//
//  GLFilterCache.hpp
//  Madv360_v1
//
//  Created by QiuDong on 16/7/15.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#ifndef GLFilterCache_hpp
#define GLFilterCache_hpp

#include "GLFilter.h"
#include "OpenGLHelper.h"
#include "AutoRef.h"
#include <map>

typedef enum {
    GLFilterNone = 0,
    GLFilterTestID = -1,
    GLFilterSimpleBeautyID = 1,
    GLFilterInverseColorID = 2,
    GLFilterBilateralID = 3,
    GLFilterKuwaharaID = 4,
    GLFilterSepiaToneID = 5,
    GLFilterAmatorkaID = 6,
    GLFilterMissEtikateID = 7,
} GLFilterID;

class GLFilterCache {
public:

    virtual ~GLFilterCache();
    
    GLFilterCache(const char* resourceDirectory);
    
    void releaseGLObjects();
    
    void render(int filterID, GLVAORef vao, GLint sourceTexture, GLenum sourceTextureTarget);
    
    void render(int filterID, GLfloat x, GLfloat y, GLfloat width, GLfloat height, GLint sourceTexture, GLenum sourceTextureTarget);
    
//    void render(int filterID, int x, int y, int width, int height, GLint sourceTexture, GLenum sourceTextureTarget, GLFilterOrientation sourceOrientation);
    
    void render(int filterID, GLfloat x, GLfloat y, GLfloat width, GLfloat height, GLint sourceTexture, GLenum sourceTextureTarget, Orientation2D sourceOrientation, Vec2f texcoordOrigin, Vec2f texcoordSize);
    
    GLFilterRef createFilter(int filterID);

    GLFilterRef obtainFilter(int filterID);
    
private:
    
    std::map<int, GLFilterRef> _filtersOfID;

    const char* _resourceDirectory = NULL;
};

typedef AutoRef<GLFilterCache> GLFilterCacheRef;

#endif /* GLFilterCache_hpp */
