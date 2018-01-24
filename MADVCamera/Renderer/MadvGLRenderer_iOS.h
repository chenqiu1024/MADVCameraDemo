//
//  MadvGLRenderer_iOS.hpp
//  Madv360_v1
//
//  Created by FutureBoy on 4/2/16.
//  Copyright © 2016 Cyllenge. All rights reserved.
//

#ifndef MadvGLRenderer_iOS_hpp
#define MadvGLRenderer_iOS_hpp

#ifdef MADVPANO_BY_SOURCE
#import "OpenGLHelper.h"
#import "MadvGLRenderer.h"
#import "EXIFParser.h"
#else
#import <MADVPano/OpenGLHelper.h>
#import <MADVPano/MadvGLRenderer.h>
#import <MADVPano/EXIFParser.h>
#endif
#include <UIKit/UIKit.h>

#define MADV_DUAL_FISHEYE_VIDEO_TAG @"MADV_DUAL_FISHEYE"

#ifdef __cplusplus
extern "C" {
#endif
    
    inline Vec2f CGPoint2Vec2f(CGPoint point) {
        Vec2f vec2;
        vec2.x = point.x;
        vec2.y = point.y;
        return vec2;
    }

    inline Vec2f CGSize2Vec2f(CGSize size) {
        Vec2f vec2;
        vec2.x = size.width;
        vec2.y = size.height;
        return vec2;
    }
    
    void createOrUpdateTextureWithBitmap(GLubyte *data, GLint pow2Width, GLint pow2Height, void* userData);
    
    GLuint createTextureFromImage(UIImage* image, CGSize destSize);
    
#ifdef __cplusplus
}
#endif

@interface MVPanoRenderer : NSObject

- (void*) internalInstance;

- (instancetype) initWithLUTPath:(NSString*)lutPath leftSrcSize:(CGSize)leftSrcSize rightSrcSize:(CGSize)rightSrcSize;
#ifndef MADVPANO_EXPORT
+ (UIImage*) renderImageWithIDR:(NSString*)idrPath destSize:(CGSize)destSize withLUT:(BOOL)withLUT sourceURI:(NSString*)sourceURI filterID:(int)filterID gyroMatrix:(float*)gyroMatrix gyroMatrixBank:(int)gyroMatrixRank;
#endif //#ifndef MADVPANO_EXPORT
+ (UIImage*) renderImage:(UIImage*)sourceImage destSize:(CGSize)destSize forceLUTStitching:(BOOL)forceLUTStitching sourcePath:(NSString*)sourcePath pMadvEXIFExtension:(MadvEXIFExtension*)pMadvEXIFExtension filterID:(int)filterID gyroMatrix:(float*)gyroMatrix gyroMatrixBank:(int)gyroMatrixRank;

+ (UIImage*) renderJPEG:(NSString*)sourcePath destSize:(CGSize)destSize forceLUTStitching:(BOOL)forceLUTStitching pMadvEXIFExtension:(MadvEXIFExtension*)pMadvEXIFExtension filterID:(int)filterID gyroMatrix:(float*)gyroMatrix gyroMatrixRank:(int)gyroMatrixRank;

+ (BOOL) renderJPEGToJPEG:(NSString*)destJpegPath sourcePath:(NSString*)sourcePath dstWidth:(int)dstWidth dstHeight:(int)dstHeight forceLUTStitching:(BOOL)forceLUTStitching pMadvEXIFExtension:(MadvEXIFExtension*)pMadvEXIFExtension filterID:(int)filterID gyroMatrix:(float*)gyroMatrix gyroMatrixRank:(int)gyroMatrixRank;

+ (BOOL) renderJPEGToJPEG:(NSString*)destJpegPath sourcePath:(NSString*)sourcePath dstWidth:(int)dstWidth dstHeight:(int)dstHeight lutPath:(NSString*)lutPath filterID:(int)filterID gyroMatrix:(float*)gyroMatrix gyroMatrixRank:(int)gyroMatrixRank;

#ifndef MADVPANO_EXPORT
+ (NSString*) lutPathOfSourceURI:(NSString*)sourceURI forceLUTStitching:(BOOL)forceLUTStitching pMadvEXIFExtension:(MadvEXIFExtension*)pMadvEXIFExtension;

+ (NSString*) cameraLUTFilePath:(NSString*)cameraUUID;

+ (NSString*) preStitchPictureFileName:(NSString*)cameraUUID fileName:(NSString*)fileName;
+ (NSString*) stitchedPictureFileName:(NSString*)preStitchPictureFileName;
+ (NSString*) cameraUUIDOfPreStitchFileName:(NSString*)preStitchFileName;

+ (void) extractLUTFiles:(const char*)destDirectory lutBinFilePath:(const char*)lutBinFilePath fileOffset:(uint32_t)fileOffset;
#endif //#ifndef MADVPANO_EXPORT
- (void) setIsYUVColorSpace:(BOOL)isYUVColorSpace;

- (BOOL) isYUVColorSpace;

- (void) prepareLUT:(NSString*)lutPath leftSrcSize:(CGSize)leftSrcSize rightSrcSize:(CGSize)rightSrcSize;

- (void) setTextureMatrix:(kmMat4*)textureMatrix;

- (void) setRenderSource:(void*)renderSource;

- (CGSize) renderSourceSize;

- (void) setGyroMatrix:(float*)matrix rank:(int)rank;

- (GLint) leftSourceTexture;
- (GLint) rightSourceTexture;
- (GLenum) sourceTextureTarget;

- (int) displayMode;
- (void) setDisplayMode:(int)displayMode;

- (void) setEnableDebug:(BOOL)enable;

- (void) setFlipY:(BOOL)flipY;

- (void) drawWithDisplayMode:(int)displayMode x:(int)x y:(int)y width:(int)width height:(int)height /*separateSourceTextures:(BOOL)separateSourceTextures */srcTextureType:(int)srcTextureType leftSrcTexture:(int)leftSrcTexture rightSrcTexture:(int)rightSrcTexture;

- (void) drawWithX:(int)x y:(int)y width:(int)width height:(int)height;

- (int) fovDegree;

@end

#endif /* MadvGLRenderer_iOS_hpp */
