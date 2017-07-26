//
//  MadvGLRenderer_iOS.mm
//  Madv360_v1
//
//  Created by FutureBoy on 4/2/16.
//  Copyright © 2016 Cyllenge. All rights reserved.
//

#include "MadvGLRenderer_iOS.h"
#import "KxMovieDecoder.h"
#import "IDRDecoder.h"
#import "z_Sandbox.h"
#import "NSString+Extensions.h"
#import "MVCameraClient.h"
#import "MVCameraDevice.h"
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>
#import <fstream>

#ifdef MADVPANO_BY_SOURCE
#import "JPEGUtils.h"
#import "EXIFParser.h"
#import "GLRenderTexture.h"
#import "GLFilterCache.h"
#else
#import <MADVPano/JPEGUtils.h>
#import <MADVPano/EXIFParser.h>
#import <MADVPano/GLRenderTexture.h>
#import <MADVPano/GLFilterCache.h>
#endif

using namespace std;

void cgDataProviderReleaseDataCallback(void * __nullable info, const void *  data, size_t size) {
    free((void*) data);
}

MadvGLRenderer_iOS::~MadvGLRenderer_iOS() {
    if(_videoDestTexture) {
        CFRelease(_videoDestTexture);
        _videoDestTexture = NULL;
    }
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
        _videoTextureCache = NULL;
    }
}

MadvGLRenderer_iOS::MadvGLRenderer_iOS(const char* lutPath, Vec2f leftSrcSize, Vec2f rightSrcSize)
: MadvGLRenderer(lutPath, leftSrcSize, rightSrcSize)
, _videoDestTexture(NULL)
, _videoTextureCache(NULL)
{
    //prepareLUT(lutPath, leftSrcSize, rightSrcSize);
}

void findMaxAndMin(const GLushort* data, int length) {
    GLushort min = 10240, max = 0;
    for (int i=length; i>0; --i)
    {
        GLushort s = *data++;
        if (s > max) max = s;
        if (s < min) min = s;
    }
    NSLog(@"min = %d, max = %d", min, max);
}

//void MadvGLRenderer_iOS::prepareLUT(const char* lutPath, Vec2f leftSrcSize, Vec2f rightSrcSize) {
////    GLfloat minXL, minYL, maxXL, maxYL, minXR, minYR, maxXR, maxYR;
//    if (NULL == lutPath) return;
//    NSString* nsLUTPath = [NSString stringWithUTF8String:lutPath];
//    UIImage* imgLXI = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"l_x_int.png"]];
//    UIImage* imgLXM = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"l_x_min.png"]];
//    UIImage* imgLYI = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"l_y_int.png"]];
//    UIImage* imgLYM = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"l_y_min.png"]];
//    UIImage* imgRXI = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"r_x_int.png"]];
//    UIImage* imgRXM = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"r_x_min.png"]];
//    UIImage* imgRYI = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"r_y_int.png"]];
//    UIImage* imgRYM = [UIImage imageWithContentsOfFile:[nsLUTPath stringByAppendingPathComponent:@"r_y_min.png"]];
//
//    CFDataRef LXIDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgLXI.CGImage));
//    const GLushort* LXIData = (const GLushort*) CFDataGetBytePtr(LXIDataRef);
//    
//    CFDataRef LXMDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgLXM.CGImage));
//    const GLushort* LXMData = (const GLushort*) CFDataGetBytePtr(LXMDataRef);
//    
//    CFDataRef LYIDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgLYI.CGImage));
//    const GLushort* LYIData = (const GLushort*) CFDataGetBytePtr(LYIDataRef);
//    
//    CFDataRef LYMDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgLYM.CGImage));
//    const GLushort* LYMData = (const GLushort*) CFDataGetBytePtr(LYMDataRef);
//    
//    CFDataRef RXIDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgRXI.CGImage));
//    const GLushort* RXIData = (const GLushort*) CFDataGetBytePtr(RXIDataRef);
//    
//    CFDataRef RXMDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgRXM.CGImage));
//    const GLushort* RXMData = (const GLushort*) CFDataGetBytePtr(RXMDataRef);
//    
//    CFDataRef RYIDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgRYI.CGImage));
//    const GLushort* RYIData = (const GLushort*) CFDataGetBytePtr(RYIDataRef);
//    
//    CFDataRef RYMDataRef = CGDataProviderCopyData(CGImageGetDataProvider(imgRYM.CGImage));
//    const GLushort* RYMData = (const GLushort*) CFDataGetBytePtr(RYMDataRef);
//    
//    NSInteger byteSize = CFDataGetLength(LXIDataRef);
//    NSInteger sizeInShort = byteSize / sizeof(GLushort);
//    
////    ///!!!For Debug:
////    findMaxAndMin(LXIData, (int)sizeInShort);
////    findMaxAndMin(LXMData, (int)sizeInShort);
////    findMaxAndMin(LYIData, (int)sizeInShort);
////    findMaxAndMin(LYMData, (int)sizeInShort);
////    findMaxAndMin(RXIData, (int)sizeInShort);
////    findMaxAndMin(RXMData, (int)sizeInShort);
////    findMaxAndMin(RYIData, (int)sizeInShort);
////    findMaxAndMin(RYMData, (int)sizeInShort);
//    
//    setLUTData(CGSize2Vec2f(imgLXI.size), leftSrcSize, rightSrcSize, (int)sizeInShort, LXIData, LXMData, LYIData, LYMData, RXIData, RXMData, RYIData, RYMData);
//    
//    CFRelease(LXIDataRef);
//    CFRelease(LXMDataRef);
//    CFRelease(LYIDataRef);
//    CFRelease(LYMDataRef);
//    CFRelease(RXIDataRef);
//    CFRelease(RXMDataRef);
//    CFRelease(RYIDataRef);
//    CFRelease(RYMDataRef);
//}

typedef struct {
    size_t width;
    size_t height;
    CGImageRef cgImage;
} CreateOrUpdateTextureWithBitmapBlockContext;

void createOrUpdateTextureWithBitmap(GLubyte *data, GLint pow2Width, GLint pow2Height, void* userData) {
    CreateOrUpdateTextureWithBitmapBlockContext* context = (CreateOrUpdateTextureWithBitmapBlockContext*) userData;
    size_t width = context->width;
    size_t height = context->height;
    CGImageRef cgImage = context->cgImage;
    delete context;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef cgContext = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetFillColorWithColor(cgContext, [UIColor clearColor].CGColor);
//    CGContextSetBlendMode(cgContext, kCGBlendModeColor);
    CGContextSetAlpha(cgContext, 1.0f);
    
    CGContextDrawImage(cgContext, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(cgContext);
    CGImageRelease(cgImage);
}

GLuint createTextureFromImage(UIImage* image, CGSize destSize) {
    CGImageRef cgImage = [image CGImage];
    CGImageRetain(cgImage);
    size_t width = (destSize.width == 0 ? CGImageGetWidth(cgImage) : destSize.width);
    size_t height = (destSize.height == 0 ? CGImageGetHeight(cgImage) : destSize.height);
    
    CreateOrUpdateTextureWithBitmapBlockContext* context = new CreateOrUpdateTextureWithBitmapBlockContext;
    context->width = width;
    context->height = height;
    context->cgImage = cgImage;
    
    GLubyte* textureData = NULL;// = (GLubyte *)malloc(width * height * 4); // if 4 components per pixel (RGBA)
    GLuint texture = 0;
    createOrUpdateTexture(&texture, (GLint)width, (GLint)height, &textureData, NULL, createOrUpdateTextureWithBitmap, context);
    free(textureData);
    
    return texture;
}

void MadvGLRenderer_iOS::prepareTextureWithRenderSource(void* renderSource) {
    id currentRenderSource = (__bridge_transfer id)renderSource;
    //NSLog(@"MadvGLRenderer_iOS::prepareTextureWithRenderSource : %lx", (long)renderSource);
    if ([currentRenderSource isKindOfClass:NSArray.class])
    {
        NSArray* images = currentRenderSource;
        UIImage* leftImg = images[0];
        UIImage* rightImg = images[1];
        GLuint srcTextureL = createTextureFromImage(leftImg, CGSizeZero);
        GLuint srcTextureR = createTextureFromImage(rightImg, CGSizeZero);
        setSourceTextures(true, srcTextureL, srcTextureR, GL_TEXTURE_2D, false);
        _renderSourceSize = Vec2f{(float)leftImg.size.width, (float)leftImg.size.height};
    }
    else if ([currentRenderSource isKindOfClass:UIImage.class])
    {
        UIImage* image = currentRenderSource;
        GLuint texture = createTextureFromImage(image, CGSizeZero);
        setSourceTextures(false, texture, texture, GL_TEXTURE_2D, false);
        _renderSourceSize = Vec2f{(float)image.size.width, (float)image.size.height};
    }
    else if ([currentRenderSource isKindOfClass:NSString.class])
    {
        const char* cstrPath = [currentRenderSource UTF8String];
        GLint texture = createTextureWithJPEG(cstrPath, &_renderSourceSize);
        if (0 >= texture)
        {
            GLint maxTextureSize = 0;
            glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
            NSLog(@"prepareTextureWithRenderSource : GL_MAX_TEXTURE_SIZE = %d", maxTextureSize);
            UIImage* image = [UIImage imageWithContentsOfFile:currentRenderSource];
            _renderSourceSize = Vec2f{(float)image.size.width, (float)image.size.height};
            texture = createTextureFromImage(image, CGSizeMake(MIN(image.size.width, maxTextureSize), MIN(image.size.height, maxTextureSize)));
        }
        setSourceTextures(false, texture, texture, GL_TEXTURE_2D, false);
    }
    else if ([currentRenderSource isKindOfClass:KxVideoFrame.class])
    {
        KxVideoFrame* frame = currentRenderSource;
        if ([frame isKindOfClass:KxVideoFrameCVBuffer.class])
        {
            KxVideoFrameCVBuffer *cvbFrame = (KxVideoFrameCVBuffer *)frame;
            
            CVBufferRef cvBufferRef = cvbFrame.cvBufferRef;
            
            if (!_videoTextureCache) {
                CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [EAGLContext currentContext], NULL, (CVOpenGLESTextureCacheRef *)&_videoTextureCache);
                if (err != noErr) {
                    //                    goto failed;
                    [cvbFrame releasePixelBuffer];
                    return;
                }
                //CFRetain(_videoTextureCache);//2016.3.3 spy
            }
            
            // Periodic texture cache flush every frame
            CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
            /* cleanUp Textures*/
            if (_videoDestTexture) {
                CFRelease(_videoDestTexture);
                _videoDestTexture = NULL;
            }
            
            glActiveTexture(GL_TEXTURE0);
            CVReturn err;
            
            int frameWidth = (int)CVPixelBufferGetWidth(cvBufferRef);
            int frameHeight = (int)CVPixelBufferGetHeight(cvBufferRef);
            _renderSourceSize = Vec2f{(float)frameWidth, (float)frameHeight};
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                               _videoTextureCache,
                                                               cvBufferRef,
                                                               NULL,
                                                               GL_TEXTURE_2D,
                                                               GL_RGBA,
                                                               frameWidth,
                                                               frameHeight,
                                                               GL_BGRA,
                                                               GL_UNSIGNED_BYTE,
                                                               0,
                                                               (CVOpenGLESTextureRef*)&_videoDestTexture);
            if (err) {
                //                goto failed;
                [cvbFrame releasePixelBuffer];
                return;
            }
            
            GLuint texture = CVOpenGLESTextureGetName((CVOpenGLESTextureRef)_videoDestTexture);
            
            glBindTexture(CVOpenGLESTextureGetTarget((CVOpenGLESTextureRef)_videoDestTexture), texture);
            
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);//GL_LINEAR_MIPMAP_LINEAR
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);//GL_CLAMP_TO_EDGE);//GL_REPEAT
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);//GL_CLAMP_TO_EDGE);//GL_REPEAT
            
//            glHint(GL_GENERATE_MIPMAP_HINT, GL_NICEST);
//            glGenerateMipmap(GL_TEXTURE_2D);
            
            //        failed:
            [cvbFrame releasePixelBuffer];
            setSourceTextures(false, texture, texture, GL_TEXTURE_2D, false);
        }
//        else if ([frame isKindOfClass:KxVideoFrameYUV.class])
//        {
//            _isYUVColorSpace = true;
//            
//            KxVideoFrameYUV *yuvFrame = (KxVideoFrameYUV *)frame;
//            assert(yuvFrame.luma.length == yuvFrame.width * yuvFrame.height);
//            assert(yuvFrame.chromaB.length == (yuvFrame.width * yuvFrame.height) / 4);
//            assert(yuvFrame.chromaR.length == (yuvFrame.width * yuvFrame.height) / 4);
//            
//            const NSUInteger frameWidth = frame.width;
//            const NSUInteger frameHeight = frame.height;
//            
//            const UInt8 *pixels[3] = {(const UInt8*) yuvFrame.luma.bytes, (const UInt8*)yuvFrame.chromaB.bytes, (const UInt8*)yuvFrame.chromaR.bytes };
//            
//            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
//            
//            if (0 == _yuvTextures[0])
//                glGenTextures(3, _yuvTextures);
//            
//            //            const UInt8 *pixels[3] = {(const UInt8*) yuvFrame.luma, (const UInt8*)yuvFrame.chromaB, (const UInt8*)yuvFrame.chromaR };
//            const NSUInteger widths[3]  = { frameWidth, frameWidth / 2, frameWidth / 2 };
//            const NSUInteger heights[3] = { frameHeight, frameHeight / 2, frameHeight / 2 };
//            
//            for (int i = 0; i < 3; ++i) {
//                
//                glBindTexture(GL_TEXTURE_2D, _yuvTextures[i]);
//                
//                glTexImage2D(GL_TEXTURE_2D,
//                             0,
//                             GL_LUMINANCE,
//                             (GLsizei)widths[i],
//                             (GLsizei)heights[i],
//                             0,
//                             GL_LUMINANCE,
//                             GL_UNSIGNED_BYTE,
//                             pixels[i]);
//                
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);//GL_CLAMP_TO_EDGE);//
//                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);//GL_CLAMP_TO_EDGE);//
//            }
//            
//            yuvFrame.luma = nil;
//            yuvFrame.chromaB = nil;
//            yuvFrame.chromaR = nil;
//        }
        frame = nil;
    }
    currentRenderSource = nil;
}

void MadvGLRenderer_iOS::extractLUTFiles(const char* destDirectory, const char* lutBinFilePath, uint32_t fileOffset) {
    ifstream ifs(lutBinFilePath, ios::in | ios::binary);
    DoctorLog(@"extractLUTFiles : fileOffset=%u, destDirectory='%s', lutBinFilePath='%s'", fileOffset, destDirectory, lutBinFilePath);
    //    fseek(fp, fileOffset, SEEK_CUR);
    const uint32_t Limit2G = 0x80000000;
    if (fileOffset >= Limit2G)
    {
        uint32_t fileOffsetLeft = fileOffset;
        //        ALOGE("extractLUTFiles : #0 fileOffsetLeft = %u", fileOffsetLeft);
        ifs.seekg(0x40000000, ios::beg);
        ifs.seekg(0x40000000, ios::cur);
        for (fileOffsetLeft -= Limit2G; fileOffsetLeft >= Limit2G; fileOffsetLeft -= Limit2G)
        {
            //            ALOGE("extractLUTFiles : #1 fileOffsetLeft = %u", fileOffsetLeft);
            ifs.seekg(0x40000000, ios::cur);
            ifs.seekg(0x40000000, ios::cur);
        }
        //        ALOGE("extractLUTFiles : #2 fileOffsetLeft = %u", fileOffsetLeft);
        ifs.seekg(fileOffsetLeft, ios::cur);
    }
    else
    {
        ifs.seekg(fileOffset, ios::beg);
    }
    
    uint32_t offsets[8];
    uint32_t sizes[8];
    uint32_t totalSize = 0;
    uint32_t maxSize = 0;
    for (int i=0; i<8; ++i)
    {
        ifs.read((char*)&offsets[i], sizeof(uint32_t));
        ifs.read((char*)&sizes[i], sizeof(uint32_t));
        DoctorLog(@"offsets[%d] = %u, sizes[%d] = %u", i,offsets[i], i,sizes[i]);
        if (sizes[i] > maxSize) maxSize = sizes[i];
        totalSize += sizes[i];
    }
    ifs.close();
    //    ALOGV("totalSize = %u", totalSize);
    
    const char* pngFileNames[] = {"/r_x_int.png", "/r_x_min.png",
        "/r_y_int.png", "/r_y_min.png",
        "/l_x_int.png", "/l_x_min.png",
        "/l_y_int.png", "/l_y_min.png"};
    char* pngFilePath = (char*) malloc(strlen(destDirectory) + strlen(pngFileNames[0]) + 1);
    
    uint8_t* pngData = (uint8_t*) malloc(maxSize);
    fstream ofs(lutBinFilePath, ios::out | ios::in | ios::binary);
    if (fileOffset >= Limit2G)
    {
        ofs.seekp(0x40000000, ios::beg);
        ofs.seekp(0x40000000, ios::cur);
        for (fileOffset -= Limit2G; fileOffset >= Limit2G; fileOffset -= Limit2G)
        {
            ofs.seekp(0x40000000, ios::cur);
            ofs.seekp(0x40000000, ios::cur);
        }
        ofs.seekp(fileOffset, ios::cur);
    }
    else
    {
        ofs.seekp(fileOffset, ios::beg);
    }
    
    uint64_t currentOffset = 0;
    for (int i=0; i<8; ++i)
    {
        ofs.seekp(offsets[i] - currentOffset, ios::cur);
        ofs.read((char*)pngData, sizes[i]);
        sprintf(pngFilePath, "%s%s", destDirectory, pngFileNames[i]);
        FILE* fout = fopen(pngFilePath, "wb+");
        fwrite(pngData, sizes[i], 1, fout);
        fclose(fout);
        currentOffset = offsets[i] + sizes[i];
    }
    ofs.close();
    free(pngData);
    free(pngFilePath);
}

NSString* MadvGLRenderer_iOS::cameraLUTFilePath(NSString* cameraUUID) {
    NSString* lutFilePath = [[MVCameraClient formattedCameraUUID:cameraUUID] stringByAppendingString:@"_lut.bin"];
    lutFilePath = [z_Sandbox documentPath:lutFilePath];
    return lutFilePath;
}

NSString* loadDefaultLUT() {
    return [[[NSBundle mainBundle] pathForResource:@"l_x_int" ofType:@"png"] stringByDeletingLastPathComponent];
}

NSString* cameraOrDefaultLUT() {
    NSString* lutPath = nil;
    MVCameraDevice* connectingCamera = [MVCameraClient sharedInstance].connectingCamera;
    if (connectingCamera != nil)
    {
        NSFileManager* fm = [NSFileManager defaultManager];
        lutPath = [MadvGLRenderer_iOS::cameraLUTFilePath(connectingCamera.uuid) stringByDeletingPathExtension];
        BOOL isDirectory;
        if (![fm fileExistsAtPath:[lutPath stringByAppendingPathComponent:@"l_x_int.png"] isDirectory:&isDirectory] || isDirectory)
        {
            lutPath = loadDefaultLUT();
        }
        else
        {
            NSLog(@"lutPathOfSourceURI : LUT of this camera : %@", lutPath);
        }
    }
    else
    {
        lutPath = loadDefaultLUT();
    }
    return lutPath;
}

#define PRESTITCH_PICTURE_EXTENSION @"prestitch.jpg"

NSString* MadvGLRenderer_iOS::preStitchPictureFileName(NSString* cameraUUID, NSString* fileName) {
    NSString* uuid = cameraUUID ? [MVCameraClient formattedCameraUUID:cameraUUID] : @"LOCAL";
    NSString* ret = [fileName stringByAppendingPathExtension:uuid];
    ret = [ret stringByAppendingPathExtension:PRESTITCH_PICTURE_EXTENSION];
    return ret;
}

NSString* MadvGLRenderer_iOS::stitchedPictureFileName(NSString* fileName) {
    if ([fileName hasSuffix:PRESTITCH_PICTURE_EXTENSION])
    {
        return [[fileName substringToIndex:(fileName.length - PRESTITCH_PICTURE_EXTENSION.length - 1)] stringByDeletingPathExtension];
    }
    else
    {
        return nil;
    }
}

NSString* MadvGLRenderer_iOS::cameraUUIDOfPreStitchFileName(NSString* preStitchFileName) {
    if ([preStitchFileName hasSuffix:PRESTITCH_PICTURE_EXTENSION])
    {
        return [[preStitchFileName substringToIndex:(preStitchFileName.length - PRESTITCH_PICTURE_EXTENSION.length - 1)] pathExtension];
    }
    else
    {
        return nil;
    }
}

NSString* makeTempLUTDirectory() {
    NSString*lutPath = [z_Sandbox documentPath:@"tmplut"];
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:lutPath error:nil];
    [fm createDirectoryAtPath:lutPath withIntermediateDirectories:YES attributes:nil error:nil];
    return lutPath;
}

//#define USE_PRESTORED_LUT

#ifdef USE_PRESTORED_LUT
NSString* prestoredLUTPath() {
    return [z_Sandbox documentPath:@"PrestoredLUT"];
}
#endif

NSString* MadvGLRenderer_iOS::lutPathOfSourceURI(NSString* sourceURI, bool withLUT, bool lutEmbeddedInJPEG) {
    DoctorLog(@"lutPathOfSourceURI : %@, withLUT = %d", sourceURI, withLUT);
    if (!sourceURI || 0 == sourceURI.length)
    {
        if (withLUT)
#ifdef USE_PRESTORED_LUT
            return prestoredLUTPath();
#else
            return cameraOrDefaultLUT();
#endif
        else
            return nil;
    }
    
    NSString* lutPath = nil;
    NSString* lowerExt = [[sourceURI pathExtension] lowercaseString];
    if ([sourceURI hasSuffix:PRESTITCH_PICTURE_EXTENSION])
    {
        if (withLUT)
        {
            NSString* cameraUUID = cameraUUIDOfPreStitchFileName(sourceURI);
            lutPath = [cameraLUTFilePath(cameraUUID) stringByDeletingPathExtension];
            
            BOOL isDirectory;
            if (![[NSFileManager defaultManager] fileExistsAtPath:[lutPath stringByAppendingPathComponent:@"l_x_int.png"] isDirectory:&isDirectory] || isDirectory)
            {
                lutPath = nil;
            }
        }
    }
    
    if ([@"jpg" isEqualToString:lowerExt] || [@"png" isEqualToString:lowerExt] || [@"gif" isEqualToString:lowerExt] || [@"bmp" isEqualToString:lowerExt])
    {
        if (withLUT && !lutPath)
        {
            if (lutEmbeddedInJPEG)
            {
                long offset = readLUTOffsetInJPEG(sourceURI.UTF8String);
                if (offset > 0)
                {
                    lutPath = makeTempLUTDirectory();
                    extractLUTFiles(lutPath.UTF8String, sourceURI.UTF8String, (uint32_t)offset);
                }
            }
            
            if (!lutPath)
            {
                lutPath = cameraOrDefaultLUT();
            }
        }
    }
    else if ([sourceURI hasPrefix:AMBA_CAMERA_RTSP_URL_ROOT])
    {
        lutPath = cameraOrDefaultLUT();
        DoctorLog(@"lutPathOfSourceURI : #3 lutPath='%@'", lutPath);
    }
    else if ([sourceURI rangeOfString:[z_Sandbox docPath]].location != NSNotFound)
    {
        static NSCondition* cond = [[NSCondition alloc] init];
        [cond lock];
        @try
        {
            KxMovieDecoder* decoder = [[KxMovieDecoder alloc] init];
            [decoder openFile:sourceURI error:nil];
            int64_t LutzOffset = [decoder getLutzOffset];
            int64_t LutzSize = [decoder getLutzSize];
            [decoder closeFile];
            NSLog(@"setupPresentViw : lutz offset = %lld size = %lld", LutzOffset, LutzSize);
            if (LutzOffset >= 0 && LutzSize > 0)
            {
                lutPath = makeTempLUTDirectory();
                extractLUTFiles(lutPath.UTF8String, sourceURI.UTF8String, (uint32_t)LutzOffset);
            }
            else if (withLUT)
            {
                lutPath = cameraOrDefaultLUT();
            }
            else
            {
                lutPath = nil;
            }
        }
        @catch (NSException *exception)
        {
            
        }
        @finally
        {
            
        }
        [cond unlock];
        DoctorLog(@"lutPathOfSourceURI : #4 lutPath='%@'", lutPath);
    }
    else if (withLUT)
    {
        lutPath = cameraOrDefaultLUT();
        DoctorLog(@"lutPathOfSourceURI : #5 lutPath='%@'", lutPath);
    }
    else
    {
        lutPath = nil;
        DoctorLog(@"lutPathOfSourceURI : Video from other stream, no LUT stitching");
    }
#ifdef USE_PRESTORED_LUT
    return prestoredLUTPath();
#else
    return lutPath;
#endif
}

//[MadvGLRenderer renderThumbnail:@"thumb.h264" destSize:CGSizeMake(1920, 1080)];
UIImage* MadvGLRenderer_iOS::renderImage(UIImage* sourceImage, CGSize destSize, bool withLUT, NSString* sourceURI, int filterID, float* gyroMatrix, int gyroMatrixRank) {
    NSString* lutPath = lutPathOfSourceURI(sourceURI, withLUT, NO);
    withLUT = withLUT && (nil != lutPath);
    GLubyte* pixelData = NULL;
    EAGLContext* eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:eaglContext];
    {
        GLuint sourceTexture = createTextureFromImage(sourceImage, CGSizeZero);
        
        GLRenderTexture renderTexture(destSize.width, destSize.height);
        pixelData = (GLubyte*) malloc(renderTexture.bytesLength());
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        CHECK_GL_ERROR();
        NSLog(@"status = %d", status);
        
        glEnable(GL_BLEND);
        glPolygonOffset(0.1f, 0.2f);///???
        //    glCullFace(GL_CCW);
        glBlendFunc(GL_ONE, GL_ZERO);
        glViewport(0, 0, destSize.width, destSize.height);
        CHECK_GL_ERROR();
#ifdef USE_MSAA
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
#else
        glBindFramebuffer(GL_FRAMEBUFFER, renderTexture.getFramebuffer());
#endif
        
        glClearColor(0, 0, 0, 0);
        CHECK_GL_ERROR();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        CHECK_GL_ERROR();
        
        GLRenderTextureRef filterRenderTexture = NULL;
        GLFilterCacheRef filterCache = NULL;
        if (filterID > 0)
        {
            filterCache = new GLFilterCache([[[NSBundle mainBundle] pathForResource:@"lookup" ofType:@"png"] stringByDeletingLastPathComponent].UTF8String);
            filterRenderTexture = new GLRenderTexture(destSize.width, destSize.height);
            filterRenderTexture->blit();
        }
        
        MadvGLRendererRef renderer = new MadvGLRenderer_iOS(lutPath.UTF8String, Vec2f{3456.f, 1728.f}, Vec2f{3456.f, 1728.f});
        renderer->setIsYUVColorSpace(false);
        renderer->setDisplayMode((lutPath ? PanoramaDisplayModeLUT : 0) | PanoramaDisplayModeReFlatten);
        renderer->setSourceTextures(false, sourceTexture, sourceTexture, GL_TEXTURE_2D, false);
        ///!!!Important {
        kmScalar textureMatrixData[] = {
            1.f, 0.f, 0.f, 0.f,
            0.f, -1.f, 0.f, 0.f,
            0.f, 0.f, 1.f, 0.f,
            0.f, 1.f, 0.f, 1.f,
        };
        kmMat4 textureMatrix;
        kmMat4Fill(&textureMatrix, textureMatrixData);
        renderer->setTextureMatrix(&textureMatrix);
        renderer->setFlipY(true);
        ///!!!} Important
        if (gyroMatrixRank > 0)
        {
            renderer->setGyroMatrix(gyroMatrix, gyroMatrixRank);
        }
        renderer->draw(0,0, destSize.width,destSize.height);
        
        if (filterID > 0)
        {
            filterRenderTexture->unblit();
            filterCache->render(filterID, 0, 0, destSize.width, destSize.height, filterRenderTexture->getTexture(), GL_TEXTURE_2D);
        }
        
        CHECK_GL_ERROR();
        renderTexture.copyPixelData(pixelData, 0, renderTexture.bytesLength());
        CHECK_GL_ERROR();
        
        if (filterID > 0)
        {
            filterRenderTexture->releaseGLObjects();
            filterCache->releaseGLObjects();
        }
        
        glDeleteTextures(1, &sourceTexture);
    }
    //*/!!!For Debug 0320:
    CGDataProviderRef cgProvider = CGDataProviderCreateWithData(NULL, pixelData, destSize.width * destSize.height * 4, cgDataProviderReleaseDataCallback);
    CGColorSpaceRef cgColorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef cgImage = CGImageCreate(destSize.width, destSize.height, 8, 32, 4 * destSize.width, cgColorSpace, bitmapInfo, cgProvider, NULL, false, renderingIntent);
    UIImage* renderedImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(cgProvider);
    CGColorSpaceRelease(cgColorSpace);
    [EAGLContext setCurrentContext:nil];
    /*/
    NSData* data = [NSData dataWithBytes:pixelData length:(destSize.width * destSize.height)];
    UIImage* renderedImage = [UIImage imageWithData:data];
    free(pixelData);
    //*/
    return renderedImage;
}

UIImage* MadvGLRenderer_iOS::renderJPEG(const char* sourcePath, CGSize destSize, bool withLUT, NSString* sourceURI, bool lutEmbeddedInJPEG, int filterID, float* gyroMatrix, int gyroMatrixRank) {
    NSString* lutPath = lutPathOfSourceURI(sourceURI, withLUT, lutEmbeddedInJPEG);
    withLUT = withLUT && (nil != lutPath);
    //*
    GLubyte* pixelData = NULL;
    EAGLContext* eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:eaglContext];
    {
        GLint sourceTexture = createTextureWithJPEG(sourcePath);
        if (0 >= sourceTexture)
        {
            GLint maxTextureSize = 0;
            glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
            NSLog(@"prepareTextureWithRenderSource : GL_MAX_TEXTURE_SIZE = %d", maxTextureSize);
            UIImage* image = [UIImage imageWithContentsOfFile:[NSString stringWithUTF8String:sourcePath]];
            sourceTexture = createTextureFromImage(image, CGSizeMake(MIN(image.size.width, maxTextureSize), MIN(image.size.height, maxTextureSize)));
        }
        
        GLRenderTexture renderTexture(destSize.width, destSize.height);
        pixelData = (GLubyte*) malloc(renderTexture.bytesLength());
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        CHECK_GL_ERROR();
        NSLog(@"status = %d", status);
        
        glEnable(GL_BLEND);
        glPolygonOffset(0.1f, 0.2f);///???
        //    glCullFace(GL_CCW);
        glBlendFunc(GL_ONE, GL_ZERO);
        glViewport(0, 0, destSize.width, destSize.height);
        CHECK_GL_ERROR();
#ifdef USE_MSAA
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
#else
        glBindFramebuffer(GL_FRAMEBUFFER, renderTexture.getFramebuffer());
#endif
        
        glClearColor(0, 0, 0, 0);
        CHECK_GL_ERROR();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        CHECK_GL_ERROR();
        
        GLRenderTextureRef filterRenderTexture = NULL;
        GLFilterCacheRef filterCache = NULL;
        if (filterID > 0)
        {
            filterCache = new GLFilterCache([[[NSBundle mainBundle] pathForResource:@"lookup" ofType:@"png"] stringByDeletingLastPathComponent].UTF8String);
            filterRenderTexture = new GLRenderTexture(destSize.width, destSize.height);
            filterRenderTexture->blit();
        }
        
        MadvGLRendererRef renderer = new MadvGLRenderer_iOS(lutPath.UTF8String, Vec2f{3456.f, 1728.f}, Vec2f{3456.f, 1728.f});
        renderer->setIsYUVColorSpace(false);
        renderer->setDisplayMode((lutPath ? PanoramaDisplayModeLUT : 0) | PanoramaDisplayModeReFlatten);
        renderer->setSourceTextures(false, sourceTexture, sourceTexture, GL_TEXTURE_2D, false);
        ///!!!Important {
        kmScalar textureMatrixData[] = {
            1.f, 0.f, 0.f, 0.f,
            0.f, -1.f, 0.f, 0.f,
            0.f, 0.f, 1.f, 0.f,
            0.f, 1.f, 0.f, 1.f,
        };
        kmMat4 textureMatrix;
        kmMat4Fill(&textureMatrix, textureMatrixData);
        renderer->setTextureMatrix(&textureMatrix);
        renderer->setFlipY(true);
        ///!!!} Important
        if (gyroMatrixRank > 0)
        {
            renderer->setGyroMatrix(gyroMatrix, gyroMatrixRank);
        }
        renderer->draw(0,0, destSize.width,destSize.height);
        
        if (filterID > 0)
        {
            filterRenderTexture->unblit();
            filterCache->render(filterID, 0, 0, destSize.width, destSize.height, filterRenderTexture->getTexture(), GL_TEXTURE_2D);
        }
        
        CHECK_GL_ERROR();
        renderTexture.copyPixelData(pixelData, 0, renderTexture.bytesLength());
        CHECK_GL_ERROR();
        
        if (filterID > 0)
        {
            filterRenderTexture->releaseGLObjects();
            filterCache->releaseGLObjects();
        }
        
        glDeleteTextures(1, (GLuint*)&sourceTexture);
    }
    //*/!!!For Debug 0320:
    CGDataProviderRef cgProvider = CGDataProviderCreateWithData(NULL, pixelData, destSize.width * destSize.height * 4, cgDataProviderReleaseDataCallback);
    CGColorSpaceRef cgColorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef cgImage = CGImageCreate(destSize.width, destSize.height, 8, 32, 4 * destSize.width, cgColorSpace, bitmapInfo, cgProvider, NULL, false, renderingIntent);
    UIImage* renderedImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(cgProvider);
    CGColorSpaceRelease(cgColorSpace);
    [EAGLContext setCurrentContext:nil];
    
    return renderedImage;
    /*/
    free(pixelData);
    return nil;
    //*/
}

void MadvGLRenderer_iOS::renderJPEGToJPEG(NSString* destJpegPath, NSString* sourcePath, int dstWidth, int dstHeight, bool withLUT, bool lutEmbeddedInJPEG, int filterID, float* gyroMatrix, int gyroMatrixRank) {
    NSString* lutPath = lutPathOfSourceURI(sourcePath, withLUT, lutEmbeddedInJPEG);
    withLUT = withLUT && (nil != lutPath);
    
    long sourceExivImageHandler = createExivImage(sourcePath.UTF8String);
    //*
    EAGLContext* eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:eaglContext];
    {
        GLint sourceTexture = createTextureWithJPEG(sourcePath.UTF8String);
        if (0 >= sourceTexture)
        {
            GLint maxTextureSize = 0;
            glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
            NSLog(@"prepareTextureWithRenderSource : GL_MAX_TEXTURE_SIZE = %d", maxTextureSize);
            UIImage* image = [UIImage imageWithContentsOfFile:sourcePath];
            sourceTexture = createTextureFromImage(image, CGSizeMake(MIN(image.size.width, maxTextureSize), MIN(image.size.height, maxTextureSize)));
        }
        int blockLines = dstHeight / 8;
        GLRenderTexture renderTexture(dstWidth, blockLines);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        CHECK_GL_ERROR();
        NSLog(@"status = %d", status);
        
        glEnable(GL_BLEND);
        glPolygonOffset(0.1f, 0.2f);///???
        //    glCullFace(GL_CCW);
        glBlendFunc(GL_ONE, GL_ZERO);
        glClearColor(0, 0, 0, 0);
        glViewport(0, 0, dstWidth, dstHeight);
        CHECK_GL_ERROR();
#ifdef USE_MSAA
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
#else
        glBindFramebuffer(GL_FRAMEBUFFER, renderTexture.getFramebuffer());
#endif
        CHECK_GL_ERROR();
        
        GLRenderTextureRef filterRenderTexture = NULL;
        GLFilterCacheRef filterCache = NULL;
        if (filterID > 0)
        {
            filterCache = new GLFilterCache([[[NSBundle mainBundle] pathForResource:@"lookup" ofType:@"png"] stringByDeletingLastPathComponent].UTF8String);
            filterRenderTexture = new GLRenderTexture(dstWidth, blockLines);
            CHECK_GL_ERROR();
        }
        
        MadvGLRendererRef renderer = new MadvGLRenderer_iOS(lutPath.UTF8String, Vec2f{3456.f, 1728.f}, Vec2f{3456.f, 1728.f});
        renderer->setIsYUVColorSpace(false);
        renderer->setDisplayMode((lutPath ? PanoramaDisplayModeLUT : 0) | PanoramaDisplayModeReFlatten);
        renderer->setSourceTextures(false, sourceTexture, sourceTexture, GL_TEXTURE_2D, false);
        ///!!!Important {
        kmScalar textureMatrixData[] = {
            1.f, 0.f, 0.f, 0.f,
            0.f, -1.f, 0.f, 0.f,
            0.f, 0.f, 1.f, 0.f,
            0.f, 1.f, 0.f, 1.f,
        };
        kmMat4 textureMatrix;
        kmMat4Fill(&textureMatrix, textureMatrixData);
        renderer->setTextureMatrix(&textureMatrix);
        renderer->setFlipY(true);
        ///!!!} Important
        //*/!!!For Debug:
        if (gyroMatrixRank > 0)
        {
            renderer->setGyroMatrix(gyroMatrix, gyroMatrixRank);
        }
        //*/
        JPEGCompressOutput* imageOutput = startWritingImageToJPEG(destJpegPath.UTF8String, GL_RGBA, GL_UNSIGNED_BYTE, 100, dstWidth, dstHeight);
        GLubyte* pixelData = (GLubyte*) malloc(4 * dstWidth * blockLines);
        
        bool finishedAppending = false;
        int blockLines0 = blockLines;
        for (int iLine = 0; iLine < dstHeight; iLine += blockLines)
        {
            if (dstHeight - iLine < blockLines)
            {
                blockLines = dstHeight - iLine;
            }
            
            if (filterID > 0)
            {
                filterRenderTexture->blit();
            }
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            CHECK_GL_ERROR();
            renderer->draw(0,-iLine, dstWidth,dstHeight);
            if (filterID > 0)
            {
                filterRenderTexture->unblit();
                filterCache->render(filterID, 0, 0, dstWidth, blockLines0, filterRenderTexture->getTexture(), GL_TEXTURE_2D);
                CHECK_GL_ERROR();
            }
            
            glReadPixels(0, 0, dstWidth, blockLines, GL_RGBA, GL_UNSIGNED_BYTE, pixelData);
            glFinish();
            CHECK_GL_ERROR();
            if (!appendImageStrideToJPEG(imageOutput, pixelData, blockLines))
            {
                finishedAppending = true;
                break;
            }
        }

        if (!finishedAppending)
        {
            delete imageOutput;
        }
        
        copyEXIFDataFromExivImage(destJpegPath.UTF8String, sourceExivImageHandler);
        releaseExivImage(sourceExivImageHandler);
        
        if (filterID > 0)
        {
            filterRenderTexture = NULL;
            filterCache = NULL;
        }
        renderer = NULL;
        glDeleteTextures(1, (GLuint*)&sourceTexture);
        free(pixelData);
    }
    [EAGLContext setCurrentContext:nil];
}

void MadvGLRenderer_iOS::renderImageInMem(unsigned char** outPixels, int* outBytesLength, CGSize destSize, const unsigned char* inPixels, int width, int height, bool withLUT, NSString* sourceURI, int filterID, float* gyroMatrix, int gyroMatrixRank) {
    NSString* lutPath = lutPathOfSourceURI(sourceURI, withLUT, NO);
    withLUT = withLUT && (nil != lutPath);
    //*
    EAGLContext* eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:eaglContext];
    {
        GLuint sourceTexture = 0;
        glGenTextures(1, &sourceTexture);
        glBindTexture(GL_TEXTURE_2D, sourceTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
        glPixelStorei(GL_PACK_ALIGNMENT, 4);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, inPixels);
//        glGenerateMipmap(GL_TEXTURE_2D);
        
        GLRenderTexture renderTexture(destSize.width, destSize.height);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        CHECK_GL_ERROR();
        NSLog(@"status = %d", status);
        
        glEnable(GL_BLEND);
        glPolygonOffset(0.1f, 0.2f);///???
        //    glCullFace(GL_CCW);
        glBlendFunc(GL_ONE, GL_ZERO);
        glViewport(0, 0, destSize.width, destSize.height);
        CHECK_GL_ERROR();
#ifdef USE_MSAA
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFramebuffer);
#else
        glBindFramebuffer(GL_FRAMEBUFFER, renderTexture.getFramebuffer());
#endif
        
        glClearColor(0, 0, 0, 0);
        CHECK_GL_ERROR();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        CHECK_GL_ERROR();
        
        GLRenderTextureRef filterRenderTexture = NULL;
        GLFilterCacheRef filterCache = NULL;
        if (filterID > 0)
        {
            filterCache = new GLFilterCache([[[NSBundle mainBundle] pathForResource:@"lookup" ofType:@"png"] stringByDeletingLastPathComponent].UTF8String);
            filterRenderTexture = new GLRenderTexture(destSize.width, destSize.height);
            filterRenderTexture->blit();
        }
        
        MadvGLRendererRef renderer = new MadvGLRenderer_iOS(lutPath.UTF8String, Vec2f{3456.f, 1728.f}, Vec2f{3456.f, 1728.f});
        renderer->setIsYUVColorSpace(false);
        renderer->setDisplayMode((lutPath ? PanoramaDisplayModeLUT : 0) | PanoramaDisplayModeReFlatten);
//        renderer->setFlipY(false);
        renderer->setSourceTextures(false, sourceTexture, sourceTexture, GL_TEXTURE_2D, false);
        if (gyroMatrixRank > 0)
        {
            renderer->setGyroMatrix(gyroMatrix, gyroMatrixRank);
        }
        renderer->draw(0,0, destSize.width,destSize.height);
        
        if (filterID > 0)
        {
            filterRenderTexture->unblit();
            filterCache->render(filterID, 0, 0, destSize.width, destSize.height, filterRenderTexture->getTexture(), GL_TEXTURE_2D);
        }
        
        CHECK_GL_ERROR();
        if (NULL == *outPixels || renderTexture.bytesLength() > *outBytesLength)
        {
            *outBytesLength = renderTexture.bytesLength();
            *outPixels = (unsigned char*) malloc(*outBytesLength);
        }
        renderTexture.copyPixelData(*outPixels, 0, renderTexture.bytesLength());
        CHECK_GL_ERROR();
        
        if (filterID > 0)
        {
            filterRenderTexture->releaseGLObjects();
            filterCache->releaseGLObjects();
        }
        
        glDeleteTextures(1, &sourceTexture);
    }
    [EAGLContext setCurrentContext:nil];
}

UIImage* MadvGLRenderer_iOS::renderImageWithIDR(NSString* thumbnailPath, CGSize destSize, bool withLUT, NSString* sourceURI, int filterID, float* gyroMatrix, int gyroMatrixRank) {
    //*
    const char* cstrThumbnailPath = thumbnailPath.UTF8String;
    decodeIDR(cstrThumbnailPath, cstrThumbnailPath);
    remove(cstrThumbnailPath);
    
    NSString* bmpPath = [thumbnailPath stringByAppendingPathExtension:@"bmp"];
    UIImage* bmpImage = [UIImage imageWithContentsOfFile:bmpPath];
    /*/
     UIImage* bmpImage = [UIImage imageNamed:@"video.png"];
     //*/
    
    UIImage* renderedImage = renderImage(bmpImage, destSize, withLUT, sourceURI, filterID, gyroMatrix, gyroMatrixRank);
    
    remove(bmpPath.UTF8String);
    
    return renderedImage;
}
