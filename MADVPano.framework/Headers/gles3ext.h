//
// Created by QiuDong on 16/5/28.
//

#ifndef GLES3JNI_GLES3EXT_H
#define GLES3JNI_GLES3EXT_H

#include "TargetConditionals.h"

#ifdef TARGET_OS_ANDROID
#define GL_GLEXT_PROTOTYPES
#include <GLES3/gl3ext.h>
#elif TARGET_OS_IOS
#include <OpenGLES/ES3/glext.h>
#endif

#endif //GLES3JNI_GLES3EXT_H
