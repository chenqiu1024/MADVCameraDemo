//
//  Log.h
//  Madv360_v1
//
//  Created by QiuDong on 16/6/2.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#ifndef GLES3JNI_LOG_H
#define GLES3JNI_LOG_H

#include "TargetConditionals.h"

//#define DEBUG 0

#ifdef TARGET_OS_ANDROID

#include <android/log.h>

#define LOG_TAG "QD:MADVGL"
#define ALOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#if DEBUG
#define ALOGV(...) __android_log_print(ANDROID_LOG_VERBOSE, LOG_TAG, __VA_ARGS__)
#else
#define ALOGV(...)
#endif

#elif TARGET_OS_IOS

#include <Foundation/Foundation.h>
//#include "LogManager.h"

#ifdef ENABLE_DOCTOR_LOG
#define ALOGE(...) DoctorLog(@__VA_ARGS__)
#define ALOGV(...) DoctorLog(@__VA_ARGS__)
#else
#define ALOGE(...) NSLog(@__VA_ARGS__)
#define ALOGV(...) NSLog(@__VA_ARGS__)
#endif

//#define ALOGE(...) printf(__VA_ARGS__)
//#define ALOGV(...) printf(__VA_ARGS__)

#elif TARGET_OS_WINDOWS

#define ALOGE(...) TRACE(__VA_ARGS__)
#define ALOGV(...) TRACE(__VA_ARGS__)

#else

#ifdef DEBUG
#define ALOGE(...) printf(__VA_ARGS__)
#define ALOGV(...) printf(__VA_ARGS__)
#else
#define ALOGE(...)
#define ALOGV(...)
#endif

#endif

#endif //GLES3JNI_LOG_H
