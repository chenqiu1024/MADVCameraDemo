//
//  GLRenderTexture.hpp
//  Madv360_v1
//
//  Created by FutureBoy on 4/2/16.
//  Copyright © 2016 Cyllenge. All rights reserved.
//

#ifndef GLRenderBuffer_hpp
#define GLRenderBuffer_hpp

#include "gles2.h"
#include "AutoRef.h"

class GLRenderTexture {
public:
    
    virtual ~GLRenderTexture() {
		releaseGLObjects();
	}
    
    GLRenderTexture(GLint width, GLint height);
    
    GLRenderTexture(GLint texture, GLenum textureType, GLint width, GLint height);

	GLRenderTexture(GLint texture, GLenum textureTarget, GLint width, GLint height, GLenum internalFormat, GLenum format, GLenum dataType);

    inline GLuint getFramebuffer() {return _framebuffer;}
    inline GLuint getTexture() {return _texture;}
    inline GLenum getTextureTarget() {return _textureTarget;}

	inline GLint getWidth() {return _width;}
	inline GLint getHeight() {return _height;}

	GLint bytesLength();

	void blit();
	void unblit();

    bool resizeIfNecessary(GLint width, GLint height);
    
	void releaseGLObjects();

    int copyPixelData(uint8_t* data, int offset, int length);

	GLubyte* copyPixelDataFromPBO(int offset, int length);

private:
    
	GLint _prevFramebuffer;
    GLuint _framebuffer = -1;
    
    GLuint _texture = -1;
    GLenum _textureTarget = GL_TEXTURE_2D;
    bool _ownTexture = true;
    
    GLint _width;
    GLint _height;

	GLenum _format;
	GLenum _internalFormat;
	GLenum _dataType;

//	bool _isPBOSupported;
//	GLuint _pboIDs[2];
//	int _pboIndex;
};

typedef AutoRef<GLRenderTexture> GLRenderTextureRef;

#endif /* GLRenderBuffer_hpp */
