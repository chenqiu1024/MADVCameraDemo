//
//  ViewController.m
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import "KxMovieViewController.h"
#import <SSZipArchive.h>
#import "MyGLView.h"
#import "MadvGLRenderer_iOS.h"
#import "NSRecursiveCondition.h"
#import "CycordVideoRecorder.h"
#include "AudioRingBuffer.h"

//#define USE_KXGLVIEW
#define checkStatus(...) assert(0 == __VA_ARGS__)
NSString * const KxMovieParameterMinBufferedDuration = @"KxMovieParameterMinBufferedDuration";
NSString * const KxMovieParameterMaxBufferedDuration = @"KxMovieParameterMaxBufferedDuration";
NSString * const KxMovieParameterDisableDeinterlacing = @"KxMovieParameterDisableDeinterlacing";

////////////////////////////////////////////////////////////////////////////////

NSString* formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;

    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%0.2ld:%0.2ld", (long)h, (long)m];
    else        [format appendFormat:@"%0.2ld", (long)m];
//    [format appendFormat:@"%d:%0.2d", h, m];
    [format appendFormat:@":%0.2ld", (long)s];
//    [format appendFormat:@"%ld:%0.2ld", (long)h, (long)m];
//    [format appendFormat:@":%0.2ld", (long)s];

    return format;
}

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

//static NSMutableDictionary * gHistory;

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
//#define NETWORK_MIN_BUFFERED_DURATION 2.0
//#define NETWORK_MAX_BUFFERED_DURATION 4.0
#define NETWORK_MIN_BUFFERED_DURATION 0.3
#define NETWORK_MAX_BUFFERED_DURATION 1.2

#define RTSP_NETWORK_MIN_BUFFERED_DURATION 0.16
#define RTSP_NETWORK_MAX_BUFFERED_DURATION 0.5

#define GyroDataFrameNumberOffset 0

#ifdef ENCODING_WITHOUT_MYGLVIEW
@interface KxMovieViewController () <GLRenderLoopDelegate> {
#else
    @interface KxMovieViewController () {
#endif
    KxMovieDecoder      *_decoder;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSMutableArray      *_subtitles;
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    CGFloat             _moviePosition;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    
    BOOL                _disableUpdateHUD;
    BOOL                _fullscreen;
    BOOL                _fitMode;
    BOOL                _restoreIdleTimer;
    BOOL                _interrupted;
#ifdef USE_KXGLVIEW
    KxMovieGLView       *_glView;
#else
    MyGLView*           _glView;
#endif
#ifdef ENCODING_WITHOUT_MYGLVIEW
    GLRenderLoop*       _encoderRenderLoop;
#endif
    int _panoramaMode;
//    UIActivityIndicatorView* _activityIndicatorView;

    NSString*           _contentPath;
    NSString*           _audioOutputPath;
    //UIImageView         *_imageView;
    
    ExtAudioFileRef _audioFileRef;
    AudioStreamBasicDescription _audioFormat;

#ifdef DEBUG
    UILabel             *_messageLabel;
    NSTimeInterval      _debugStartTime;
    NSUInteger          _debugAudioStatus;
    NSDate              *_debugAudioStatusTS;
#endif

    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    BOOL                _buffered;///??? Should be named "buffering"?
    
    BOOL                _savedIdleTimer;
    
    NSDictionary        *_parameters;
    
//    UIView* _presentView;
//    BOOL _isViewAppearing;
    
    AudioRingBuffer      _audioRingBuf;
}

@property (readwrite) BOOL playing;
@property (readwrite) BOOL decoding;
@property (readwrite) BOOL audioRecording;
@property (readwrite, strong) KxArtworkFrame *artworkFrame;

@property (nonatomic, strong) NSMutableArray* videoFrames;
//@property (nonatomic, strong) KxMovieDecoder* decoder;

@property (nonatomic, strong) NSMutableArray* subtitles;

@property (nonatomic, assign) CGFloat moviePosition;

@property (nonatomic, assign) float FPS;

@property (nonatomic, assign) int gyroDataBytesOffset;
@property (nonatomic, strong) NSData* gyroData;
@property (nonatomic, assign) int bytesPerGyroStringLine;
@property (nonatomic, assign) int gyroStringBytesSize;

@end

@implementation KxMovieViewController

@synthesize isUsedAsEncoder;
@synthesize isUsedAsCapturer;
@synthesize isUsedAsVideoEditor;
@synthesize encoderQualityLevel;
@synthesize decoder = _decoder;
@synthesize moviePosition = _moviePosition;
@synthesize subtitles = _subtitles;
@synthesize glView = _glView;
@synthesize videoFrames = _videoFrames;

@synthesize isGlassMode;
@synthesize panoramaMode = _panoramaMode;

@synthesize isCameraGyroAdustEnabled;

@synthesize isLoadingViewVisible;

@synthesize encodingProgressChangedBlock;
@synthesize encodingDoneBlock;

@synthesize FPS;
@synthesize gyroDataBytesOffset;
@synthesize gyroData;
@synthesize bytesPerGyroStringLine;
@synthesize gyroStringBytesSize;
    
#ifdef ENCODING_WITHOUT_MYGLVIEW
@synthesize encoderRenderLoop = _encoderRenderLoop;
#endif
    
- (BOOL) isCameraGyroDataAvailable {
    return self.gyroStringBytesSize > 0;
}

- (void) setPanoramaMode:(int)panoramaMode {
    _panoramaMode = panoramaMode;
#ifdef ENCODING_WITHOUT_MYGLVIEW
    self.encoderRenderLoop.panoramaMode = panoramaMode;
#endif
    self.glView.panoramaMode = panoramaMode;
}

- (int) panoramaMode {
    return _panoramaMode;
}

- (void) setFOVRange:(int)initFOV maxFOV:(int)maxFOV minFOV:(int)minFOV {
    [self.glView.glRenderLoop setFOVRange:initFOV maxFOV:maxFOV minFOV:minFOV];
}
    
+ (void)initialize
{
    NSLog(@"initialize");
//    if (!gHistory)
//        gHistory = [NSMutableDictionary dictionary];
}

- (void) doInit {
    NSLog(@"doInit");
    self.isGlassMode = NO;
//    self.displayMode = PanoramaDisplayModeStereoGraphic | PanoramaDisplayModeLUT;
    self.panoramaMode = PanoramaDisplayModeStereoGraphic;
    
    self.isCameraGyroAdustEnabled = NO;
    self.gyroDataBytesOffset = 0;
    self.gyroData = nil;
    self.bytesPerGyroStringLine = 36;
    self.gyroStringBytesSize = 0;
    self.FPS = 29.97f;
    _previousMoviePosition = 0;
    
    self.isLoadingViewVisible = YES;
    self.audioRecording = NO;
    NSLog(@"doInit audioRecording = NO");
    
    _audioRingBuf.Create(1024 * 1024);
    
//    _presentView = nil;
//    _isViewAppearing = NO;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder {
    
    NSLog(@"initWithCoder");
    if (self = [super initWithCoder:aDecoder])
    {
        [self doInit];
    }
    return self;
}

- (instancetype) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    NSLog(@"initWithNibName %s", nibNameOrNil);
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [self doInit];
    }
    return self;
}

- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
{
    
    NSLog(@"initWithContentPath %f", path);
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self doInit];
        [self setContentPath:path parameters:parameters];
    }
    return self;
}

#ifdef DEBUG_VIDEOFRAME_LEAKING
//- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
//    if ([@"videoFrames.count" isEqualToString:keyPath])
//    {
//        NSLog(@"EAGLContext : KxMovieViewController $ observeValueForKeyPath : _videoFrames.count = %ld", (long)_videoFrames.count);
//    }
//}
#endif

static int s_liveObjects = 0;
static __weak id s_retainer = nil;

+ (NSRecursiveCondition*) sharedCondition {
    static NSRecursiveCondition* s_cond;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s_cond = [[NSRecursiveCondition alloc] init];
    });
    return s_cond;
}

+ (int) decreaseLiveObjectsCount {
    int ret;
    [[self.class sharedCondition] lock];
    {
        ret = --s_liveObjects;
        NSLog(@"#VideoLeak# MediaPlayerViewController $ -- : liveObjects = %d", s_liveObjects);
        [[self.class sharedCondition] broadcast];
    }
    [[self.class sharedCondition] unlock];
    return ret;
}

+ (int) increaseLiveObjectsCount:(id)retainer {
    int ret;
    [[self.class sharedCondition] lock];
    {
        if (retainer != s_retainer)
        {
            s_retainer = retainer;
#ifdef WAIT_UNTIL_PREVIOUS_MEDIAPLAYERVIEWCONTROLLER_DEALLOC
            while (s_liveObjects > 0)
            {
                NSLog(@"#VideoLeak# MediaPlayerViewController $ ++ Wait : liveObjects = %d", s_liveObjects);
                [[self.class sharedCondition] wait];
            }
#endif
            ret = ++s_liveObjects;
            NSLog(@"#VideoLeak# MediaPlayerViewController $ ++ : liveObjects = %d", s_liveObjects);
        }
        else
        {
            ret = s_liveObjects;
        }
    }
    [[self.class sharedCondition] unlock];
    return ret;
}

- (void) dealloc
{
#ifdef DEBUG_VIDEOFRAME_LEAKING
//    [self removeObserver:self forKeyPath:@"videoFrames.count"];
#endif
    
    //NSLog(@"#Codec# KxMovieViewController dealloc # pause @ %@", self);
    [self pause];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_dispatchQueue) {
        // Not needed as of ARC.
        //        dispatch_release(_dispatchQueue);
        _dispatchQueue = NULL;
    }
    if (_dispatchQueueAudioRecord) {
        _dispatchQueueAudioRecord = NULL;
    }
    [self freeBufferedFrames]; //2016.3.3 spy
    
    LoggerStream(1, @"%@ dealloc", self);
    
    if ([self isKindOfClass:NSClassFromString(@"MediaPlayerViewController")] && _contentPath && _contentPath.length)
    {
        NSLog(@"#VideoLeak# MediaPlayerViewController $ dealloc");
        [KxMovieViewController decreaseLiveObjectsCount];
    }
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void) setContentPath:(NSString*)path
             parameters:(NSDictionary*)parameters {
    _contentPath = path;
                 
    NSLog(@"setContentPath %s",path);
    NSAssert(path.length > 0, @"empty path");
    if (!isUsedAsEncoder) {
        id<KxAudioManager> audioManager = [KxAudioManager audioManager];
        [audioManager activateAudioSession];
    }
                     
    _moviePosition = 0;
    //        self.wantsFullScreenLayout = YES;
    
    _parameters = parameters;
    
    __weak KxMovieViewController *weakSelf = self;
    KxMovieDecoder *decoder = [[KxMovieDecoder alloc] init];
                 //NSLog(@"#Codec# KxMovieViewController setContentPath # decoder = %@, @ %@", decoder, self);
    
    decoder.interruptCallback = ^BOOL(){
        __strong KxMovieViewController *strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong typeof(self) pSelf = weakSelf;
        if (!pSelf) return;
        
        if ([pSelf isKindOfClass:NSClassFromString(@"MediaPlayerViewController")] && ![[[path lastPathComponent] stringByDeletingPathExtension] isEqualToString:SPLASH_MEDIA_NAME])
        {
            [KxMovieViewController increaseLiveObjectsCount:pSelf];
        }
        
        NSError *error = nil;
        [decoder openFile:path error:&error];

        if (decoder.fps > 0)
        {
            pSelf.FPS = decoder.fps;
        }

        if (![path hasPrefix:RTSP_URL_SCHEME] && ![path hasPrefix:RTMP_URL_SCHEME])
        {
            NSLog(@"#Gyro# _gyroStringBytesSize#0 = %d", pSelf.gyroStringBytesSize);
            pSelf.gyroStringBytesSize = decoder.getGyroSize;
            NSLog(@"#Gyro# _gyroStringBytesSize#1 = %d", pSelf.gyroStringBytesSize);
            if (0 != pSelf.gyroStringBytesSize)
            {
                pSelf.gyroData = [NSData dataWithBytes:decoder.getGyroData length:pSelf.gyroStringBytesSize];
                NSLog(@"#Gyro# _bytesPerGyroStringLine#0 = %d", pSelf.bytesPerGyroStringLine);
                pSelf.bytesPerGyroStringLine = decoder.getGyroSizePerFrame;
                NSLog(@"#Gyro# _bytesPerGyroStringLine#1 = %d", pSelf.bytesPerGyroStringLine);
//                ///For Debug:
//                int frames = pSelf.gyroStringBytesSize / pSelf.bytesPerGyroStringLine;
//                float matrix[9];
//                for (int i=0; i<frames; ++i)
//                {
//                    if ([self getGyroMatrix:matrix frameNumber:i])
//                    {
//                        NSLog(@"#Gyro# VideoGyroData[%d]: {%0.3f,%0.3f,%0.3f; %0.3f,%0.3f,%0.3f; %0.3f,%0.3f,%0.3f}", i, matrix[0],matrix[1],matrix[2],matrix[3],matrix[4],matrix[5],matrix[6],matrix[7],matrix[8]);
//                    }
//                }
            }
        }
        
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (weakSelf.gyroStringBytesSize > 0) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:GYRODATAAVAILABLE object:nil];
                }
                
                [weakSelf setMovieDecoder:decoder withError:error];
            });
//        return;///!!!For Debug 0301
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) pSelf = weakSelf;
        [pSelf showWaitView];
    });
    
}

- (void) viewDidLoad {
    
    NSLog(@"viewDidLoad");
     LoggerStream(1, @"loadView");
    CGRect bounds = [[UIScreen mainScreen] applicationFrame];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.view.tintColor = [UIColor blackColor];
    
//    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
//    _activityIndicatorView.center = self.view.center;
//    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
//    [self.view addSubview:_activityIndicatorView];
    
#ifdef DEBUG
    CGFloat width = bounds.size.width;
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,40,width-40,40)];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.textColor = [UIColor redColor];
    _messageLabel.hidden = YES;
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.numberOfLines = 2;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_messageLabel];
#endif
    
    if (_decoder) {
        [self setupPresentView];
    }
}

- (void)didReceiveMemoryWarning
{
    //NSLog(@"#Codec# KxMovieViewController didReceiveMemoryWarning #0 @ %@", self);
    [super didReceiveMemoryWarning];
 
    if (self.playing) {
        
        //NSLog(@"#Codec# KxMovieViewController didReceiveMemoryWarning # pause @ %@", self);
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            LoggerStream(0, @"didReceiveMemoryWarning, disable buffering and continue playing @ %@", self);
            
        } else {
            
            // force ffmpeg to free allocated memory
            
            //NSLog(@"#Codec# KxMovieViewController didReceiveMemoryWarning closeFile1 @ %@", self);
            [_decoder closeFile];
            ///!!![_decoder openFile:nil error:nil];
        }
        
    } else {
        //NSLog(@"#Codec# KxMovieViewController didReceiveMemoryWarning closeFile2 @ %@", self);
        [self freeBufferedFrames];
        [_decoder closeFile];
        ///???[_decoder openFile:nil error:nil];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    /*
    do
    {
        @synchronized (self)
        {
            if (!_presentView || _isViewAppearing)
            {
                _isViewAppearing = YES;
                break;
            }
            _isViewAppearing = YES;
        }
        [self didSetupPresentView:_presentView];
    }
    while (false);
    //*/
    if(!self.isFinishEncoder)
    {
        //NSLog(@"#Codec# KxMovieViewController viewDidAppear @ %@", self);
        LoggerStream(1, @"viewDidAppear");

        _interrupted = NO;///!!!qiudong
        
        if (self.presentingViewController)
            [self fullscreenMode:NO];///!!!YES
        
        //_savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
        
        if (_decoder) {
            //NSLog(@"#Codec# KxMovieViewController viewDidAppear # restorePlay @ %@", self);
            if(!self.isStopPlay)
            {
                [self restorePlay];
            }
        }
        else {
            //        [self showWaitView];
            //        [_activityIndicatorView startAnimating];
        }
        NSLog(@"EAGLContext : KxMovieViewController $ viewDidAppear # _glView = %lx, glRenderLoop = %lx", _glView.hash, _glView.glRenderLoop.hash);
        [self.glView.glRenderLoop stopOtherRenderLoopIfAny];
        [self.glView.glRenderLoop startRendering];
    }
    
    
    
}

- (void) viewWillDisappear:(BOOL)animated
{
    NSLog(@"EAGLContext : kxMovieViewController viewWillDisappear %d, glView = %@, glRenderLoop = %lx", animated, self.glView, self.glView.glRenderLoop.hash);
    //NSLog(@"#Codec# KxMovieViewController viewWillDisappear #0 @ %@", self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];

    [self dismissWaitView];
//    [_activityIndicatorView stopAnimating];
    if (_decoder) {
        //NSLog(@"#Codec# KxMovieViewController viewWillDisappear # pause @ %@", self);
        [self pause];
        /*
        if (_moviePosition == 0 || _decoder.isEOF)
            [gHistory removeObjectForKey:_decoder.path];
        else if (!_decoder.isNetwork)
            [gHistory setValue:[NSNumber numberWithFloat:_moviePosition]
                        forKey:_decoder.path];
        //*/
    }
    
    if (_fullscreen)
        [self fullscreenMode:NO];
        
    //[[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    
    _buffered = NO;
    _interrupted = YES;
    NSLog(@"EAGLContext(%@) : KxMovieViewController $ viewWillDisappear # Before MyGLView stopRendering @ %lx, glRenderLoop = %lx", [NSThread currentThread],  self.glView.hash, self.glView.glRenderLoop.hash);
    
#ifdef ENCODING_WITHOUT_MYGLVIEW
    if (!self.isUsedAsEncoder) {
        [GLRenderLoop stopCurrentRenderLoop];
    }
#else
    [GLRenderLoop stopCurrentRenderLoop];
#endif
    
    LoggerStream(1, @"kxMovieViewController viewWillDisappear %@", self);
    //_isViewAppearing = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    //[GLRenderLoop stopCurrentRenderLoop];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;///!!!(interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - public

-(void) play
{
    
    //NSLog(@"#Codec# KxMovieViewController play #0 @ %@", self);
    if (self.playing)
    {
        //NSLog(@"#Codec# KxMovieViewController play # return because self.playing=YES @ %@", self);
        return;
    }
    
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        //NSLog(@"#Codec# KxMovieViewController play # return because !_decoder.validVideo || !_decoder.validAudio @ %@", self);
        return;
    }
    
    if (_interrupted)
    {
        //NSLog(@"#Codec# KxMovieViewController play # return because _interrupted @ %@", self);
        return;
    }

    self.playing = YES;
    _interrupted = NO;
    _tickCorrectionTime = 0;
    _tickCounter = 0;

#ifdef DEBUG
    _debugStartTime = -1;
#endif
    //NSLog(@"#Codec# KxMovieViewController play # asyncDecodeFrames @ %@", self);
    [self asyncDecodeFrames];

    __weak typeof(self) wSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!wSelf || !wSelf.playing) return;
        [wSelf tick];
    });

    if (_decoder.validAudio)
        [self enableAudio:YES];

    _disableUpdateHUD = NO;
    
    [self didPlay];
    //NSLog(@"#Codec# KxMovieViewController play # didPlay @ %@", self);
    LoggerStream(1, @"play movie");
}

- (void) didPlay {
}

- (void) pause
{
    //NSLog(@"#Codec# KxMovieViewController pause #0 @ %@", self);
    if (!self.playing)
    {
        //NSLog(@"#Codec# KxMovieViewController pause # return because self.playing=NO @ %@", self);
        return;
    }

    self.playing = NO;
    //_interrupted = YES;
    if (self.isUsedAsEncoder && _decoder.validAudio) {
        while(_audioFrames.count > 0)
            usleep(1000);
        NSLog(@"close the audio recorded file");
    }
    [self enableAudio:NO];
    [self didPause];
    LoggerStream(1, @"pause movie");
    //NSLog(@"#Codec# KxMovieViewController pause # didPause @ %@", self);
}

- (void) stop {
    //NSLog(@"#Codec# KxMovieViewController stop # pause @ %@", self);
    [self pause];
    
    //NSLog(@"#Codec# KxMovieViewController stop freeBufferedFrames @ %@", self);
    [self freeBufferedFrames];
    //[_decoder closeFile];
}

- (void) cancelEncoding {
    [self pause];
    NSLog(@"EAGLContext : ShotController viewWillDisappear freeBufferedFrames, glRenderLoop = %lx", self.glView.glRenderLoop.hash);
    [self freeBufferedFrames]; //2016.3.3 spy
    self.decoder = nil;
    
#ifdef ENCODING_WITHOUT_MYGLVIEW
    self.encoderRenderLoop.encodingError = [NSError errorWithDomain:@"MadvErrorEncodingCanceled" code:-2 userInfo:@{}];
    NSLog(@"#Bug2880# cancelEncoding : self.encoderRenderLoop.encodingError = %@", self.encoderRenderLoop.encodingError);
    [self.encoderRenderLoop stopRendering];
    NSLog(@"#Bug2880# cancelEncoding : 2");
    //[self.encoderRenderLoop stopEncoding:nil];
    NSLog(@"#Bug2880# cancelEncoding : 3");
    self.encoderRenderLoop = nil;
#endif

}

- (void) restartEncoding:(QualityLevel)encoderQuaLevel{
    self.encoderQualityLevel = encoderQuaLevel;
    [self setContentPath:_contentPath parameters:_parameters];
    [self play];
}

- (void) didPause {
    
}

- (void) setMoviePosition: (CGFloat) position
{
    
    NSLog(@"setMoviePosition position:%f", position);
    BOOL playMode = self.playing;
    
    self.playing = NO;
    [self enableAudio:NO];
    
    __weak typeof(self) wSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [wSelf updatePosition:position playMode:playMode];
    });
    
    _disableUpdateHUD = YES;
}

#pragma mark - private

- (void) setMovieDecoder: (KxMovieDecoder *) decoder
               withError: (NSError *) error
{
    
    //NSLog(@"#Codec# KxMovieViewController setMovieDecoder # decoder = %@, error = %@, @ %@", decoder, error, self);
    LoggerStream(2, @"setMovieDecoder");
            
    if (!error && decoder) {
        
        _decoder        = decoder;
        _dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        _dispatchQueueAudioRecord  = dispatch_queue_create("AudioRecord", DISPATCH_QUEUE_SERIAL);
        
        //dispatch_set_target_queue(_dispatchQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        _videoFrames    = [NSMutableArray array];
#ifdef DEBUG_VIDEOFRAME_LEAKING
//        [self addObserver:self forKeyPath:@"videoFrames.count" options:0 context:nil];
#endif
        _audioFrames    = [NSMutableArray array];
        
        if (_decoder.subtitleStreamsCount) {
            _subtitles = [NSMutableArray array];
        }
    
        if (_decoder.isNetwork) {
            if (_decoder.isRTSPLive) {
                NSLog(@"rtsp live buffer");
                _minBufferedDuration = RTSP_NETWORK_MIN_BUFFERED_DURATION;
                _maxBufferedDuration = RTSP_NETWORK_MAX_BUFFERED_DURATION;
            } else {
                NSLog(@"network buffer");
                _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
                _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
                if (_decoder.frameHeight > 1152) {
                    _maxBufferedDuration = 0.6;
                }
            }
            
        } else {
            
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
        
        if (!_decoder.validVideo)
            _minBufferedDuration *= 10.0; // increase for audio
                
        // allow to tweak some parameters at runtime
        if (_parameters.count) {
            
            id val;
            
            val = [_parameters valueForKey: KxMovieParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _minBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _maxBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]])
                _decoder.disableDeinterlacing = [val boolValue];
            
            if (_maxBufferedDuration < _minBufferedDuration)
                _maxBufferedDuration = _minBufferedDuration * 2;
        }
        
        LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
        if (self.isViewLoaded) {
            [self setupPresentView];
            
            [self dismissWaitView];
            /*
            if (_activityIndicatorView.isAnimating) {
                [_activityIndicatorView stopAnimating];
            }
             //*/
        }
        
    } else {
         if (self.isViewLoaded && self.view.window) {
             //[_activityIndicatorView stopAnimating];
             [self dismissWaitView];
             
             if (!_interrupted)
                 [self handleDecoderMovieError: error];
         }
    }
    
    [self didSetMovieDecoder:_decoder withError:error];
}

- (void) didSetMovieDecoder:(KxMovieDecoder*)decoder withError:(NSError*)error {
    
    NSLog(@"didSetMovieDecoder");
    if (!error && decoder)
    {
        if (self.isViewLoaded) {
            if(!self.isStopPlay)
            {
                [self restorePlay];
            }
        }
    }
}

- (void) restorePlay
{
    //NSLog(@"#Codec# KxMovieViewController restorePlay #0 @ %@", self);
    if (!_decoder)
    {
        //NSLog(@"#Codec# KxMovieViewController restorePlay # return0 @ %@", self);
        return;
    }
    else if (_decoder.isEOF)
    {
        
        //NSLog(@"#Codec# KxMovieViewController restorePlay # EOF @ %@", self);
        [self updatePosition:0.f playMode:YES];
        /*if (_moviePosition >= _decoder.duration)
            [self updatePosition:0.f playMode:YES];
        else
            [self updatePosition:_moviePosition playMode:YES];*/
    }
    else
    {
         /*NSNumber *n = [gHistory valueForKey:_decoder.path];
         if (n)
         [self updatePosition:n.floatValue playMode:YES];
         else*/
        if (self.previousMoviePosition) {
            NSLog(@"#Codec# KxMovieViewController restorePlay with previousMoviePosition @ %@", self);
            [self updatePosition:self.previousMoviePosition playMode:YES];
            self.previousMoviePosition = 0;
        }
        else if (self.editStartTime > 0 && self.isNewEditTime) {
            NSLog(@"#Codec# KxMovieViewController restorePlay # updatePosition starttime: %f @ %@", self.editStartTime, self);
            [self updatePosition:self.editStartTime playMode:YES];
            self.isNewEditTime = FALSE;
            //self.editStartTime = 0;
        }
        else
        {
            NSLog(@"#Codec# KxMovieViewController restorePlay # play @ %@", self);
            [self play];
        }
        
        //[self updatePosition:_moviePosition playMode:YES];
    }
}

    + (NSString*) outputVideoFileBaseName:(NSString*)contentPath qualityLevel:(QualityLevel)qualityLevel forExport:(BOOL)forExport {
        NSString* suffix = forExport ? @"_export" : @"_output";
        return [[[contentPath stringByDeletingPathExtension] lastPathComponent] stringByAppendingString:suffix];
    }
    
    + (NSString*) editorOutputVideoFileBaseName:(NSString*)contentPath {
        NSDateFormatter* formatter = [[NSDateFormatter alloc] init] ;
        [formatter setDateFormat:@"YYYYMMddHHmmss"];
        NSString* dateStr = [formatter stringFromDate:[NSDate date]];
        return [[[[contentPath stringByDeletingPathExtension] lastPathComponent] stringByAppendingString:@"_"] stringByAppendingString:dateStr];
    }
    
    + (NSString*) screenCaptureVideoFileBaseName:(NSString*)contentPath {
        NSString* baseName = [[contentPath stringByDeletingPathExtension] lastPathComponent];
        NSDateFormatter* formatter = [[NSDateFormatter alloc] init] ;
        [formatter setDateFormat:@"YYYYMMddHHmmss"];
        NSString* dateStr = [formatter stringFromDate:[NSDate date]];
        return [NSString stringWithFormat:@"%@%@_%@", SCREEN_CAPTURE_FILENAME_PREFIX, baseName, dateStr];
    }
    
    + (NSString*) encodedFileBaseName:(NSString*)contentPath qualityLevel:(QualityLevel)qualityLevel forExport:(BOOL)forExport {
        NSString* outputVideoBaseName = [self.class outputVideoFileBaseName:contentPath qualityLevel:qualityLevel forExport:forExport];
        outputVideoBaseName = [GLRenderLoop outputVideoBaseName:outputVideoBaseName qualityLevel:qualityLevel];
        return [CycordVideoRecorder outputMovieFileBaseName:outputVideoBaseName];
    }
    
- (void) setupPresentView
{
    NSLog(@"EAGLContext : KxMovieViewController $ setupPresentView");
    MyGLView* presentView = _glView;
    CGRect bounds = self.view.bounds;
    NSString* lutPath = MadvGLRenderer_iOS::lutPathOfSourceURI(_contentPath, NO, NO);
    if (_decoder.validVideo) {
        [_decoder setupVideoFrameFormat:KxVideoFrameFormatYUV];
#ifdef USE_KXGLVIEW
        presentView = [[KxMovieGLView alloc] initWithFrame:bounds decoder:_decoder];
#else
        NSString* outputVideoBaseName = nil;
        if (self.isUsedAsVideoEditor || self.isUsedAsCapturer)
        {
            outputVideoBaseName = [self.class editorOutputVideoFileBaseName:_contentPath];
        }
        else if (self.isUsedAsCapturer)
        {
            outputVideoBaseName = [self.class screenCaptureVideoFileBaseName:_contentPath];
        }
        else if (self.isUsedAsEncoder)
        {
            outputVideoBaseName = [self.class outputVideoFileBaseName:_contentPath qualityLevel:self.encoderQualityLevel forExport:self.isExport];
        }
#ifdef ENCODING_WITHOUT_MYGLVIEW
        if (self.isUsedAsEncoder)
        {
            if (self.encoderRenderLoop)
            {
                [self.encoderRenderLoop setLUTPath:lutPath lutSrcSizeL:CGSizeMake(3456, 1728) lutSrcSizeR:CGSizeMake(3456, 1728)];
                [self.encoderRenderLoop setVideoRecorder:outputVideoBaseName qualityLevel:self.encoderQualityLevel forCapturing:NO];
            }
            else
            {
                NSLog(@"EAGLContext : KxMovieViewController $ setupPresentView # self.encoderRenderLoop = %lx", self.encoderRenderLoop.hash);
                self.encoderRenderLoop = [[GLRenderLoop alloc] initWithDelegate:self lutPath:lutPath lutSrcSizeL:CGSizeMake(3456, 1728) lutSrcSizeR:CGSizeMake(3456, 1728) inputFrameSize:CGSizeMake(bounds.size.width * self.view.contentScaleFactor, bounds.size.height * self.view.contentScaleFactor) outputVideoBaseName:outputVideoBaseName encoderQualityLevel:self.encoderQualityLevel forCapturing:NO];
                self.encoderRenderLoop.encodingDoneBlock = self.encodingDoneBlock;
                self.encoderRenderLoop.encodingFrameBlock = self.encodingFrameBlock;
            }
            self.encoderRenderLoop.encodingError = nil;
        }
        else
#endif
        {
            if (presentView)
            {
                [presentView.glRenderLoop setLUTPath:lutPath lutSrcSizeL:CGSizeMake(3456, 1728) lutSrcSizeR:CGSizeMake(3456, 1728)];
                [presentView.glRenderLoop setVideoRecorder:outputVideoBaseName qualityLevel:self.encoderQualityLevel forCapturing:self.isUsedAsCapturer];
            }
            else
            {
                NSLog(@"EAGLContext : KxMovieViewController $ setupPresentView # _glView = (%@), PresentView = %@, glRenderLoop = %lx", _glView, presentView, _glView.glRenderLoop.hash);
                presentView = [[MyGLView alloc] initWithFrame:bounds lutPath:lutPath lutSrcSizeL:CGSizeMake(3456, 1728) lutSrcSizeR:CGSizeMake(3456, 1728) outputVideoBaseName:outputVideoBaseName encoderQualityLevel:self.encoderQualityLevel forCapturing:self.isUsedAsCapturer];
            }
            presentView.glRenderLoop.encodingDoneBlock = self.encodingDoneBlock;
            presentView.glRenderLoop.encodingFrameBlock = self.encodingFrameBlock;
        }
        
        if (self.isUsedAsEncoder && _decoder.validAudio) {
            //*
            outputVideoBaseName = [GLRenderLoop outputVideoBaseName:outputVideoBaseName qualityLevel:self.encoderQualityLevel];
            outputVideoBaseName = [CycordVideoRecorder outputAudioTmpFileBaseName:outputVideoBaseName];
            /*/
            if (self.encoderQualityLevel == QualityLevel4K)
                outputVideoBaseName = [outputVideoBaseName stringByAppendingString:@"4K"];
            else if (self.encoderQualityLevel == QualityLevel1080)
                outputVideoBaseName = [outputVideoBaseName stringByAppendingString:@"1080"];
            outputVideoBaseName = [outputVideoBaseName stringByAppendingPathExtension:@"aac"]; write by spy change audio file name
            //*/
            _audioOutputPath = [NSString stringWithFormat:@"%@/%@", [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"], outputVideoBaseName] ;
            
            // Describe format
            int kChannels = 2;
            unsigned int bytesPerSample = sizeof(float) * kChannels;

            memset(&_audioFormat, 0, sizeof(_audioFormat));
            _audioFormat.mFormatID = kAudioFormatMPEG4AAC;
            _audioFormat.mFormatFlags = kMPEG4Object_AAC_LC;
            //_audioFormat.mFormatID = kAudioFormatLinearPCM;
            //_audioFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat;
            _audioFormat.mSampleRate = 48000.00;
            _audioFormat.mFramesPerPacket = 1024;
            _audioFormat.mChannelsPerFrame = kChannels;
            //_audioFormat.mFramesPerPacket  = 1;
            //_audioFormat.mBytesPerFrame    = bytesPerSample;
            //_audioFormat.mBytesPerPacket   = bytesPerSample * _audioFormat.mFramesPerPacket;
            //_audioFormat.mBitsPerChannel    = 8 * sizeof(float);
            

            CFURLRef destinationURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)_audioOutputPath, kCFURLPOSIXPathStyle, false);
            OSStatus status = ExtAudioFileCreateWithURL(destinationURL, kAudioFileAAC_ADTSType, &_audioFormat, NULL, kAudioFileFlags_EraseFile, &_audioFileRef); //kAudioFileCAFType //write by spy aac file
            //OSStatus status = ExtAudioFileCreateWithURL(destinationURL, kAudioFileCAFType, &_audioFormat, NULL, kAudioFileFlags_EraseFile, &_audioFileRef); //kAudioFileCAFType //write by spy aac file
    
            checkStatus(status);
            CFRelease(destinationURL);
            
            UInt32 size;
            AudioStreamBasicDescription clientFormat;
            clientFormat.mFormatID          = kAudioFormatLinearPCM;
            clientFormat.mFormatFlags       = kAudioFormatFlagIsFloat;
            clientFormat.mBytesPerPacket    = bytesPerSample;
            clientFormat.mFramesPerPacket   = 1;
            clientFormat.mBytesPerFrame     = bytesPerSample;
            clientFormat.mChannelsPerFrame  = kChannels;  // 1 indicates mono
            clientFormat.mBitsPerChannel    = 8 * sizeof(float);
            clientFormat.mSampleRate        = 48000.00;
            
            size = sizeof( clientFormat );
            status = ExtAudioFileSetProperty( _audioFileRef, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat ); //write by spy setting input format
            checkStatus(status);
        }
#ifdef ENCODING_WITHOUT_MYGLVIEW
        if (self.isUsedAsEncoder)
        {
            self.encoderRenderLoop.panoramaMode = self.panoramaMode;
            
            KxVideoFrameFormat format = [_decoder getVideoFrameFormat];
            if (format == KxVideoFrameFormatYUV)
                self.encoderRenderLoop.isYUVColorSpace = YES;
            else
                self.encoderRenderLoop.isYUVColorSpace = NO;
            
            self.encoderRenderLoop.isGlassMode = self.isGlassMode;
            self.encoderRenderLoop.panoramaMode = self.panoramaMode;
            
            [self.encoderRenderLoop invalidateRenderbuffer];
            
            [self.encoderRenderLoop stopOtherRenderLoopIfAny];
            //是否转成低码率
            if (self.isShareEncoder) {
                [self.encoderRenderLoop setShareMode];
            }
            //if (!_decoder.isShareBitrateContent) {
                [self.encoderRenderLoop startRendering];
            //}
        }
        else
#endif
        {
            presentView.panoramaMode = self.panoramaMode;
            
            KxVideoFrameFormat format = [_decoder getVideoFrameFormat];
            if (format == KxVideoFrameFormatYUV)
                presentView.isYUVColorSpace = YES;
            else
                presentView.isYUVColorSpace = NO;
        }
        
#endif
    }
#ifdef ENCODING_WITHOUT_MYGLVIEW
    if (self.isUsedAsEncoder)
    {
        if (!self.encoderRenderLoop) {
            LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
            [_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
            //_imageView = [[UIImageView alloc] initWithFrame:bounds];
            //_imageView.backgroundColor = [UIColor blackColor];
            self.encoderRenderLoop = [[GLRenderLoop alloc] initWithDelegate:self lutPath:lutPath lutSrcSizeL:CGSizeMake(3456, 1728) lutSrcSizeR:CGSizeMake(3456, 1728) inputFrameSize:CGSizeMake(bounds.size.width * self.view.contentScaleFactor, bounds.size.height * self.view.contentScaleFactor) outputVideoBaseName:nil encoderQualityLevel:self.encoderQualityLevel forCapturing:NO];
            self.encoderRenderLoop.encodingDoneBlock = self.encodingDoneBlock;
            self.encoderRenderLoop.encodingFrameBlock = self.encodingFrameBlock;
            self.encoderRenderLoop.panoramaMode = self.panoramaMode;
            self.encoderRenderLoop.isYUVColorSpace = NO;
            
            KxVideoFrameFormat format = [_decoder getVideoFrameFormat];
            if (format == KxVideoFrameFormatYUV)
                self.encoderRenderLoop.isYUVColorSpace = YES;
            else
                self.encoderRenderLoop.isYUVColorSpace = NO;
        }
        if(self.isUsedAsVideoEditor)
        {
            self.encoderRenderLoop.filterID = self.filterID;
        }
        
    }
    else
#endif
    {
        if (!presentView) {
            LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
            [_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
            //_imageView = [[UIImageView alloc] initWithFrame:bounds];
            //_imageView.backgroundColor = [UIColor blackColor];
            presentView = [[MyGLView alloc] initWithFrame:bounds lutPath:lutPath lutSrcSizeL:CGSizeMake(3456, 1728) lutSrcSizeR:CGSizeMake(3456, 1728) outputVideoBaseName:nil encoderQualityLevel:self.encoderQualityLevel forCapturing:self.isUsedAsCapturer];
            presentView.glRenderLoop.encodingDoneBlock = self.encodingDoneBlock;
            presentView.glRenderLoop.encodingFrameBlock = self.encodingFrameBlock;
            presentView.panoramaMode = self.panoramaMode;
            presentView.isYUVColorSpace = NO;
            
            KxVideoFrameFormat format = [_decoder getVideoFrameFormat];
            if (format == KxVideoFrameFormatYUV)
                presentView.isYUVColorSpace = YES;
            else
                presentView.isYUVColorSpace = NO;
        }
    }
    
    if (_decoder.validVideo) {
        [self setupUserInteraction];
    } else {
        //_imageView.image = [UIImage imageNamed:@"kxmovie.bundle/music_icon.png"];
        //_imageView.contentMode = UIViewContentModeCenter;
    }
    
    self.view.backgroundColor = [UIColor clearColor];
    
    if (_glView != presentView)
    {
        if (_glView)
        {
            [_glView removeFromSuperview];
            NSLog(@"EAGLContext : KxMovieViewController $ setupPresentView # set _glView = nil (%@), PresentView = %@, glRenderLoop = %lx", _glView, presentView, _glView.glRenderLoop.hash);
            _glView = nil;
        }
        _glView = (MyGLView*) presentView;
        NSLog(@"EAGLContext : KxMovieViewController $ setupPresentView # set _glView = PresentView = %@, glRenderLoop = %lx", presentView, _glView.glRenderLoop.hash);
        _glView.isGlassMode = self.isGlassMode;
        _glView.panoramaMode = self.panoramaMode;
    }
    /*
    do
    {
        @synchronized (self)
        {
            if (_presentView || !_isViewAppearing)
            {
                _presentView = presentView;
                break;
            }
            _presentView = presentView;
        }
        [self didSetupPresentView:_presentView];
    }
    while (false);
     /*/
    if (presentView)
        [self didSetupPresentView:presentView];
     //*/
}

- (void) didSetupPresentView:(UIView*)presentView {
    
}

- (void) setupUserInteraction
{
    UIView * view = self.glView;
    view.userInteractionEnabled = YES;
    [self didSetupUserInteraction];
}

- (void) didSetupUserInteraction {
    
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    
    //NSLog(@"audioCallbackFillData numFrames:%d numChannels:%d", numFrames, numChannels);
    //fillSignalF(outData,numFrames,numChannels);
    //return;

    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }

    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = _audioFrames[0];
                       
#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        if (_decoder.validVideo) {
                        
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -0.1 && !(_videoFrames.count == 0 && _decoder.isEOF)) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
#ifdef DEBUG
//                                LoggerStream(0, @"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 1;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
                                
#ifdef DEBUG
//                                LoggerStream(0, @"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 2;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                continue;
                            }
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }

                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;                        
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;                
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
#ifdef DEBUG
                _debugAudioStatus = 3;
                _debugAudioStatusTS = [NSDate date];
#endif
                break;
            }
        }
    }
}

- (void) audioCallbackFillDataRecord
{
    
    //NSLog(@"audioCallbackFillDataRecord");
    //fillSignalF(outData,numFrames,numChannels);
    //return;
    UInt32 numFrames = 1024;
    UInt32 numChannels = 2;
    
    if (_buffered) {
        return;
    }
    
    @autoreleasepool {
        
        while (numFrames > 0 && !(_audioFrames.count == 0 && _videoFrames.count == 0 && _decoder.isEOF) && _audioRecording) {
            
            //NSLog(@"numFrames %d ac: %lu vc:%lu eof:%d audioRecording:%d", numFrames, (unsigned long)_audioFrames.count, (unsigned long)_videoFrames.count, _decoder.isEOF, _audioRecording);
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = _audioFrames[0];

#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        if (_decoder.validVideo) {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            NSLog(@"audioFrames--: %lu", _audioFrames.count);
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                            
                            if (self.isUsedAsVideoEditor && (_editEndTime - _editStartTime) > 0) {
                                //NSLog(@"audiorecord timestamp(before adjust) = %f", frame.timestamp);
                                frame.timestamp -= _editStartTime;
                            }
                        }
 
                        //NSLog(@"audiorecord timestamp = %f", frame.timestamp);
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                        
                        //write by spy
                        _audioRingBuf.Write((unsigned char*)_currentAudioFrame.bytes, (unsigned int)_currentAudioFrame.length);
                    }
                }
            }
            
            if (_currentAudioFrame) {
                //wrtie by spy
                int audioframesize = numFrames * numChannels  * sizeof(float);
                float pcm[numFrames * numChannels];
                while (_audioRingBuf.GetReadSize() >= audioframesize)
                {
                	_audioRingBuf.Read((unsigned char*)&pcm[0], audioframesize);
                    [self recordAudioFrame: numFrames channels: numChannels buf: (float*)&pcm[0]];
                }
                _currentAudioFrame = nil;
            }
        }
        
        NSLog(@"exited the loop: numFrames %d ac: %lu vc:%lu eof:%d audioRecording:%d", numFrames, (unsigned long)_audioFrames.count, (unsigned long)_videoFrames.count, _decoder.isEOF, _audioRecording);
    }
}

- (void) enableAudio: (BOOL) on
{
    NSLog(@"enableAudio %d", on);
    
    if (!isUsedAsEncoder) {
        id<KxAudioManager> audioManager = [KxAudioManager audioManager];
                
        if (on && _decoder.validAudio) {
            __weak typeof(self) wSelf = self;
            audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
                [wSelf audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
            };
                    
            [audioManager play];
            LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                            (int)audioManager.samplingRate,
                            (int)audioManager.numBytesPerSample,
                            (int)audioManager.numOutputChannels);
                
        } else {
            [audioManager pause];
            audioManager.outputBlock = nil;
        }
    } else {
        
        __weak KxMovieViewController *weakSelf = self;
        __weak KxMovieDecoder *weakDecoder = _decoder;
        
        if (on && _decoder.validAudio && !weakSelf.audioRecording) {
            weakSelf.audioRecording = YES;
            dispatch_async(_dispatchQueueAudioRecord, ^{
                NSLog(@"usedAsRecorder enableAudio : In _dispatchQueue");
                
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (!strongSelf || !strongSelf.playing)
                {
                    NSLog(@"usedAsRecorder enableAudio : Exit #1");
                    return;
                }
                
                while (strongSelf.audioRecording) {
                    @autoreleasepool {
                         [strongSelf audioCallbackFillDataRecord];
                    }
                }
                ExtAudioFileDispose(_audioFileRef);
                NSLog(@"usedAsRecorder exit enableAudio loop");
            });
        } else {
            weakSelf.audioRecording = NO;
            NSLog(@"usedAsRecorder enableAudio No: audioRecording = No");
        }
    }
}

- (BOOL) addFrames: (NSArray *)frames
{
    //NSLog(@"addFrames");
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            if (!self.playing)
            {
                [((NSMutableArray*) frames) removeAllObjects];
                return NO;
            }
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
#ifdef DEBUG_VIDEOFRAME_LEAKING
                    //NSLog(@"VideoLeak : _videoFrames addObject, count = %d", (int)_videoFrames.count);
#endif
                    _bufferedDuration += frame.duration;
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (self.isUsedAsEncoder)
                        NSLog(@"audioFrames++: %lu", _audioFrames.count);
                    if (!_decoder.validVideo)
                        _bufferedDuration += frame.duration;
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeArtwork)
                    self.artworkFrame = (KxArtworkFrame *)frame;
        }
    }
    
    if (_decoder.validSubtitles) {
        
        @synchronized(_subtitles) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeSubtitle) {
                    [_subtitles addObject:frame];
                }
        }
    }
    
    return self.playing && _bufferedDuration < _maxBufferedDuration;
}

- (BOOL) decodeFrames
{
    
    //NSLog(@"decodeFrames");
    //NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
    
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void) asyncDecodeFrames
{
    //NSLog(@"asyncDecodeFrames");
    if (self.decoding)
    {
        //NSLog(@"asyncDecodeFrames : Exit #0");
        return;
    }
    
    __weak KxMovieViewController *weakSelf = self;
    __weak KxMovieDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;///!!!
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        //NSLog(@"asyncDecodeFrames : In _dispatchQueue");
        {
            __strong KxMovieViewController *strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.playing)
            {
                //NSLog(@"asyncDecodeFrames : Exit #1");
                return;
            }
        }
        
        BOOL good = YES;
        while (good) {
            good = NO;
            
            @autoreleasepool {
                __strong KxMovieDecoder *decoder = weakDecoder;
                if (decoder && (decoder.validVideo || decoder.validAudio)) {
                    NSArray *frames = [decoder decodeFrames:duration];
                    //NSLog(@"asyncDecodeFrames : frames.count = %ld", frames.count);
                    if (frames.count) {
                        __strong KxMovieViewController *strongSelf = weakSelf;
                        if (strongSelf)
                        {
                            //NSLog(@"KxMovieViewController :: asyncDecodeFrames : addFrames");
                            good = [strongSelf addFrames:frames];
                            //NSLog(@"KxMovieViewController :: asyncDecodeFrames : addFrames good=%d", good);
                        } else {
                            //NSLog(@"KxMovieViewController :: asyncDecodeFrames : addFrames no");
                        }
                    }
                } else {
                    //NSLog(@"KxMovieViewController :: asyncDecodeFrames : decoder no");
                }
            }
        }
        //NSLog(@"exit asyncdecode loop");
                
        {
            __strong KxMovieViewController *strongSelf = weakSelf;
            if (strongSelf)
            {
                //NSLog(@"asyncDecodeFrames : Set decoding = NO");
                strongSelf.decoding = NO;
            }
        }
    });
}

- (void) didPlayOver {
    if (self.isUsedAsEncoder && _decoder.validAudio) {
        while(_audioFrames.count > 0)
            usleep(1000);
        [self enableAudio:NO];
        NSLog(@"close the audio recorded file");
    }
}

- (void) tick
{
    //NSLog(@"KxMovieViewController :: tick");
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _buffered = NO;
        [self dismissWaitView];
    }
    
    CGFloat interval = 0;
    if (!_buffered)
        interval = [self presentFrame];
    
    if (self.playing) {
        NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            if (_decoder.isEOF) {
                //NSLog(@"KxMovieViewController tick pause");
                
                [self pause];
                [self updateHUD];
                if ([self respondsToSelector:@selector(didPlayOver)]) {
                    [self didPlayOver];
                }
                return;
            }
            
            if (_minBufferedDuration > 0 && !_buffered) {
                _buffered = YES;
                NSLog(@"tick showWaitView");
                [self showWaitView];
            }
        }
        
        //for video-edit
        //NSLog(@"_decoder position %f editStartTime %f editEndTime %f", _decoder.position, _editStartTime, _editEndTime);
        if( _editEndTime > 0 && _decoder.position >= (_editEndTime - 0.1)) {
            NSLog(@"tick play over");
            [self pause];
            [self updateHUD];
            if ([self respondsToSelector:@selector(didPlayOver)]) {
                [self didPlayOver];
            }
            return;
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
           // //NSLog(@"#Codec# KxMovieViewController tick # asyncDecodeFrames @ %@", self);
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        __weak typeof(self) wSelf = self;
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (!wSelf || !wSelf.playing) return;
            [wSelf tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
        [self updateHUD];
    }
    
    int percent = 0;
    if ((_editEndTime - _editStartTime) > 0) {
        percent = roundf((_decoder.position - _editStartTime) * 100 / (_editEndTime - _editStartTime));
    }
    else {
        percent = roundf(_decoder.position * 100 / _decoder.duration);
    }
    [self didPlayProgressChanged:percent];
}

- (void) dismissWaitView {
    NSLog(@"dismissWaitView");
    [self dismissActivityIndicatorView];
}

- (void) showWaitView {
    if (!self.isLoadingViewVisible)
    {
        NSLog(@"showWaitView bypassed!");
        return;
    }
    NSLog(@"showWaitView");
    if (!self.isUsedAsEncoder) {
        [self showActivityIndicatorView];
    }
    
    //[_activityIndicatorView startAnimating];
}

- (CGFloat) tickCorrection
{
    
    //NSLog(@"tickCorrection");
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    if ((_tickCounter % 200) == 0)
        LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 1.f || correction < -1.f) {
        
        LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat) presentFrame
{
    
   // NSLog(@"presentFrame");
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        KxVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                if (self.isUsedAsVideoEditor && (_editEndTime - _editStartTime) > 0)
                    frame.timestamp -= _editStartTime * 1000;
                [_videoFrames removeObjectAtIndex:0];
                //NSLog(@"videorecord timestamp: %f", frame.timestamp);
#ifdef DEBUG_VIDEOFRAME_LEAKING
                //NSLog(@"VideoLeak : _videoFrames removeObject, count = %d", (int)_videoFrames.count);
#endif
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else if (_decoder.validAudio) {

        //interval = _bufferedDuration * 0.5;
                
        if (self.artworkFrame) {
#ifdef ENCODING_WITHOUT_MYGLVIEW
            if (self.isUsedAsEncoder)
                [self.encoderRenderLoop draw:[self.artworkFrame asImage]];
            else
#endif
                [_glView.glRenderLoop draw:[self.artworkFrame asImage]];
            //_imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }

    if (_decoder.validSubtitles)
        [self presentSubtitles];
    
#ifdef DEBUG
    if (self.playing && _debugStartTime < 0)
        _debugStartTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
#endif

    return interval;
}

#ifdef DEBUG_GYRO
static FILE* gyroFile = NULL;
static int frameCount = 0;
#endif

- (int) applyGyroDataOfVideoTime:(float)seconds {
    int frameNumber = seconds * self.FPS;
    if (self.gyroStringBytesSize > 0)
    {
        frameNumber += GyroDataFrameNumberOffset;
        if (frameNumber < 0)
            frameNumber = 0;
        if (frameNumber * self.bytesPerGyroStringLine + self.gyroDataBytesOffset >= self.gyroData.length) {
            frameNumber = (int) ((self.gyroData.length - self.gyroDataBytesOffset) / self.bytesPerGyroStringLine - 1);
            //if (frameNumber < 0) {
            //                        madvGLRenderer.setGyroMatrix(matrix, 3);
            //    return;
            //}
        }
    }
    if (self.gyroStringBytesSize > 0 && frameNumber >= 0)
    {
        //[self updateGyroData:frameNumber maxFrameNumber:(self.isUsedAsEncoder ? 60 : -1)];
        [self updateGyroData:frameNumber maxFrameNumber:-1];
    }
    return frameNumber;
}

- (CGFloat) presentVideoFrame: (KxVideoFrame *) frame
{
    //NSLog(@"presentVideoFrame frame.timestamp=%f, decoder.position=%f", frame.timestamp, self.decoder.position);
    int frameNumber = [self applyGyroDataOfVideoTime:(frame.timestamp / 1000.f)];
#ifdef ENCODING_WITHOUT_MYGLVIEW
    if (self.isUsedAsEncoder)
    {
        if (self.encoderRenderLoop) {
            //NSLog(@"presentVideoFrame");
            [self.encoderRenderLoop render:frame];///!!!For Debug #VideoLeak# by QD 20170124
#ifdef DEBUG_GYRO
            if (NULL == gyroFile)
            {
                NSString* gyroFilePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithUTF8String:GyroFileName]];
                gyroFile = fopen(gyroFilePath.UTF8String, "r+");
            }
            if (NULL != gyroFile)
            {
                float matrix[9];
                fscanf(gyroFile, "%f,%f,%f,%f,%f,%f,%f,%f,%f", &matrix[0], &matrix[1], &matrix[2], &matrix[3], &matrix[4], &matrix[5], &matrix[6], &matrix[7], &matrix[8]);
                NSLog(@"GyroMatrix : %f,%f,%f,%f,%f,%f,%f,%f,%f", matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6], matrix[7], matrix[8]);
                [self.encoderRenderLoop setGyroMatrix:matrix rank:3];
            }
#endif
        } else if ([frame isKindOfClass:KxVideoFrameRGB.class]) {
            KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
            //_imageView.image = [rgbFrame asImage];
            [self.encoderRenderLoop draw:[rgbFrame asImage]];
        } else if ([frame isKindOfClass:KxVideoFrameCVBuffer.class]) {
            if (self.gyroStringBytesSize > 0 && frameNumber >= 0)
            {
                [self updateGyroData:frameNumber maxFrameNumber:-1];
            }
            KxVideoFrameCVBuffer* cvbFrame = (KxVideoFrameCVBuffer*)frame;
            [self.encoderRenderLoop render:cvbFrame];
        }
    }
    else
#endif
    {
        if (_glView) {
            //NSLog(@"presentVideoFrame");
            [_glView.glRenderLoop render:frame];///!!!For Debug #VideoLeak# by QD 20170124
#ifdef DEBUG_GYRO
            if (NULL == gyroFile)
            {
                NSString* gyroFilePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithUTF8String:GyroFileName]];
                gyroFile = fopen(gyroFilePath.UTF8String, "r+");
            }
            if (NULL != gyroFile)
            {
                float matrix[9];
                fscanf(gyroFile, "%f,%f,%f,%f,%f,%f,%f,%f,%f", &matrix[0], &matrix[1], &matrix[2], &matrix[3], &matrix[4], &matrix[5], &matrix[6], &matrix[7], &matrix[8]);
                NSLog(@"GyroMatrix : %f,%f,%f,%f,%f,%f,%f,%f,%f", matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6], matrix[7], matrix[8]);
                [_glView setGyroMatrix:matrix rank:3];
            }
#endif
        } else if ([frame isKindOfClass:KxVideoFrameRGB.class]) {
            KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
            //_imageView.image = [rgbFrame asImage];
            [_glView.glRenderLoop draw:[rgbFrame asImage]];
        } else if ([frame isKindOfClass:KxVideoFrameCVBuffer.class]) {
            if (self.gyroStringBytesSize > 0 && frameNumber >= 0)
            {
                [self updateGyroData:frameNumber maxFrameNumber:-1];
            }
            KxVideoFrameCVBuffer* cvbFrame = (KxVideoFrameCVBuffer*)frame;
            [_glView.glRenderLoop render:cvbFrame];
        }
    }
    
    _moviePosition = frame.position;
    return frame.duration;
}

- (void) presentSubtitles
{
    
    NSLog(@"presentSubtitles");
    NSArray *actual, *outdated;
    
    if ([self subtitleForPosition:_moviePosition
                           actual:&actual
                         outdated:&outdated]){
        
        if (outdated.count) {
            @synchronized(_subtitles) {
                [_subtitles removeObjectsInArray:outdated];
            }
        }
        
        if (actual.count) {
            
            NSMutableString *ms = [NSMutableString string];
            for (KxSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
                if (ms.length) [ms appendString:@"\n"];
                [ms appendString:subtitle.text];
            }
            
            [self showSubtitleText:ms];
        } else {
            [self showSubtitleText:nil];
        }
    }
}

- (void) recordAudioFrame:  (UInt32) inNumberFrames
                         channels: (int) channels
                         buf:  (float*) buf
{
    AudioBufferList bufferList;
    UInt16 numSamples = inNumberFrames*channels;
    
    //NSLog(@"recordAudioFrame %d ", numSamples);
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = buf;
    bufferList.mBuffers[0].mNumberChannels = channels;
    bufferList.mBuffers[0].mDataByteSize = numSamples*sizeof(float);

    
    //OSStatus status = ExtAudioFileWriteAsync(_audioFileRef, inNumberFrames, &bufferList);
    OSStatus status = ExtAudioFileWrite(_audioFileRef, inNumberFrames, &bufferList);
    if(status != 0)
        NSLog(@"Audio write fail ret=%d",status);
    //NSLog(@"record audio frame samples:%d channel:%d", numSamples, channels);
    ///!!!#Bug2880# It crashes after back to foreground! checkStatus(status);
}

- (void) showSubtitleText:(NSString*)text {
    // Subclass Implements
}

- (BOOL) subtitleForPosition: (CGFloat) position
                      actual: (NSArray **) pActual
                    outdated: (NSArray **) pOutdated
{
    
    NSLog(@"subtitleForPosition %f", position);
    
    if (!_subtitles.count)
        return NO;
    
    NSMutableArray *actual = nil;
    NSMutableArray *outdated = nil;
    
    for (KxSubtitleFrame *subtitle in _subtitles) {
        
        if (position < subtitle.position) {
            
            break; // assume what subtitles sorted by position
            
        } else if (position >= (subtitle.position + subtitle.duration)) {
            
            if (pOutdated) {
                if (!outdated)
                    outdated = [NSMutableArray array];
                [outdated addObject:subtitle];
            }
            
        } else {
            
            if (pActual) {
                if (!actual)
                    actual = [NSMutableArray array];
                [actual addObject:subtitle];
            }
        }
    }
    
    if (pActual) *pActual = actual;
    if (pOutdated) *pOutdated = outdated;
    
    return actual.count || outdated.count;
}

- (void) updateHUD
{
    
    //NSLog(@"updateHUD");
    
    if (_disableUpdateHUD)
        return;
    [self updatePositionView];

#if 0
#ifdef DEBUG
    const NSTimeInterval timeSinceStart = [NSDate timeIntervalSinceReferenceDate] - _debugStartTime;
    NSString *subinfo = self.decoder.validSubtitles ? [NSString stringWithFormat: @" %d",_subtitles.count] : @"";
    
    NSString *audioStatus;
    
    if (_debugAudioStatus) {
        
        if (NSOrderedAscending == [_debugAudioStatusTS compare: [NSDate dateWithTimeIntervalSinceNow:-0.5]]) {
            _debugAudioStatus = 0;
        }
    }
    
    if      (_debugAudioStatus == 1) audioStatus = @"\n(audio outrun)";
    else if (_debugAudioStatus == 2) audioStatus = @"\n(audio lags)";
    else if (_debugAudioStatus == 3) audioStatus = @"\n(audio silence)";
    else audioStatus = @"";
    
    _messageLabel.text = [NSString stringWithFormat:@"%d %d%@ %c - %@ %@ %@\n%@",
                          _videoFrames.count,
                          _audioFrames.count,
                          subinfo,
                          self.decoding ? 'D' : ' ',
                          formatTimeInterval(timeSinceStart, NO),
                          //timeSinceStart > self.moviePosition + 0.5 ? @" (lags)" : @"",
                          self.decoder.isEOF ? @"- END" : @"",
                          audioStatus,
                          _buffered ? [NSString stringWithFormat:@"buffering %.1f%%", _bufferedDuration / _minBufferedDuration * 100] : @""];
#endif
#endif
}

- (void) updatePositionView {
}

- (void) fullscreenMode: (BOOL) on
{
    
    NSLog(@"fullscreenMode %d", on);
    _fullscreen = on;
    UIApplication *app = [UIApplication sharedApplication];
    [app setStatusBarHidden:on withAnimation:UIStatusBarAnimationNone];
    // if (!self.presentingViewController) {
    //[self.navigationController setNavigationBarHidden:on animated:YES];
    //[self.tabBarController setTabBarHidden:on animated:YES];
    // }
}

- (void) setMoviePositionFromDecoder
{
    
    NSLog(@"setMoviePositionFromDecoder %f", _decoder.position);
    _moviePosition = _decoder.position;
}

- (void) setDecoderPosition: (CGFloat) position
{
    
    NSLog(@"setDecoderPosition %f", position);
    _decoder.position = position;
}

- (void) enableUpdateHUD
{
    
    //NSLog(@"enableUpdateHUD");
    _disableUpdateHUD = NO;
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    
    NSLog(@"updatePosition position:%f playmode:%d", position, playMode);
    [self freeBufferedFrames];
    
    position = MIN(_decoder.duration - 1, MAX(0, position));
    
    __weak KxMovieViewController *weakSelf = self;

    dispatch_async(_dispatchQueue, ^{
        if (playMode) {
            {
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf play];
                }
            });
        } else {
            {
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
                [strongSelf decodeFrames];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf presentFrame];
                    [strongSelf enableUpdateHUD];
                    [strongSelf updateHUD];
                }
            });
        }        
    });
}

- (void) didPlayProgressChanged:(int)percent {
}

- (void) freeBufferedFrames
{
    @synchronized(_videoFrames) {
#ifdef DEBUG_VIDEOFRAME_LEAKING
        //NSLog(@"VideoLeak : freeBufferedFrames @ [%@]", [[NSThread callStackSymbols] description]);// stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]);
        //NSLog(@"VideoLeak : Before _videoFrames removeAllObjects, count = %d", (int)_videoFrames.count);
#endif
        [_videoFrames removeAllObjects];
#ifdef DEBUG_VIDEOFRAME_LEAKING
        //NSLog(@"VideoLeak : After _videoFrames removeAllObjects, count = %d", (int)_videoFrames.count);
#endif
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    if (_subtitles) {
        @synchronized(_subtitles) {
            [_subtitles removeAllObjects];
        }
    }
    
    _bufferedDuration = 0;
}

- (void) handleDecoderMovieError: (NSError *) error
{
    NSLog(@"handleDecoderMovieError : %@", error);
    /*
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil];
    
    [alertView show];
    //*/
}

- (BOOL) interruptDecoder
{
    //if (!_decoder)
    //    return NO;
    return _interrupted;
}

-(BOOL) getGyroMatrix:(float*)pMatrix frameNumber:(int)frameNumber {
    @try {
        int iSrcByte = frameNumber * self.bytesPerGyroStringLine + self.gyroDataBytesOffset;
        Byte* bytes = (Byte*) self.gyroData.bytes;
        for (int j=0; j<9; ++j) {
            int b0 = bytes[iSrcByte++];
            int b1 = bytes[iSrcByte++];
            int b2 = bytes[iSrcByte++];
            int b3 = bytes[iSrcByte++];
            int intValue = (b0 & 0xff) | ((b1 & 0xff) << 8) | ((b2 & 0xff) << 16) | ((b3 & 0xff) << 24);
            pMatrix[j] = *((float*) (int*) &intValue);
            //                    System.out.print(matrix[j] + " = 0x" + Integer.toHexString(intValue) + ", ");
        }
        return YES;
    }
    @catch (id ex) {
        return NO;
    }
    @finally {
    }
}

- (void) updateGyroData:(int)frameNumber maxFrameNumber:(int)maxFrameNumber {
    if (!self.isCameraGyroAdustEnabled)
        return;
#ifdef ENCODING_WITHOUT_MYGLVIEW
    if (self.gyroStringBytesSize > 0 && (nil != self.glView || nil != self.encoderRenderLoop)) {
#else
    if (self.gyroStringBytesSize > 0 && nil != self.glView) {
#endif
        frameNumber += GyroDataFrameNumberOffset;
        if (frameNumber < 0)
            frameNumber = 0;
        if (frameNumber * self.bytesPerGyroStringLine + self.gyroDataBytesOffset >= self.gyroData.length) {
            frameNumber = (int)((self.gyroData.length - self.gyroDataBytesOffset) / self.bytesPerGyroStringLine - 1);
            if (frameNumber < 0) {
                //                    madvGLRenderer.setGyroMatrix(matrix, 3);
                return;
            }
        }
        if (maxFrameNumber > 0 && frameNumber > maxFrameNumber) {
            return;
        }
        float matrix[9];
        BOOL succ = [self getGyroMatrix:matrix frameNumber:frameNumber];
        if (succ) {
            //NSLog(@"#Gyro# updateGyroData#%d : {%0.3f,%0.3f,%0.3f; %0.3f,%0.3f,%0.3f; %0.3f,%0.3f,%0.3f}", frameNumber, matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5], matrix[6], matrix[7], matrix[8]);
            if (self.glView) {
                [self.glView.glRenderLoop setGyroMatrix:matrix rank:3];
            }
#ifdef ENCODING_WITHOUT_MYGLVIEW
            if (self.encoderRenderLoop) {
                [self.encoderRenderLoop setGyroMatrix:matrix rank:3];
            }
#endif
        }
        else {
            if (self.glView) {
                [self.glView.glRenderLoop setGyroMatrix:matrix rank:0];
            }
#ifdef ENCODING_WITHOUT_MYGLVIEW
            if (self.encoderRenderLoop) {
                [self.encoderRenderLoop setGyroMatrix:matrix rank:0];
            }
#endif
        }
    }
}

#ifdef ENCODING_WITHOUT_MYGLVIEW
#pragma mark    GLRenderLoopDelegate
- (void) glRenderLoopSetupGLRenderbuffer:(GLRenderLoop*)renderLoop {
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA, 32, 32);
}
#endif
    
@end

