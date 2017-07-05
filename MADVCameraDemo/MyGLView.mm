//
//  MyGLView.m
//  OpenGLESShader
//
//  Created by FutureBoy on 10/27/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import "MyGLView.h"
#import "MadvGLRenderer_iOS.h"
#import <MADVPano/PanoCameraController_iOS.h>
#import "KxMovieDecoder.h"
//#import "NSString+Extensions.h"
//#import "CycordVideoRecorder.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/EAGL.h>
#import <CoreMotion/CoreMotion.h>
#import "NSRecursiveCondition.h"
#import <MADVPano/JPEGUtils.h>
#import <MADVPano/PNGUtils.h>
#import <MADVPano/OpenGLHelper.h>
#import <MADVPano/GLRenderTexture.h>
#import <MADVPano/GLFilterCache.h>

#define MAX_FOCAL_LENGTH    30.f
#define MIN_FOCAL_LENGTH    3.f

#define FlingVelocityScaleX  0.002f
#define FlingVelocityScaleY  0.002f
#define Deceleration  8
#define FLING_VELOCITY_THRESHOLD 300.f

#define FOVReferenceWidthInInch  2.4409482f

#define MAX_FOV  100
#define MAX_FOV_STEREOGRAPHIC  180
#define MAX_FOV_PLANET  155
#define MIN_FOV  30
#define INIT_FOV  100

static const int MaxBufferBytes = 32 * 1048576;

//#define USE_MSAA
//#define NO_RENDERTEXTURE

#pragma mark    GLRenderLoop
@interface GLRenderLoop () //<CycordVideoRecorderDelegate>
{
    EAGLContext* _eaglContext;
    //    CADisplayLink* _displayLink;
    id _nextRenderSource;
    id _previewRenderSource;
    BOOL _hasPreviewShown;
    BOOL _hasSetRenderSource;
    BOOL _isRendererRunning;
    BOOL _isRendererPaused;
    BOOL _willRebindGLCanvas;
    BOOL _isGLReady;
    BOOL _isGyroEnabled;
    BOOL _isShareMode;
    NSRecursiveCondition* _renderCond;
    
    NSString* _snapshotDestPath;
    dispatch_block_t _snapshotCompletionHandler;
    
//    CycordVideoRecorder* _videoRecorder;
    
    GLint _width;
    GLint _height;
    GLint _inputWidth;
    GLint _inputHeight;
    
    GLuint _framebuffer;
    GLuint _renderbuffer;
    
    GLuint _msaaFramebuffer;
    GLuint _msaaRenderbuffer;
    //    GLuint _msaaDepthbuffer;
    
    MadvGLRendererRef _renderer;
    AutoRef<PanoCameraController_iOS> _panoController;
    
    GLRenderTextureRef _recorderRenderTexture;
    CGSize _outputVideoSize;
    
    GLRenderTextureRef _renderTexture0;
    GLRenderTextureRef _renderTexture1;
    GLFilterCacheRef _filterCache;
    GLuint _capsTexture;
    
    //缩放值
    float _prevFOV;
    float _FOV;
    float _minFOV;
    float _maxFOV;
    
    BOOL _isRenderThreadRunning;
    
    BOOL _recording;
    BOOL _capturing;
    BOOL _inCapturing;
    long _startTimeMills;
    long _currentFrameTimestamp;
    long _inputVideoFrameTimeStamp;
    
    BOOL _withLUTStitching;
    NSString* _lutPath;
    NSString* _prevLutPath;
    CGSize _lutSrcSizeL;
    CGSize _lutSrcSizeR;
    
    __weak id<GLRenderLoopDelegate> _delegate;
}

@property (nonatomic, strong) NSRecursiveCondition* renderCond;

@property (nonatomic, assign) BOOL recording;

@end

static GLRenderLoop* s_currentRenderLoop = nil;
static BOOL s_willStopCurrentRenderLoop = NO;

@implementation GLRenderLoop

@synthesize delegate = _delegate;
@synthesize isGlassMode;
@synthesize encoderQualityLevel;
@synthesize encodingDoneBlock;
@synthesize encodingFrameBlock;
@synthesize encodingError;
@synthesize panoramaMode;
@synthesize renderCond = _renderCond;
@synthesize recording = _recording;

//@synthesize isScrolling = _isScrolling;
//@synthesize isFlinging = _isFlinging;
//@synthesize isUsingGyro = _isUsingGyro;

//- (void) setInCapturing:(BOOL)inCapturing {
//    @synchronized (self)
//    {
//        if (_inCapturing == inCapturing)
//            return;
//        
//        if (inCapturing)
//        {
//            _startTimeMills = getCurrentTimeMills();
//            if (-1 == _currentFrameTimestamp)
//            {
//                _currentFrameTimestamp = 0;
//            }
//        }
//        else
//        {
//            long tmp = _startTimeMills;
//            _startTimeMills = -1;
//            _currentFrameTimestamp += (getCurrentTimeMills() - tmp);
//        }
//        
//        _inCapturing = inCapturing;
//    }
//}
//
//- (BOOL) inCapturing {
//    return _inCapturing;
//}

+ (dispatch_queue_t) sharedRenderingQueue {
    static dispatch_once_t once;
    static dispatch_queue_t s_renderingQueue = nil;
    dispatch_once(&once, ^{
        s_renderingQueue = dispatch_queue_create("Rendering", DISPATCH_QUEUE_SERIAL);
    });
    return s_renderingQueue;
}

+ (void) stopCurrentRenderLoop {
    @synchronized (self)
    {
        NSLog(@"EAGLContext : GLRenderLoop stopCurrentRenderLoop # Before stopCurrentRenderLoop @ %lx : s_willStopCurrentRenderLoop = %d, s_currentRenderLoop = %lx",  self.hash, s_willStopCurrentRenderLoop, s_currentRenderLoop.hash);
        if (s_currentRenderLoop)
        {
            s_willStopCurrentRenderLoop = NO;
            [s_currentRenderLoop stopRendering];
        }
        else
        {
            s_willStopCurrentRenderLoop = YES;
        }
        NSLog(@"EAGLContext : GLRenderLoop stopCurrentRenderLoop # After stopCurrentRenderLoop @ %lx : s_willStopCurrentRenderLoop = %d, s_currentRenderLoop = %lx",  self.hash, s_willStopCurrentRenderLoop, s_currentRenderLoop.hash);
    }
}

- (void) stopOtherRenderLoopIfAny {
    @synchronized (self.class)
    {
        if (!s_currentRenderLoop || s_currentRenderLoop == self)
        {
            return;
        }
    }
    [GLRenderLoop stopCurrentRenderLoop];
}

- (MadvGLRendererRef) renderer {
    MadvGLRendererRef ret = _renderer;
    return ret;
}

- (void) setIsYUVColorSpace:(BOOL)isYUVColorSpace {
    [_renderCond lock];
    if (self.isRendererReady)
    {
        _renderer->setIsYUVColorSpace(isYUVColorSpace);
    }
    [_renderCond unlock];
}

- (BOOL) isYUVColorSpace {
    BOOL ret = NO;
    [_renderCond lock];
    if (self.isRendererReady)
    {
        ret = _renderer->getIsYUVColorSpace();
    }
    [_renderCond unlock];
    return ret;
}

- (void) releaseGL {
    NSLog(@"EAGLContext : GLRenderLoop Begin releaseGL %lx",  self.hash);
    [EAGLContext setCurrentContext:_eaglContext];
    
    NSLog(@"EAGLContext : GLRenderLoop renderLoop # glClear, _eaglContext = %lx @ %lx",  _eaglContext.hash, self.hash);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    glViewport(0, 0, _width, _height);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    //    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glFlush();
    [[EAGLContext currentContext] presentRenderbuffer:GL_RENDERBUFFER];
    
    if (_framebuffer)
    {
        glDeleteFramebuffers(1, &_framebuffer);
    }
    
    if (_msaaFramebuffer)
    {
        glDeleteFramebuffers(1, &_msaaFramebuffer);
    }
    //    if (_msaaDepthbuffer)
    //    {
    //        glDeleteRenderbuffers(1, &_msaaDepthbuffer);
    //    }
    if (_msaaRenderbuffer)
    {
        glDeleteRenderbuffers(1, &_msaaRenderbuffer);
    }
    
    if (_renderbuffer)
    {
        glDeleteRenderbuffers(1, &_renderbuffer);
    }
    
    _eaglContext = nil;
    
    _renderer = NULL;
    _panoController = NULL;
    
    _recorderRenderTexture = NULL;
    
    if (_renderTexture0) _renderTexture0->releaseGLObjects();
    _renderTexture0 = NULL;
    if (_renderTexture1) _renderTexture1->releaseGLObjects();
    _renderTexture1 = NULL;
    
    if (_filterCache) _filterCache->releaseGLObjects();
    _filterCache = NULL;
    
    if (_capsTexture)
    {
        glDeleteTextures(1, &_capsTexture);
    }
    
    [EAGLContext setCurrentContext:nil];
    NSLog(@"EAGLContext : GLRenderLoop End releaseGL %lx",  self.hash);
}

- (instancetype) initWithDelegate:(id<GLRenderLoopDelegate>)delegate lutPath:(NSString*)lutPath lutSrcSizeL:(CGSize)lutSrcSizeL lutSrcSizeR:(CGSize)lutSrcSizeR inputFrameSize:(CGSize)inputFrameSize outputVideoBaseName:(NSString*)outputVideoBaseName encoderQualityLevel:(QualityLevel)qualityLevel forCapturing:(BOOL)forCapturing {
    if (self = [super init])
    {
        _delegate = delegate;
        
        _startTimeMills = -1;
        _currentFrameTimestamp = -1;
        _inputVideoFrameTimeStamp = -1;
        
        [self setVideoRecorder:outputVideoBaseName qualityLevel:qualityLevel forCapturing:forCapturing];
        
        _inputWidth = inputFrameSize.width;
        _inputHeight = inputFrameSize.height;
        
        _withLUTStitching = NO;
        [self setLUTPath:lutPath lutSrcSizeL:lutSrcSizeL lutSrcSizeR:lutSrcSizeR];
        
        _prevFOV = INIT_FOV;
        _FOV = INIT_FOV;
        _maxFOV = -1;
        _minFOV = -1;
        
        _isRendererRunning = NO;
        _isGLReady = NO;
        
        _isGyroEnabled = NO;
        
        _snapshotDestPath = nil;
        //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ////            _isRendererRunning = NO;
        ////            _isGLReady = NO;
        //            [self startRendering];
        //            [_renderCond lock];
        //            {
        //                while (!_isGLReady)
        //                {
        //                    [_renderCond wait];
        //                }
        //            }
        //            [_renderCond unlock];
        //        });
    }
    return self;
}

- (void) invalidateRenderbuffer {
    _willRebindGLCanvas = YES;
}

- (void) setIsGyroEnabled:(BOOL)enabled {
    _isGyroEnabled = enabled;
    if (self.renderer && NULL != _panoController)
    {
        _panoController->setEnablePitchDragging(!enabled);
        [self resetViewPosition];///!!!#Bug3487#
    }
}

- (void) onGyroQuaternionChanged:(CMAttitude*)attitude orientation:(UIInterfaceOrientation)orientation startOrientation:(UIInterfaceOrientation)startOrientation {
    @synchronized (self)
    {
        [self.renderCond lock];
        if (self.isRendererReady)
        {
            if (NULL != _panoController)
            {
                _panoController->setGyroRotationQuaternion(attitude, orientation, startOrientation);
            }
        }
        [self.renderCond unlock];
    }
    //            NSLog(@"Attitude:<%f,%f,%f> at %f", attitude.yaw, attitude.pitch, attitude.roll, motion.timestamp);
    //if ([pSelf.mediaAsset isKindOfClass:UIImage.class])
    {
        [self requestRedraw];
    }
}
/*
+ (kmVec2) draggingPointFromScreenPoint:(CGPoint)point screenSize:(CGSize)screenSize {
    return {(float)point.x / (float)screenSize.width - 0.5f, 0.5f - (float)point.y / (float)screenSize.height};
}

+ (kmVec2) screenPointFromDraggingPoint:(kmVec2)draggingPoint screenSize:(CGSize)screenSize {
    return {(draggingPoint.x + 0.5f) * (float)screenSize.width, (float)screenSize.height * (0.5f - draggingPoint.y)};
}
//*/
- (void) onPanRecognized : (UIPanGestureRecognizer*)panRecognizer {
    CGPoint velocityVector = [panRecognizer velocityInView:panRecognizer.view];
//    float velocityScalar = sqrtf(velocityVector.x * velocityVector.x + velocityVector.y * velocityVector.y);
//    NSLog(@"#Fling# velocity = %f", velocityScalar);
    CGPoint pointInView = [panRecognizer locationInView:panRecognizer.view];
    CGSize frameSize = panRecognizer.view.frame.size;
    //kmVec2 touchVec2f = [self.class draggingPointFromScreenPoint:touchPoint screenSize:frameSize];
    //kmVec2 normalizedVelocity = {(float)(velocityVector.x / frameSize.width), (float)(velocityVector.y / frameSize.height)};
    
    @synchronized (self)
    {
        switch (panRecognizer.state) {
            case UIGestureRecognizerStateBegan:
                {
                    if (NULL != _renderer)
                    {
                        //_panoController->startTouchControl(touchVec2f);
                        _panoController->startDragging(pointInView, frameSize);
                    }
//                    _isScrolling = YES;
//                    _isFlinging = NO;
//                    _isUsingGyro = NO;
//                    _flingVelocityX = _flingVelocityY = 0;
                }
                break;
            case UIGestureRecognizerStateChanged:
                {
                    if (NULL != _renderer)
                    {
                        //_panoController->setDragPoint(touchVec2f);
                        _panoController->dragTo(pointInView, frameSize);
                    }
                }
                break;
            case UIGestureRecognizerStateCancelled:
            case UIGestureRecognizerStateEnded:
                if (NULL != _renderer)
                {
                    //_panoController->stopTouchControl(normalizedVelocity);
                    _panoController->stopDraggingAndFling(velocityVector, frameSize);
                }
                break;
            default:
                break;
        }
        [self requestRedraw];
    }
}

- (void) onPinchRecognized:(UIPinchGestureRecognizer*)pinchRecognizer {
    if (NULL != _renderer)
    {
        switch (pinchRecognizer.state) {
            case UIGestureRecognizerStateBegan:
                _prevFOV = _FOV;
                break;
            case UIGestureRecognizerStateChanged:
                {
                    _FOV = (float) (_prevFOV / pinchRecognizer.scale);
                    [self requestRedraw];
                }
                break;
            default:
                break;
        }
    }
}

- (void) resetViewPosition {
    [_renderCond lock];
    if (self.isRendererReady)
    {
        if (NULL != _renderer)
        {
            _panoController->resetViewPosition();
            [self requestRedraw];
        }
    }
    [_renderCond unlock];
}

- (void) onDoubleTapRecognized:(UITapGestureRecognizer*)tapRecognizer {
    [self resetViewPosition];
}

- (void) setLUTPath:(NSString*)lutPath lutSrcSizeL:(CGSize)lutSrcSizeL lutSrcSizeR:(CGSize)lutSrcSizeR {
    _lutPath = lutPath;
    _lutSrcSizeL = lutSrcSizeL;
    _lutSrcSizeR = lutSrcSizeR;
}

+ (NSString*) outputVideoBaseName:(NSString*)originalVideoName qualityLevel:(QualityLevel)qualityLevel {
    NSString* outputVideoBaseName = originalVideoName;
    switch (qualityLevel)
    {
        case QualityLevel4K:
            outputVideoBaseName = [outputVideoBaseName stringByAppendingString:@"4K"];
            break;
        case QualityLevel1080:
            outputVideoBaseName = [outputVideoBaseName stringByAppendingString:@"1080"];
            break;
        default:
            break;
    }
    if (!outputVideoBaseName || outputVideoBaseName.length <= 0)
    {
        outputVideoBaseName = @"image_snapshot";
    }
    return outputVideoBaseName;
}

- (void) setVideoRecorder:(NSString*)outputVideoBaseName qualityLevel:(QualityLevel)qualityLevel forCapturing:(BOOL)forCapturing {
    _capturing = forCapturing;
    if (!_capturing)
    {
        _recording = (outputVideoBaseName && outputVideoBaseName.length > 0);
    }
    else
    {
        _recording = NO;
    }
    self.encoderQualityLevel = qualityLevel;
    outputVideoBaseName = [self.class outputVideoBaseName:outputVideoBaseName qualityLevel:qualityLevel];
    //_videoRecorder = [[CycordVideoRecorder alloc] initWithOutputVideoBaseName:outputVideoBaseName];
    //_videoRecorder.delegate = self;
}

#define RenderTextureScale 1.0f

- (void) resizeFilterRenderTexture:(CGSize)size {
    ///!!!    if (_renderTexture0)
    //    {
    //        _renderTexture0->resizeIfNecessary(size.width * RenderTextureScale, size.height * RenderTextureScale);
    //    }
    //    else
    //    {
    //        _renderTexture0 = new GLRenderTexture(size.width * RenderTextureScale, size.height * RenderTextureScale);
    //        NSLog(@"_filterRenderTexture = %d", _renderTexture0->getTexture());
    //    }
}
/*
- (void) resizeVideoRecorder:(CGSize)outputVideoSize {
    _inputWidth = outputVideoSize.width;
    _inputHeight = outputVideoSize.height;
    
    if (!_recording && !_capturing)
        return;
    
    if (_capturing)
    {
        outputVideoSize = CGSizeMake(1600, 900);
    }
    else if (_recording)
    {
        switch (self.encoderQualityLevel) {
            case QualityLevel4K:
                outputVideoSize = CGSizeMake(outputVideoSize.width, outputVideoSize.height);
                break;
            case QualityLevel1080:
                outputVideoSize = CGSizeMake(2304, 1152);
                break;
            default:
                outputVideoSize = CGSizeMake(outputVideoSize.width, outputVideoSize.height);
                break;
        }
    }
    
    //    outputVideoSize = CGSizeMake(_width, _height);///!!!For Debug
    //    [self resizeFilterRenderTexture:CGSizeMake(_width, _height)];///!!!For Debug
    [self resizeFilterRenderTexture:outputVideoSize];
    
    if (outputVideoSize.width > 0 && outputVideoSize.height > 0)
    {
        _outputVideoSize = outputVideoSize;
        if (_videoRecorder)
        {
            [_videoRecorder setViewSize:outputVideoSize];
            if (_isShareMode) {
                [_videoRecorder setShareMode];
            }
            [_videoRecorder setupVideoRecorder];
            
            if (_videoRecorder)
            {
                if (NULL == _recorderRenderTexture || outputVideoSize.width != _recorderRenderTexture->getWidth() || outputVideoSize.height != _recorderRenderTexture->getHeight())
                {
                    CVOpenGLESTextureRef cvTexture = _videoRecorder.renderTexture;
                    _recorderRenderTexture = new GLRenderTexture(CVOpenGLESTextureGetName(cvTexture), CVOpenGLESTextureGetTarget(cvTexture), outputVideoSize.width, outputVideoSize.height);
                    NSLog(@"_recorderRenderTexture = %d", _recorderRenderTexture->getTexture());
                }
            }
        }
    }
    //    }///!!!For Debug
}
/*
#pragma mark    CycordVideoRecorderDelegate

- (void) cycordVideoRecorderDidRenderOneFrame:(int)elapsedMillseconds {
    
}

- (void) cycordVideoRecorderDidRecordOneFrame:(int)recordedMillseconds {
    
}

- (void) cycordVideoRecorderFailedWhileRecording:(NSError *)error {
    self.encodingError = error;
    [self stopRendering];
    [self stopEncoding:nil];
}
//*/
- (void) renderLoop:(id)object {
    // Init GL and GL objects:
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:_eaglContext];
    NSLog(@"EAGLContext : GLRenderLoop renderLoop begin, _eaglContext = %lx @ %lx",  _eaglContext.hash, self.hash);
    
    //    NSLog(@"EAGLContext : GLRenderLoop renderLoop # glClear, _eaglContext = %lx @ %lx",  _eaglContext.hash, self.hash);
    //    glViewport(0, 0, _width, _height);
    //    glClearColor(0, 0, 0, 1);
    //    glClear(GL_COLOR_BUFFER_BIT);
    //    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    //    [[EAGLContext currentContext] presentRenderbuffer:GL_RENDERBUFFER];
    
#ifdef USE_MSAA
    //        _supportDiscardFramebuffer = NO;
    //        char* glExtensions = (char*)glGetString(GL_EXTENSIONS);
    //        if (glExtensions && strstr(glExtensions, "GL_EXT_discard_framebuffer"))
    //        {
    //            _supportDiscardFramebuffer = YES;
    //        }
    //        NSLog(@"GLExt : %s\n", glExtensions);
    
    glGenFramebuffers(1, &_msaaFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
    glGenRenderbuffers(1, &_msaaRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderbuffer);
    //        glGenRenderbuffers(1, &_msaaDepthbuffer);
    CHECK_GL_ERROR();
#endif
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    CHECK_GL_ERROR();
    //    CAEAGLLayer* layer = (CAEAGLLayer*) self.layer;
    //    layer.opaque = YES;
    //    layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
    //                                //If use glReadPixels to get pixel data after presentRenderbuffer, RetainedBacking should be set to YES:
    //                                [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
    //                                kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    CHECK_GL_ERROR();
    [self rebindGLCanvas];
    
    _renderer = new MadvGLRenderer_iOS(_lutPath.UTF8String, CGSize2Vec2f(_lutSrcSizeL), CGSize2Vec2f(_lutSrcSizeR));
    _panoController = new PanoCameraController_iOS(_renderer);
    
    _prevLutPath = _lutPath;
#ifdef ENABLE_OPENGL_DEBUG
    _renderer->setEnableDebug(true);
#endif
    [self setIsGyroEnabled:_isGyroEnabled];
    //    NSString* capLogoPath = [[NSBundle mainBundle] pathForResource:@"madv_cap_logo" ofType:@"pngraw"];
    //    _capsTexture = createTextureFromPNG(capLogoPath.UTF8String);
    ////    _capsTexture = createTextureFromImage([UIImage imageNamed:@"madv_cap_logo"]);
    //    _renderer->setNeedDrawCaps(true);
    //    _renderer->setCapsTexture(_capsTexture, GL_TEXTURE_2D);
    //    ///!!!:For Debug
    NSString* resourcePath = [[NSBundle mainBundle] pathForResource:@"lookup" ofType:@"png"];
    
    
    resourcePath = [resourcePath stringByDeletingLastPathComponent];
    _filterCache = new GLFilterCache(resourcePath.UTF8String);
    
    [_renderCond lock];
    {
        _isGLReady = YES;
        [_renderCond broadcast];
    }
    [_renderCond unlock];
    NSLog(@"EAGLContext : GLRenderLoop renderLoop _isGLReady = YES; @ %lx",  self.hash);
    // Main Loop:
    id prevRenderSource = nil;
    while (_isRendererRunning)
    {
        @autoreleasepool //write by spy
        {
            [_renderCond lock];
            {
                BOOL waited = NO;
                while (_isRendererPaused && _isRendererRunning)
                {
                    waited = YES;
                    NSLog(@"EAGLContext : GLRenderLoop renderLoop wait; @ %lx",  self.hash);
                    [_renderCond wait];
                }
                if (waited)
                {
                    NSLog(@"EAGLContext : GLRenderLoop renderLoop wakeup @ %lx",  self.hash);
                }
            }
            [_renderCond unlock];
            if (!_isRendererRunning)
            {NSLog(@"EAGLContext : GLRenderLoop renderLoop !_isRendererRunning @ %lx",  self.hash);
                break;
            }
            
            long loopStart = [[NSDate date] timeIntervalSince1970] * 1000.f;
            // Rendering one frame:
            if (_willRebindGLCanvas)
            {
                _willRebindGLCanvas = NO;
                [self rebindGLCanvas];
            }
            
            if (_lutPath && ![_lutPath isEqualToString:_prevLutPath])
            {
                _renderer->prepareLUT(_lutPath.UTF8String, CGSize2Vec2f(_lutSrcSizeL), CGSize2Vec2f(_lutSrcSizeR));
                _prevLutPath = _lutPath;
            }
            
            //        id renderSource = [self readRenderSource];
            id renderSource = nil;
            @synchronized (self)
            {
                if (_previewRenderSource && !_hasPreviewShown)
                {
                    _hasPreviewShown = YES;
                    renderSource = _previewRenderSource;
                    _previewRenderSource = nil;
                }
                else
                {
                    renderSource = _nextRenderSource;
                    _nextRenderSource = nil;
                }
            }
            //        renderSource = nil;
            ///!!!For Debug #VideoLeak#
            
            if (renderSource && renderSource != prevRenderSource)
            {//NSLog(@"VideoLeak : new renderSource coming : %@", renderSource);
                prevRenderSource = renderSource;
                
                if ([renderSource isKindOfClass:NSString.class])
                {
                    NSString* filePath = (NSString*) renderSource;
                    //    [self resizeVideoRecorder:image.size];
                    
                    kmScalar textureMatrixData[] = {
                        1.f, 0.f, 0.f, 0.f,
                        0.f, -1.f, 0.f, 0.f,
                        0.f, 0.f, 1.f, 0.f,
                        0.f, 1.f, 0.f, 1.f,
                    };
                    kmMat4 textureMatrix;
                    kmMat4Fill(&textureMatrix, textureMatrixData);
                    _renderer->setTextureMatrix(&textureMatrix);
                    
                    _renderer->setRenderSource((__bridge_retained void*)filePath);
                    _hasSetRenderSource = YES;
                }
                else if ([renderSource isKindOfClass:UIImage.class])
                {
                    kmScalar textureMatrixData[] = {
                        1.f, 0.f, 0.f, 0.f,
                        0.f, -1.f, 0.f, 0.f,
                        0.f, 0.f, 1.f, 0.f,
                        0.f, 1.f, 0.f, 1.f,
                    };
                    kmMat4 textureMatrix;
                    kmMat4Fill(&textureMatrix, textureMatrixData);
                    _renderer->setTextureMatrix(&textureMatrix);
                    
                    UIImage* image = (UIImage*) renderSource;
                    //[self resizeVideoRecorder:image.size];
                    
                    _renderer->setRenderSource((__bridge_retained void*)image);
                    _hasSetRenderSource = YES;
                }
                else if ([renderSource isKindOfClass:KxVideoFrame.class])
                {
                    kmScalar textureMatrixData[] = {
                        1.f, 0.f, 0.f, 0.f,
                        0.f, -1.f, 0.f, 0.f,
                        0.f, 0.f, 1.f, 0.f,
                        0.f, 0.f, 0.f, 1.f,
                    };
                    kmMat4 textureMatrix;
                    kmMat4Fill(&textureMatrix, textureMatrixData);
                    _renderer->setTextureMatrix(&textureMatrix);
                    
                    KxVideoFrame* frame = (KxVideoFrame*) renderSource;
                    
                    //[self resizeVideoRecorder:CGSizeMake(frame.width, frame.height)];
                    
                    _renderer->setRenderSource((__bridge_retained void*)frame);
                    _hasSetRenderSource = YES;
                    
                    if ([frame isKindOfClass:KxVideoFrameCVBuffer.class])
                    {
                        KxVideoFrameCVBuffer* cvbFrame = (KxVideoFrameCVBuffer*) frame;
                        [cvbFrame releasePixelBuffer];
                    }
                }
                
                Vec2f sourceSize = _renderer->getRenderSourceSize();
                _inputHeight = sourceSize.height;
                _inputWidth = sourceSize.width;
            }
            
            //if (self.inCapturing)
            {//Bug#3763
                //[self resizeVideoRecorder:CGSizeMake(1600, 900)];
            }
            
            if (_hasSetRenderSource)
            {
                [self draw];
            }
            renderSource = nil;
            
            // Targeting 60 fps, no need for faster
            long timeInterval = 16;
            _panoController->update((float)timeInterval / 1000.f);
            
            long waitDelta = timeInterval - ([[NSDate date] timeIntervalSince1970] * 1000.f - loopStart);
            waitDelta = (waitDelta > 0 ? waitDelta : 0);
            if (self.delegate && [self.delegate respondsToSelector:@selector(glRenderLoop:frameTimeTicked:)])
            {
                [self.delegate glRenderLoop:self frameTimeTicked:(int)waitDelta];
            }
            if (waitDelta > 0)
            {
                [NSThread sleepForTimeInterval:waitDelta/1000.f];
            }
        }
    }
    NSLog(@"EAGLContext : GLRenderLoop renderLoop Begin Finishing @ %lx",  self.hash);
    [_renderCond lock];
    _isGLReady = NO;
    [_renderCond unlock];
    
    _nextRenderSource = nil;
    _previewRenderSource = nil;
    _hasPreviewShown = NO;
    _hasSetRenderSource = NO;
    //调整顺序 write by spy
    if (_recording || _capturing) {
        [self stopEncoding];
    }
    [self releaseGL];
}

- (BOOL) isRendererReady {
    return _isGLReady;
}

- (void) pauseRendering {
    [_renderCond lock];
    {
        _isRendererPaused = YES;
    }
    [_renderCond unlock];
}

- (void) resumeRendering {
    [_renderCond lock];
    {
        _isRendererPaused = NO;
        [_renderCond broadcast];
    }
    [_renderCond unlock];
}

- (void) stopRendering {
    NSLog(@"EAGLContext : GLRenderLoop stopRendering @ %lx",  self.hash);
//    _isScrolling = NO;
//    _isFlinging = NO;
//    _isUsingGyro = NO;
    
    [_renderCond lock];
    {
        _isRendererRunning = NO;
        [_renderCond broadcast];
    }
    [_renderCond unlock];
}

- (void) setShareMode {
    _isShareMode = YES;
}

- (void) startRendering {
    NSLog(@"EAGLContext : GLRenderLoop startRendering @ %lx",  self.hash);
//    _isScrolling = NO;
//    _isFlinging = NO;
//    _isUsingGyro = NO;
    _hasPreviewShown = NO;
    _hasSetRenderSource = NO;
    _madVdata = nil;
    
    @synchronized (self)
    {
        if (!_renderCond)
        {
            _renderCond = [[NSRecursiveCondition alloc] init];
        }
    }
    
    [_renderCond lock];
    {
        if (_isRendererRunning)
        {NSLog(@"EAGLContext : GLRenderLoop startRendering return : Already started, _isGLReady = %d @ %lx", _isGLReady, self.hash);
            _isRendererPaused = NO;
            [_renderCond broadcast];
            
            [_renderCond unlock];
            return;
        }
        
        _isRendererRunning = YES;
        _isRendererPaused = NO;
    }
    [_renderCond unlock];
    
    dispatch_async([self.class sharedRenderingQueue], ^{
        NSLog(@"EAGLContext : GLRenderLoop finished startRendering @ %lx",  self.hash);
        @synchronized (self.class)
        {
            NSLog(@"EAGLContext : GLRenderLoop startRendering # Before renderLoop #0 @ %lx : s_willStopCurrentRenderLoop = %d, s_currentRenderLoop = %lx",  self.hash, s_willStopCurrentRenderLoop, s_currentRenderLoop.hash);
            s_currentRenderLoop = self;
            if (s_willStopCurrentRenderLoop)
            {
                s_willStopCurrentRenderLoop = NO;
                [s_currentRenderLoop stopRendering];
            }
            NSLog(@"EAGLContext : GLRenderLoop startRendering # Before renderLoop #1 @ %lx : s_willStopCurrentRenderLoop = %d, s_currentRenderLoop = %lx",  self.hash, s_willStopCurrentRenderLoop, s_currentRenderLoop.hash);
        }
        
        [self renderLoop:nil];
    });
    NSLog(@"EAGLContext : GLRenderLoop startRendering returned @ %lx",  self.hash);
}
/*
- (void)setMadVdata:(NSData*) MadVData
{
    _madVdata = MadVData;
}

- (void) stopEncoding {
    @synchronized (self)
    {
        if (_recording || _capturing)
        {
            _recording = NO;
            _capturing = NO;
            
            __weak __typeof(self) wSelf = self;
            if (self.encodingError)
            {
                _videoRecorder.encodingError = self.encodingError;
            }
            [_videoRecorder stopRecordingWithCompletionHandler:^(NSError* error, NSString* outputFilePath){
                if (wSelf.encodingDoneBlock)
                {
                    if (!error && wSelf.encodingError)
                    {
                        error = wSelf.encodingError;
                    }
                    
                    if (wSelf.recording)
                    {
                        if (!error)
                        {
                            [self write360VideoMetaData:outputFilePath];
                        }
                        if (!error && _madVdata != nil) {
                            NSFileHandle* fh=[NSFileHandle fileHandleForWritingAtPath:outputFilePath];
                            [fh seekToEndOfFile];
                            [fh writeData:_madVdata];
                            [fh closeFile];
                        }
                    }
                    NSLog(@"#Bug2880# stopEncoding #3");

                    wSelf.encodingDoneBlock(outputFilePath, error);
                }
            }];
        }
    }
}

- (void) write360VideoMetaData:(NSString*) outputFilePath {
    NSError *perror = [[NSError alloc] init];
    KxMovieDecoder *aDecoder = [[KxMovieDecoder alloc] init];
    if (aDecoder) {
        [aDecoder openFile:outputFilePath error:&perror];
        _moovBoxSizeOffset = aDecoder.getMoovBoxSizeOffset;
        _videoTrakBoxSizeOffset = aDecoder.getVideoTrakBoxSizeOffset;
        _videoTrakBoxEndOffset = aDecoder.getVideoTrakBoxEndOffset - 1 ;
        [aDecoder closeFile];
    }
    aDecoder = nil;
    
    if( _moovBoxSizeOffset > 0 && _videoTrakBoxSizeOffset > 0 && _videoTrakBoxEndOffset > 0) {
        NSFileHandle* fh=[NSFileHandle fileHandleForUpdatingAtPath:outputFilePath];
        NSData* sizeBufferMoovSize;
        NSData* sizeBufferVideoTrakSize;
        NSData* moovBoxSizeData;
        NSData* videoTrakBoxSizeData;
        NSData* tmp;
        NSData* videoMetaData;
        
        [fh seekToFileOffset:_moovBoxSizeOffset];
        sizeBufferMoovSize = [fh readDataOfLength:4];
        Byte *dataBytesMoovSize = (Byte *)[sizeBufferMoovSize bytes];
        int moovBoxSize = ((dataBytesMoovSize[0] << 24) & 0xff000000)
                             | ((dataBytesMoovSize[1] << 16) & 0x00ff0000)
                             | ((dataBytesMoovSize[2] << 8) & 0x0000ff00)
                             | (dataBytesMoovSize[3] & 0x000000ff);
        moovBoxSize += 454;
        dataBytesMoovSize[0] = (moovBoxSize & 0xff000000) >> 24;
        dataBytesMoovSize[1] = (moovBoxSize & 0x00ff0000) >> 16;
        dataBytesMoovSize[2] = (moovBoxSize & 0x0000ff00) >> 8;
        dataBytesMoovSize[3] = (moovBoxSize & 0x000000ff);
        moovBoxSizeData = [[NSData alloc] initWithBytes:dataBytesMoovSize length:4];
        [fh seekToFileOffset:_moovBoxSizeOffset];
        [fh writeData:moovBoxSizeData];
        
        [fh seekToFileOffset:_videoTrakBoxSizeOffset];
        sizeBufferVideoTrakSize = [fh readDataOfLength:4];
        Byte *dataBytesVideoTrakSize = (Byte *)[sizeBufferVideoTrakSize bytes];
        int videoTrakBoxSize = ((dataBytesVideoTrakSize[0] << 24) & 0xff000000)
                               | ((dataBytesVideoTrakSize[1] << 16) & 0x00ff0000)
                               | ((dataBytesVideoTrakSize[2] << 8) & 0x0000ff00)
                               | (dataBytesVideoTrakSize[3] & 0x000000ff);
        videoTrakBoxSize += 454;
        dataBytesVideoTrakSize[0] = (videoTrakBoxSize & 0xff000000) >> 24;
        dataBytesVideoTrakSize[1] = (videoTrakBoxSize & 0x00ff0000) >> 16;
        dataBytesVideoTrakSize[2] = (videoTrakBoxSize & 0x0000ff00) >> 8;
        dataBytesVideoTrakSize[3] = (videoTrakBoxSize & 0x000000ff);
        videoTrakBoxSizeData = [[NSData alloc] initWithBytes:dataBytesVideoTrakSize length:4];
        [fh seekToFileOffset:_videoTrakBoxSizeOffset];
        [fh writeData:videoTrakBoxSizeData];

        [fh seekToFileOffset:_videoTrakBoxEndOffset+1];
        tmp = [fh readDataToEndOfFile];
        
        Byte videoMetaDataBytes[] ={
            0x00, 0x00, 0x01, 0xC6, 0x75, 0x75, 0x69, 0x64, 0xFF, 0xCC, 0x82, 0x63, 0xF8, 0x55, 0x4A, 0x93, 0x88, 0x14, 0x58, 0x7A, 0x02, 0x52, 0x1F, 0xDD, 0x3C, 0x3F, 0x78, 0x6D, 0x6C, 0x20, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E, 0x3D, 0x22, 0x31, 0x2E, 0x30, 0x22, 0x3F, 0x3E, 0x3C, 0x72, 0x64, 0x66, 0x3A, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x56, 0x69, 0x64, 0x65, 0x6F, 0x0A, 0x78, 0x6D, 0x6C, 0x6E, 0x73, 0x3A, 0x72, 0x64, 0x66, 0x3D, 0x22, 0x68, 0x74, 0x74, 0x70, 0x3A, 0x2F, 0x2F, 0x77, 0x77, 0x77, 0x2E, 0x77, 0x33, 0x2E, 0x6F, 0x72, 0x67, 0x2F, 0x31, 0x39, 0x39, 0x39, 0x2F, 0x30, 0x32, 0x2F, 0x32, 0x32, 0x2D, 0x72, 0x64, 0x66, 0x2D, 0x73, 0x79, 0x6E, 0x74, 0x61, 0x78, 0x2D, 0x6E, 0x73, 0x23, 0x22, 0x0A, 0x78, 0x6D, 0x6C, 0x6E, 0x73, 0x3A, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3D, 0x22, 0x68, 0x74, 0x74, 0x70, 0x3A, 0x2F, 0x2F, 0x6E, 0x73, 0x2E, 0x67, 0x6F, 0x6F, 0x67, 0x6C, 0x65, 0x2E, 0x63, 0x6F, 0x6D, 0x2F, 0x76, 0x69, 0x64, 0x65, 0x6F, 0x73, 0x2F, 0x31, 0x2E, 0x30, 0x2F, 0x73, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x2F, 0x22, 0x3E, 0x3C, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3E, 0x74, 0x72, 0x75, 0x65, 0x3C, 0x2F, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3E, 0x3C, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x53, 0x74, 0x69, 0x74, 0x63, 0x68, 0x65, 0x64, 0x3E, 0x74, 0x72, 0x75, 0x65, 0x3C, 0x2F, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x53, 0x74, 0x69, 0x74, 0x63, 0x68, 0x65, 0x64, 0x3E, 0x3C, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x53, 0x74, 0x69, 0x74, 0x63, 0x68, 0x69, 0x6E, 0x67, 0x53, 0x6F, 0x66, 0x74, 0x77, 0x61, 0x72, 0x65, 0x3E, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x20, 0x4D, 0x65, 0x74, 0x61, 0x64, 0x61, 0x74, 0x61, 0x20, 0x54, 0x6F, 0x6F, 0x6C, 0x3C, 0x2F, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x53, 0x74, 0x69, 0x74, 0x63, 0x68, 0x69, 0x6E, 0x67, 0x53, 0x6F, 0x66, 0x74, 0x77, 0x61, 0x72, 0x65, 0x3E, 0x3C, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x50, 0x72, 0x6F, 0x6A, 0x65, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x54, 0x79, 0x70, 0x65, 0x3E, 0x65, 0x71, 0x75, 0x69, 0x72, 0x65, 0x63, 0x74, 0x61, 0x6E, 0x67, 0x75, 0x6C, 0x61, 0x72, 0x3C, 0x2F, 0x47, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x3A, 0x50, 0x72, 0x6F, 0x6A, 0x65, 0x63, 0x74, 0x69, 0x6F, 0x6E, 0x54, 0x79, 0x70, 0x65, 0x3E, 0x3C, 0x2F, 0x72, 0x64, 0x66, 0x3A, 0x53, 0x70, 0x68, 0x65, 0x72, 0x69, 0x63, 0x61, 0x6C, 0x56, 0x69, 0x64, 0x65, 0x6F, 0x3E};

        videoMetaData = [[NSData alloc] initWithBytes:videoMetaDataBytes length:454];
        [fh seekToFileOffset:_videoTrakBoxEndOffset+1];
        [fh writeData:videoMetaData];
        [fh seekToFileOffset:_videoTrakBoxEndOffset+454+1];
        [fh writeData:tmp];
        
        [fh closeFile];
    }
}
//*/
- (void) setFOVRange:(int)initFOV maxFOV:(int)maxFOV minFOV:(int)minFOV {
    _prevFOV = initFOV;
    _FOV = initFOV;
    _maxFOV = maxFOV;
    _minFOV = minFOV;
}

- (void) adustAndSetFOV {
    [_renderCond lock];
    if (self.isRendererReady)
    {
        int maxFOV = _maxFOV;
        if (maxFOV <= 0)
        {
            switch (self.panoramaMode)
            {
                case PanoramaDisplayModeStereoGraphic:
                    maxFOV = MAX_FOV_STEREOGRAPHIC;
                    break;
                case PanoramaDisplayModeLittlePlanet:
                    maxFOV = MAX_FOV_PLANET;
                    break;
                default:
                    maxFOV = MAX_FOV;
                    break;
            }
        }
        int minFOV = _minFOV;
        if (minFOV <= 0)
        {
            minFOV = MIN_FOV;
        }
        
        if (_FOV < minFOV) {
            _FOV = minFOV;
        }
        else if (_FOV > maxFOV) {
            _FOV = maxFOV;
        }
        //NSLog(@"adustAndSetFOV : %f", _FOV);
        //float widthInInch = mSurfaceTextureWidth / mDisplayMetrics.xdpi;
        //Log.e(TAG, "mSurfaceTextureWidth = " + mSurfaceTextureWidth + ", mSurfaceTextureHeight = " + mSurfaceTextureHeight);
        //float adustedFOV = (float) Math.toDegrees(Math.atan(Math.tan(Math.toRadians(FOV) / 2.f) * widthInInch / FOVReferenceWidthInInch)) * 2.f;
        //Log.e(TAG, "FOV = " + FOV + ", adustedFOV = " + adustedFOV);
        //if (null != mRenderer) {
        _panoController->setFOVDegree((int) _FOV);
        //}
    }
    [_renderCond unlock];
}

- (void) rebindGLCanvas {
    [EAGLContext setCurrentContext:_eaglContext];
    CHECK_GL_ERROR();
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    if (self.delegate && [self.delegate respondsToSelector:@selector(glRenderLoopSetupGLRenderbuffer:)])
    {
        [self.delegate glRenderLoopSetupGLRenderbuffer:self];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSLog(@"status = %d, width = %d, height = %d", status, _width, _height);
    CHECK_GL_ERROR();
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height);
    CHECK_GL_ERROR();
    if (!_recording)
    {
        [self resizeFilterRenderTexture:CGSizeMake(_width, _height)];
    }
    
    
    //    glViewport(0, 0, _width, _height);
#ifdef USE_MSAA
    //    if (_msaaFramebuffer)
    //    {
    //        glDeleteFramebuffers(1, &_msaaFramebuffer);
    //        glGenFramebuffers(1, &_msaaFramebuffer);
    //    }
    glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
    
    //    if (_msaaDepthbuffer)
    //    {
    //        glDeleteRenderbuffers(1, &_msaaDepthbuffer);
    //        glGenRenderbuffers(1, &_msaaDepthbuffer);
    //        CHECK_GL_ERROR();
    //    }
    //    if (_msaaRenderbuffer)
    //    {
    //        glDeleteRenderbuffers(1, &_msaaRenderbuffer);
    //        glGenRenderbuffers(1, &_msaaRenderbuffer);
    //        CHECK_GL_ERROR();
    //    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderbuffer);
    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 4, GL_RGBA8_OES, _width, _height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _msaaRenderbuffer);
    CHECK_GL_ERROR();
    //    glBindRenderbuffer(GL_RENDERBUFFER, _msaaDepthbuffer);
    //    glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, 4, GL_DEPTH_COMPONENT16, _width, _height);
    //    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _msaaDepthbuffer);
    //    CHECK_GL_ERROR();
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
#endif
}

- (void) assignNextRenderSource:(id)nextRenderSource {
    @synchronized (self)
    {//NSLog(@"EAGLContext : assignNextRenderSource : %@", nextRenderSource);
        if ([_nextRenderSource isKindOfClass:KxVideoFrameCVBuffer.class])
        {
            KxVideoFrameCVBuffer* cvbFrame = (KxVideoFrameCVBuffer*) _nextRenderSource;
            [cvbFrame releasePixelBuffer];
        }
        _nextRenderSource = nil;
        _nextRenderSource = nextRenderSource;
        
        if ([_nextRenderSource isKindOfClass:KxVideoFrame.class])
        {
            KxVideoFrame* videoFrame = (KxVideoFrame*) _nextRenderSource;
            _inputVideoFrameTimeStamp = videoFrame.timestamp;
        }
        else
        {
            _inputVideoFrameTimeStamp = -1;
        }
        //NSLog(@"#VideoEncoding#: assignNextRenderSource : _inputVideoFrameTimeStamp = %d", (int)_inputVideoFrameTimeStamp);
        
        if (!_previewRenderSource && [_nextRenderSource isKindOfClass:UIImage.class])
        {
            _previewRenderSource = _nextRenderSource;
        }
    }
}

- (id) readRenderSource {
    id ret = nil;
    @synchronized (self)
    {
        if (_previewRenderSource && !_hasPreviewShown)
        {
            _hasPreviewShown = YES;
            ret = _previewRenderSource;
            _previewRenderSource = nil;
        }
        else
        {
            ret = _nextRenderSource;
            _nextRenderSource = nil;
        }
    }
    return ret;
}

- (void) draw:(UIImage *)image {
    _withLUTStitching = NO;
    [self assignNextRenderSource:image];
}

- (void) drawJPEG:(NSString*)filePath {
    _withLUTStitching = NO;
    [self assignNextRenderSource:filePath];
}

- (void) render: (KxVideoFrame *) frame
{
    //    NSLog(@"EAGLContext : Render video frame", [NSThread currentThread]);
    _withLUTStitching = YES;
    [self assignNextRenderSource:frame];
}

- (void) setGyroMatrix:(float*)matrix rank:(int)rank {
    [_renderCond lock];
    if (self.isRendererReady)
    {
        _renderer->setGyroMatrix(matrix, rank);
    }
    [_renderCond unlock];
}

- (void) drawStichedImageWithLeftImage:(UIImage*)leftImage rightImage:(UIImage*)rightImage {
    NSArray* images = @[leftImage, rightImage];
    [EAGLContext setCurrentContext:_eaglContext];
    _renderer->setRenderSource((__bridge_retained void*)images);
}

- (void) renderImmediately: (KxVideoFrame *) frame
{
    [EAGLContext setCurrentContext:_eaglContext];
   // [self resizeVideoRecorder:CGSizeMake(frame.width, frame.height)];
    
    _renderer->setRenderSource((__bridge_retained void*)frame);
    [self draw];
}

- (void) draw {
    if (!_eaglContext) return;
    [EAGLContext setCurrentContext:_eaglContext];
    glEnable(GL_BLEND);
    glPolygonOffset(0.1f, 0.2f);///???
    //    glCullFace(GL_CCW);
    CHECK_GL_ERROR();
#ifdef USE_MSAA
    glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderbuffer);
    CHECK_GL_ERROR();
#else
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
#endif
    //    glClearColor((rand() % 256)/255.f, (rand() % 256)/255.f, (rand() % 256)/255.f, 1);///!!!
    glClearColor(0, 0, 0, 0);
    CHECK_GL_ERROR();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    CHECK_GL_ERROR();
    GLint currentSourceTextureL = _renderer->getLeftSourceTexture();
    GLint currentSourceTextureR = _renderer->getRightSourceTexture();
    GLenum currentSourceTextureTarget = _renderer->getSourceTextureTarget();
    int currentFilterID = self.filterID;
    int currentPanoramaMode = self.panoramaMode;
    int displayWidth = _width;
    int displayHeight = _height;
    int inputWidth = _inputWidth;
    int inputHeight = _inputHeight;
    BOOL currentIsGlassMode = self.isGlassMode;
    int currentLUTStitchingMode = ((_withLUTStitching && _lutPath) ? PanoramaDisplayModeLUT : 0);
    int currentRenderMode = currentLUTStitchingMode | currentPanoramaMode;
    //BOOL isInCapturing = self.inCapturing;
    
    [self adustAndSetFOV];
    
    if (_recording && NULL != _recorderRenderTexture)
    {
        glViewport(0, 0, _outputVideoSize.width, _outputVideoSize.height);
        //        _renderer->setDisplayMode((currentRenderMode & (~PanoramaDisplayModeExclusiveMask)) | PanoramaDisplayModePlain);
#ifdef ENCODE_VIDEO_WITH_GYRO
        _renderer->setDisplayMode(currentLUTStitchingMode | PanoramaDisplayModeReFlatten);
#else
        _renderer->setDisplayMode(currentLUTStitchingMode | PanoramaDisplayModePlain);
//        _renderer->setDisplayMode(PanoramaDisplayModePlain);
#endif
        _renderer->setEnableDebug(false);
        _renderer->setFlipY(true);
        if (currentFilterID > 0)
        {
            if (NULL == _renderTexture0)
            {
                _renderTexture0 = new GLRenderTexture(_recorderRenderTexture->getWidth(), _recorderRenderTexture->getHeight());
            }
            else
            {
                _renderTexture0->resizeIfNecessary(_recorderRenderTexture->getWidth(), _recorderRenderTexture->getHeight());
            }
            
            _renderTexture0->blit();
            _renderer->draw(0,0, _renderTexture0->getWidth(), _renderTexture0->getHeight());// _filterRenderTexture << Stitching << sourceTexture(s)
            _renderTexture0->unblit();
            
            _recorderRenderTexture->blit();
            _filterCache->render(currentFilterID, 0, 0, _recorderRenderTexture->getWidth(), _recorderRenderTexture->getHeight(), _renderTexture0->getTexture(), _renderTexture0->getTextureTarget(), OrientationNormal, Vec2f{0.f, 0.f}, Vec2f {1.f, 1.f}); // _recorderRenderTexture << Filtering << _filterRenderTexture
            _recorderRenderTexture->unblit();
        }
        else
        {
            _recorderRenderTexture->blit();
            _renderer->draw(0,0, _recorderRenderTexture->getWidth(), _recorderRenderTexture->getHeight());// _recorderRenderTexture << Stitching << sourceTexture(s)
            _recorderRenderTexture->unblit();
        }
        _renderer->setFlipY(false);
        
        //[_videoRecorder startRecording:30.f];
        //        if (_startTimeMills <= 0)
        //        {
        //            _startTimeMills = getCurrentTimeMills();
        //        }
        //        int timelapse = (int)(getCurrentTimeMills() - _startTimeMills);
        //        [_videoRecorder recordOneFrame:(_currentFrameTimestamp >= 0 ? (int)_currentFrameTimestamp : timelapse)];
        glFlush();
        if (_inputVideoFrameTimeStamp >= 0)
        {
            //[_videoRecorder recordOneFrame:(int)_inputVideoFrameTimeStamp];
        }
        
        //NSLog(@"VideoEncoding: recordOneFrame:%d", (int)_currentFrameTimestamp);
        
        //        _renderer->setFlipY(false);
        //        _renderer->setDisplayMode(currentRenderMode & (~PanoramaDisplayModeLUT));
//        _renderer->setDisplayMode(currentPanoramaMode);
//        _renderer->setSourceTextures(NO, _recorderRenderTexture->getTexture(), _recorderRenderTexture->getTexture(), _recorderRenderTexture->getTextureTarget(), NO);///!!!
//        if (self.isGlassMode)
//        {
//            _renderer->draw(0,0, _width/2,_height);
//            _renderer->draw(_width/2,0, _width/2,_height);
//        }
//        else
//        {
//            _renderer->draw(0,0, _width,_height);
//        }
//        //        _renderer->setFlipY(false);
//        _renderer->setSourceTextures(NO, currentSourceTextureL, currentSourceTextureR, currentSourceTextureTarget, NO);///!!!
    }
    else
    {
        int outputWidth, outputHeight;
        
        // Take snapshot if necessary:
        GLRenderTextureRef snapshotRenderTexture = NULL;
        if (_snapshotDestPath)
        {
            if ((0 != (currentPanoramaMode & PanoramaDisplayModeSphere)) || (0 != (currentPanoramaMode & PanoramaDisplayModeStereoGraphic)) || (0 != (currentPanoramaMode & PanoramaDisplayModeLittlePlanet)))
            {
                int fovDegreeX = _renderer->glCamera()->getFOVDegree();
                int fovDegreeY = 2.f * fabsf(kmRadiansToDegrees(atanf(tanf(kmDegreesToRadians((float)fovDegreeX / 2.f)) * displayHeight / displayWidth)));
                outputWidth = inputWidth * fovDegreeX / 360.f;
                outputHeight = inputHeight * fovDegreeY / 180.f;
            }
            else
            {
                outputWidth = inputWidth;
                outputHeight = inputHeight;
            }
            GLint maxTextureSize = 0;
            glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
            if (maxTextureSize > 0)
            {
                if (outputWidth > maxTextureSize)
                {
                    outputHeight = roundf((float)maxTextureSize * (float)outputHeight / (float)outputWidth);
                    outputWidth = maxTextureSize;
                }
                if (outputHeight > maxTextureSize)
                {
                    outputWidth = roundf((float)maxTextureSize * (float)outputWidth / (float)outputHeight);
                    outputHeight = maxTextureSize;
                }
            }
            snapshotRenderTexture = new GLRenderTexture(outputWidth, outputHeight);
        }
        /*
        else if (_capturing && isInCapturing)
        {
            outputWidth = _outputVideoSize.width;
            outputHeight = _outputVideoSize.height;
        }
         //*/
        else
        {
            outputWidth = _width;
            outputHeight = _height;
        }
        int outBoundWidth = outputWidth;
        int outBoundHeight = outputHeight;
        
        if (currentIsGlassMode)
        {
            if (outputWidth > outputHeight)
            {
                outBoundWidth /= 2;
            }
            else
            {
                outBoundHeight /= 2;
            }
        }
        int destRectWidth = outBoundWidth;
        int destRectHeight = outBoundHeight;
        if (PanoramaDisplayModePlain == currentPanoramaMode || PanoramaDisplayModeReFlatten == currentPanoramaMode)
        {
            if (inputWidth <= 0 || inputHeight <= 0)
            {
                inputWidth = outputWidth;
                inputHeight = outputHeight;
            }
            
            if (destRectHeight * inputWidth / inputHeight > destRectWidth)
            {
                destRectHeight = destRectWidth * inputHeight / inputWidth;
            }
            else if (destRectWidth * inputHeight / inputWidth > destRectHeight)
            {
                destRectWidth = destRectHeight * inputWidth / inputHeight;
            }
        }
        //#ifdef DEBUGGING_FILTERS
        //        if (true || currentIsGlassMode)
        //        {
        //#else
        if (0 != currentFilterID || currentIsGlassMode)
        {
            //#endif
            if (NULL == _renderTexture0)
            {
                _renderTexture0 = new GLRenderTexture(outBoundWidth * RenderTextureScale, outBoundHeight * RenderTextureScale);
                //                _renderTexture0 = new GLRenderTexture(_outputVideoSize.width, _outputVideoSize.height);
            }
            else
            {
                bool resized = _renderTexture0->resizeIfNecessary(outBoundWidth * RenderTextureScale, outBoundHeight * RenderTextureScale);
                //                bool resized = _renderTexture0->resizeIfNecessary(_outputVideoSize.width, _outputVideoSize.height);
                if (resized)
                {
                    NSLog(@"Resized : ");
                }
            }
            CHECK_GL_ERROR();
            //#ifdef DEBUGGING_FILTERS
            //                if (true && currentIsGlassMode)
            //#else
            if (0 != currentFilterID && currentIsGlassMode)
            //#endif
            {
                if (NULL == _renderTexture1)
                {
                    _renderTexture1 = new GLRenderTexture(outBoundWidth * RenderTextureScale, outBoundHeight * RenderTextureScale);
                }
                else
                {
                    bool resized = _renderTexture1->resizeIfNecessary(outBoundWidth * RenderTextureScale, outBoundHeight * RenderTextureScale);
                    if (resized)
                    {
                        NSLog(@"Resized : ");
                    }
                }
            }
            CHECK_GL_ERROR();
        }
        
        Orientation2D renderOrientation = OrientationNormal;
        if (_snapshotDestPath)
        {
            snapshotRenderTexture->blit();
        }/*
        else if (_capturing && NULL != _recorderRenderTexture && isInCapturing)
        {
            _recorderRenderTexture->blit();
            renderOrientation = OrientationRotate180DegreeMirror;
        }
        //*/
        glViewport(0, 0, outputWidth, outputHeight);
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        //        glClearColor((rand() % 256)/255.f, (rand() % 256)/255.f, (rand() % 256)/255.f, 1);///!!!
        glClear(GL_COLOR_BUFFER_BIT);
        CHECK_GL_ERROR();
        //            NSLog(@"MyGLView draw : (0, 0, %d, %d)", outputWidth, outputHeight);
        //#ifdef DEBUGGING_FILTERS
        //            if (true)
        //#else
        if (0 != currentFilterID)
        //#endif
        {
            if (currentIsGlassMode)
            {
                _renderTexture0->blit();
                _renderer->draw(currentRenderMode, 0, 0, _renderTexture0->getWidth(), _renderTexture0->getHeight(), false, currentSourceTextureTarget, currentSourceTextureL, currentSourceTextureR);
                _renderTexture0->unblit();
                
                _renderTexture1->blit();
                _filterCache->render(currentFilterID, 0, 0, _renderTexture1->getWidth(), _renderTexture1->getHeight(), _renderTexture0->getTexture(), GL_TEXTURE_2D, OrientationNormal, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                _renderTexture1->unblit();
                
                if (outputWidth > outputHeight)
                {
                    _filterCache->render(0, (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture1->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                    _filterCache->render(0, outBoundWidth + (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture1->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                }
                else
                {
                    _filterCache->render(0, (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture1->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                    _filterCache->render(0, (outBoundWidth - destRectWidth) / 2, outBoundHeight + (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture1->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                }
            }
            else
            {
                _renderTexture0->blit();
                _renderer->draw(currentRenderMode, 0, 0, _renderTexture0->getWidth(), _renderTexture0->getHeight(), false, currentSourceTextureTarget, currentSourceTextureL, currentSourceTextureR);
                _renderTexture0->unblit();
                
                _filterCache->render(currentFilterID, (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture0->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
            }
        }
        else if (currentIsGlassMode)
        {
            _renderTexture0->blit();
            _renderer->draw(currentRenderMode, 0, 0, _renderTexture0->getWidth(), _renderTexture0->getHeight(), false, currentSourceTextureTarget, currentSourceTextureL, currentSourceTextureR);
            _renderTexture0->unblit();
            
            if (outputWidth > outputHeight)
            {
                _filterCache->render(0, (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture0->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                _filterCache->render(0, outBoundWidth + (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture0->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
            }
            else
            {
                _filterCache->render(0, (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture0->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
                _filterCache->render(0, (outBoundWidth - destRectWidth) / 2, outBoundHeight + (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, _renderTexture0->getTexture(), GL_TEXTURE_2D, renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
            }
        }
        else
        {
            if (OrientationRotate180DegreeMirror == renderOrientation)
            {
                _renderer->setFlipY(true);
            }
            _renderer->draw(currentRenderMode, (outBoundWidth - destRectWidth) / 2, (outBoundHeight - destRectHeight) / 2, destRectWidth, destRectHeight, false, currentSourceTextureTarget, currentSourceTextureL, currentSourceTextureR);
            if (OrientationRotate180DegreeMirror == renderOrientation)
            {
                _renderer->setFlipY(false);
            }
        }
        
        if (_snapshotDestPath)
        {
            int blockLines = MaxBufferBytes / 4 / outputWidth;
            if (blockLines > outputHeight)
            {
                blockLines = outputHeight;
            }
            
            JPEGCompressOutput* imageOutput = startWritingImageToJPEG(_snapshotDestPath.UTF8String, GL_RGBA, GL_UNSIGNED_BYTE, 100, outputWidth, outputHeight);
            GLubyte* pixelData = (GLubyte*) malloc(4 * outputWidth * blockLines);
            
            bool finishedAppending = false;
            for (int iLine = outputHeight-blockLines; iLine >= 0; iLine -= blockLines)
            {
                glReadPixels(0, iLine, outputWidth, blockLines, GL_RGBA, GL_UNSIGNED_BYTE, pixelData);
                glFinish();
                if (!appendImageStrideToJPEG(imageOutput, pixelData, blockLines, true))
                {
                    finishedAppending = true;
                    break;
                }
                if (iLine < blockLines && iLine > 0)
                {
                    blockLines = iLine;
                }
            }
            
            if (!finishedAppending)
            {
                delete imageOutput;
            }
            free(pixelData);
            
            _snapshotDestPath = nil;
            if (_snapshotCompletionHandler)
            {
                _snapshotCompletionHandler();
            }
            
            snapshotRenderTexture->unblit();
            glViewport(0, 0, displayWidth, displayHeight);
            _filterCache->render(0, 0,0,displayWidth,displayHeight, snapshotRenderTexture->getTexture(), snapshotRenderTexture->getTextureTarget(), renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
            snapshotRenderTexture = NULL;
        }
        /*
        else if (_capturing && NULL != _recorderRenderTexture && isInCapturing)
        {
            _recorderRenderTexture->unblit();
            
            [_videoRecorder startRecording:30.f];
            if (_currentFrameTimestamp >= 0)
            {
                long timeMills = _currentFrameTimestamp;
                if (_startTimeMills >= 0)
                {
                    timeMills += (getCurrentTimeMills() - _startTimeMills);
                }
                
                if (timeMills < 1000)
                {
                    glFlush();
                }
                //NSLog(@"#VideoCapture# recordOneFrame at time: %d, _currentFrameTimestamp=%ld, _startTimeMills=%ld, videoFrameTime = %d", (int)timeMills, _currentFrameTimestamp, _startTimeMills, (int)_inputVideoFrameTimeStamp);
                [_videoRecorder recordOneFrame:(int)timeMills];
                if (self.encodingFrameBlock)
                {
                    self.encodingFrameBlock((float)timeMills / 1000.f);
                }
            }
            
            glViewport(0, 0, displayWidth, displayHeight);
            _filterCache->render(0, 0,0,displayWidth,displayHeight, _recorderRenderTexture->getTexture(), _recorderRenderTexture->getTextureTarget(), renderOrientation, Vec2f{0.f, 0.f}, Vec2f{1.0f, 1.0f});
        }
         //*/
    }
    _renderer->setDisplayMode(currentRenderMode);
    //*/
#ifdef USE_MSAA
    CHECK_GL_ERROR();
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _framebuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, _msaaFramebuffer);
    CHECK_GL_ERROR();
    //    glResolveMultisampleFramebufferAPPLE();
    //    CHECK_GL_ERROR();
    //    GLenum attachments[] = {GL_DEPTH_ATTACHMENT};
    //    glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 1, attachments);
    glInvalidateFramebuffer(GL_READ_FRAMEBUFFER, 1, (GLenum[]){GL_DEPTH_ATTACHMENT});
    glBlitFramebuffer(0, 0, _width, _height, 0, 0, _width, _height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
    glInvalidateFramebuffer(GL_READ_FRAMEBUFFER, 1, (GLenum[]){GL_COLOR_ATTACHMENT0});
    CHECK_GL_ERROR();
#endif
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [[EAGLContext currentContext] presentRenderbuffer:GL_RENDERBUFFER];
    CHECK_GL_ERROR();
}

void runAsynchronouslyOnGLQueue(void(^block)()) {
    /*
     #pragma clang diagnostic push
     #pragma clang diagnostic ignored "-Wdeprecated-declarations"
     if (dispatch_get_current_queue() == sharedOpenGLQueue())
     #pragma clang diagnostic pop
     {
     block();
     }
     else
     {
     dispatch_async(sharedOpenGLQueue(), block);
     }
     /*/
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == dispatch_get_main_queue())
#pragma clang diagnostic pop
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
    //    block();
    //*/
}

- (void) requestRedraw {
}

- (void) takeSnapShot:(NSString*)destPath completion:(dispatch_block_t)completion {
    _snapshotDestPath = destPath;
    _snapshotCompletionHandler = completion;
}

@end

#pragma mark    MyGLView
@interface MyGLView () <GLRenderLoopDelegate>
{
    GLRenderLoop* _glRenderLoop;
}

@property (nonatomic, strong) GLRenderLoop* glRenderLoop;

@property (nonatomic, strong) CMMotionManager* motionManager;

@end

@implementation MyGLView

@synthesize interfaceOrientation;
@synthesize glRenderLoop = _glRenderLoop;

- (int) panoramaMode {
    return self.glRenderLoop.panoramaMode;
}
- (void) setPanoramaMode:(int)panoramaMode {
    self.glRenderLoop.panoramaMode = panoramaMode;
}

- (int) filterID {
    return self.glRenderLoop.filterID;
}
- (void) setFilterID:(int)filterID {
    self.glRenderLoop.filterID = filterID;
}

- (BOOL) isGlassMode {
    return self.glRenderLoop.isGlassMode;
}
- (void) setIsGlassMode:(BOOL)isGlassMode {
    self.glRenderLoop.isGlassMode = isGlassMode;
}

- (BOOL) isYUVColorSpace {
    return self.glRenderLoop.isYUVColorSpace;
}
- (void) setIsYUVColorSpace:(BOOL)isYUVColorSpace {
    self.glRenderLoop.isYUVColorSpace = isYUVColorSpace;
}

+ (Class) layerClass {
    return CAEAGLLayer.class;
}

- (void) dealloc {
    NSLog(@"EAGLContext : MyGLView dealloc %lx, glRenderLoop = %lx",  self.hash, self.glRenderLoop.hash);
}

- (void) glRenderLoopSetupGLRenderbuffer:(GLRenderLoop *)renderLoop {
    [[EAGLContext currentContext] renderbufferStorage:GL_RENDERBUFFER fromDrawable:((CAEAGLLayer*)self.layer)];
}

- (void) glRenderLoop:(GLRenderLoop *)renderLoop frameTimeTicked:(int)millseconds {
    
}

- (instancetype) initWithFrame:(CGRect)frame lutPath:(NSString*)lutPath lutSrcSizeL:(CGSize)lutSrcSizeL lutSrcSizeR:(CGSize)lutSrcSizeR outputVideoBaseName:(NSString*)outputVideoBaseName encoderQualityLevel:(QualityLevel)qualityLevel forCapturing:(BOOL)forCapturing {
    if (self = [super initWithFrame:frame])
    {
        self.backgroundColor = [UIColor clearColor];
        self.layer.backgroundColor = [UIColor clearColor].CGColor;
        
        self.interfaceOrientation = UIInterfaceOrientationPortrait;
        
        CAEAGLLayer* layer = (CAEAGLLayer*) self.layer;
        layer.opaque = YES;
        layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    //If use glReadPixels to get pixel data after presentRenderbuffer, RetainedBacking should be set to YES:
                                    [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        self.layer.contentsScale = [UIScreen mainScreen].scale;
        
        self.motionManager = nil;
        
        UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanRecognized:)];
        [self addGestureRecognizer:panRecognizer];
        
        UIPinchGestureRecognizer* pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onPinchRecognized:)];
        [self addGestureRecognizer:pinchRecognizer];
        
        UITapGestureRecognizer* doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTapRecognized:)];
        doubleTapRecognizer.numberOfTapsRequired = 2;
        doubleTapRecognizer.numberOfTouchesRequired = 1;
        [self addGestureRecognizer:doubleTapRecognizer];
        
        self.glRenderLoop = [[GLRenderLoop alloc] initWithDelegate:self lutPath:lutPath lutSrcSizeL:lutSrcSizeL lutSrcSizeR:lutSrcSizeR inputFrameSize:CGSizeMake(frame.size.width * self.contentScaleFactor, frame.size.height * self.contentScaleFactor) outputVideoBaseName:outputVideoBaseName encoderQualityLevel:qualityLevel forCapturing:forCapturing];
    }
    return self;
}

- (void) pause {
    [self stopMotionManager];
    [self.glRenderLoop pauseRendering];
}

- (void) resume {
    [self.glRenderLoop resumeRendering];
    [self startMotionManager];
}

- (void) willDisappear {
    NSLog(@"EAGLContext : MyGLView willDisappear @ %lx, glRenderLoop = %lx", self.hash, self.glRenderLoop.hash);
    ///!!![self stopMotionManager];
    [self.glRenderLoop stopRendering];
    
    //[self.glRenderLoop stopEncoding:nil];
}

- (void) willAppear {
    NSLog(@"EAGLContext : MyGLView willAppear @ %lx, glRenderLoop = %lx",  self.hash, self.glRenderLoop.hash);
    [self.glRenderLoop stopOtherRenderLoopIfAny];
    [self.glRenderLoop startRendering];
    ///!!![self startMotionManager];
}

- (void) stopMotionManager {
    @synchronized (self)
    {
        if (!self.motionManager)
        {
            return;
        }
        [self.motionManager stopDeviceMotionUpdates];
        self.motionManager = nil;
        
        [self.glRenderLoop setIsGyroEnabled:NO];
    }
}

- (void) startMotionManager {
    @synchronized (self)
    {
        if (self.motionManager)
        {
            return;
        }
        self.motionManager = [[CMMotionManager alloc] init];
        if (self.motionManager.deviceMotionAvailable)
        {
            [self.motionManager stopDeviceMotionUpdates];
            //        self.motionManager.accelerometerUpdateInterval = .2;
            //        self.motionManager.gyroUpdateInterval = .2;
            self.motionManager.deviceMotionUpdateInterval = 1.f / 30.f;
            
            __weak __typeof(self) wSelf = self;
            UIInterfaceOrientation startOrientation = self.interfaceOrientation;
            [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
                __strong __typeof(self) pSelf = wSelf;
                if (!pSelf) return;
                
                CMAttitude* attitude = motion.attitude;
                [pSelf.glRenderLoop onGyroQuaternionChanged:attitude orientation:pSelf.interfaceOrientation startOrientation:startOrientation];
            }];
            
            [self.glRenderLoop setIsGyroEnabled:YES];
        }
    }
}

- (void) willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview == nil)
    {
        NSLog(@"EAGLContext : MyGLView willMoveToSuperview (nil) @ %lx, glRenderLoop = %lx",  self.hash, self.glRenderLoop.hash);
        [self willDisappear];
    }
    else
    {
        NSLog(@"EAGLContext : MyGLView willMoveToSuperview @ %lx, glRenderLoop = %lx",  self.hash, self.glRenderLoop.hash);
    }
}

- (void) didMoveToSuperview {
    if (self.superview)
    {
        NSLog(@"EAGLContext : MyGLView didMoveToSuperview @ %lx, glRenderLoop = %lx",  self.hash, self.glRenderLoop.hash);
        [self willAppear];
    }
    else
    {
        NSLog(@"EAGLContext : MyGLView didMoveToSuperview (nil) @ %lx, glRenderLoop = %lx",  self.hash, self.glRenderLoop.hash);
    }
}

- (void)layoutSubviews {
    CHECK_GL_ERROR();
    [self.glRenderLoop invalidateRenderbuffer];
}

- (void) onPanRecognized : (UIPanGestureRecognizer*)panRecognizer {
    [self.glRenderLoop onPanRecognized:panRecognizer];
}

- (void) onPinchRecognized:(UIPinchGestureRecognizer*)pinchRecognizer {
    [self.glRenderLoop onPinchRecognized:pinchRecognizer];
}

- (void) onDoubleTapRecognized:(UITapGestureRecognizer*)tapRecognizer {
    [self.glRenderLoop onDoubleTapRecognized:tapRecognizer];
}

- (void) resetViewPosition {
    [self.glRenderLoop resetViewPosition];
}

- (void) takeSnapShot:(NSString*)destPath completion:(dispatch_block_t)completion {
    [self.glRenderLoop takeSnapShot:destPath completion:completion];
}

@end
