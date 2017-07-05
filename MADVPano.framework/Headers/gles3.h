//
// Created by QiuDong on 16/5/28.
//

#ifndef GLES3JNI_GLES3STUB_H
#define GLES3JNI_GLES3STUB_H

#include "TargetConditionals.h"

#ifdef TARGET_OS_ANDROID
#include <GLES3/gl3.h>
#elif TARGET_OS_IOS
#include <OpenGLES/ES3/gl.h>
#endif

#endif //GLES3JNI_GLES3STUB_H
