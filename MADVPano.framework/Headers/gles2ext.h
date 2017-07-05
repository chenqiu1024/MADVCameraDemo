//
// Created by QiuDong on 16/5/28.
//

#ifndef GLES3JNI_GLES2EXT_H
#define GLES3JNI_GLES2EXT_H

#include "TargetConditionals.h"

#ifdef TARGET_OS_ANDROID
#define GL_GLEXT_PROTOTYPES
#include <GLES2/gl2ext.h>
#elif TARGET_OS_IOS
#include <OpenGLES/ES2/glext.h>
#endif

#ifndef GL_READ_ONLY_ARB
#define GL_READ_ONLY_ARB                  0x88B8
#endif

#endif //GLES3JNI_GLES2EXT_H
