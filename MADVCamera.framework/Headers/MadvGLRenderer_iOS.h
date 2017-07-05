//
//  MadvGLRenderer_iOS.hpp
//  Madv360_v1
//
//  Created by FutureBoy on 4/2/16.
//  Copyright © 2016 Cyllenge. All rights reserved.
//

#ifndef MadvGLRenderer_iOS_hpp
#define MadvGLRenderer_iOS_hpp

#include <MADVPano/MadvGLRenderer.h>
#include <UIKit/UIKit.h>

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

class MadvGLRenderer_iOS : public MadvGLRenderer {
public:
    
    virtual ~MadvGLRenderer_iOS();
    
    MadvGLRenderer_iOS(const char* lutPath, Vec2f leftSrcSize, Vec2f rightSrcSize);
    
    static UIImage* renderImageWithIDR(NSString* thumbnailPath, CGSize destSize, bool withLUT, NSString* sourceURI, int filterID, float* gyroMatrix, int gyroMatrixRank);
    static UIImage* renderImage(UIImage* sourceImage, CGSize destSize, bool withLUT, NSString* sourceURI, int filterID, float* gyroMatrix, int gyroMatrixRank);
    static UIImage* renderJPEG(const char* sourcePath, CGSize destSize, bool withLUT, NSString* sourceURI, bool lutEmbeddedInJPEG, int filterID, float* gyroMatrix, int gyroMatrixRank);
    static void renderJPEGToJPEG(NSString* destJpegPath, NSString* sourcePath, int dstWidth, int dstHeight, bool withLUT, bool lutEmbeddedInJPEG, int filterID, float* gyroMatrix, int gyroMatrixRank);
    static void renderImageInMem(unsigned char** outPixels, int* outBytesLength, CGSize destSize, const unsigned char* inPixels, int width, int height, bool withLUT, NSString* sourceURI, int filterID, float* gyroMatrix, int gyroMatrixRank);
    
    static NSString* lutPathOfSourceURI(NSString* sourceURI, bool withLUT, bool lutEmbeddedInJPEG);
    
    static NSString* cameraLUTFilePath(NSString* cameraUUID);
    
    static NSString* preStitchPictureFileName(NSString* cameraUUID, NSString* fileName);
    static NSString* stitchedPictureFileName(NSString* preStitchPictureFileName);
    static NSString* cameraUUIDOfPreStitchFileName(NSString* preStitchFileName);
    
    static void extractLUTFiles(const char* destDirectory, const char* lutBinFilePath, uint32_t fileOffset);
    
protected:
    
    void prepareTextureWithRenderSource(void* renderSource);
    
    //For iOS8HD
    struct __CVOpenGLESTextureCache * _videoTextureCache;
    struct __CVOpenGLESTexture *      _videoDestTexture;
};

#endif /* MadvGLRenderer_iOS_hpp */
