//
// Created by QiuDong on 16/5/28.
//

#ifndef GLES3JNI_GLES2STUB_H
#define GLES3JNI_GLES2STUB_H

#include "TargetConditionals.h"

#ifdef TARGET_OS_ANDROID
#include <GLES2/gl2.h>
#elif TARGET_OS_IOS
#include <OpenGLES/ES2/gl.h>
#else
#include <gl/gl.h>
#include <gl/glext.h>//×¢Òâ¶¨ÒåË³Ðò 
//#include <gl/glu.h>

#define _USE_MATH_DEFINES
#include <math.h>
//#include <cmath>

#include <stdint.h>

#define glDeleteVertexArraysOES glDeleteVertexArrays
#define glGenVertexArraysOES glGenVertexArrays
#define glBindVertexArrayOES glBindVertexArray
#define GL_VERTEX_ARRAY_BINDING_OES GL_VERTEX_ARRAY_BINDING

#define GL_RGBA16F_EXT GL_RGBA16F

#endif

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif

#endif //GLES3JNI_GLES2STUB_H
