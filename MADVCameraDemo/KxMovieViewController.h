//
//  ViewController.h
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
//#import "BaseViewController.h"
#import "UIViewController+Extensions.h"

#import <Foundation/Foundation.h>
#import <AudioToolBox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
//#import "KxMovieGLView.h"
#import "KxLogger.h"

typedef enum : NSInteger {
    QualityLevel4K = 0,//4k,
    QualityLevel1080 = 1,
    QualityLevelOther = 2,
} QualityLevel;

@class KxMovieDecoder;
@class MyGLView;

extern NSString * const KxMovieParameterMinBufferedDuration;    // Float
extern NSString * const KxMovieParameterMaxBufferedDuration;    // Float
extern NSString * const KxMovieParameterDisableDeinterlacing;   // BOOL

#ifdef __cplusplus
extern "C" {
#endif

NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft);

#ifdef __cplusplus
}
#endif

#ifdef ENCODING_WITHOUT_MYGLVIEW
@class GLRenderLoop;
#endif

@interface KxMovieViewController : UIViewController //BaseViewController

- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters;

- (void) setContentPath:(NSString*)path
             parameters:(NSDictionary*)parameters;

@property (nonatomic, strong) MyGLView* glView;

@property (readonly) BOOL playing;

@property (nonatomic, assign) BOOL isUsedAsEncoder;
@property (nonatomic, assign) QualityLevel encoderQualityLevel;
#ifdef ENCODING_WITHOUT_MYGLVIEW
@property (nonatomic, strong) GLRenderLoop* encoderRenderLoop;
#endif
@property (nonatomic, assign) int panoramaMode;
@property (nonatomic, assign) BOOL isGlassMode;

- (void) setFOVRange:(int)initFOV maxFOV:(int)maxFOV minFOV:(int)minFOV;

@property (nonatomic, assign, readonly) BOOL isCameraGyroDataAvailable;
@property (nonatomic, assign) BOOL isCameraGyroAdustEnabled;

@property (nonatomic, assign) BOOL isLoadingViewVisible;

@property(nonatomic,strong) void(^encodingProgressChangedBlock)(int percent);
@property(nonatomic,strong) void(^encodingDoneBlock)(NSString*, NSError*);

@property (nonatomic, strong) KxMovieDecoder* decoder;
@property (nonatomic, assign) CGFloat previousMoviePosition;
@property(nonatomic,assign)BOOL isFinishEncoder;
@property(nonatomic,assign)CGFloat editStartTime;
@property(nonatomic,assign)CGFloat editEndTime;
@property(nonatomic,assign)BOOL isNewEditTime;
@property (nonatomic, assign) int filterID;

@property (nonatomic, strong) dispatch_queue_t    dispatchQueue;
@property (nonatomic, strong) dispatch_queue_t    dispatchQueueAudioRecord;

- (void) play;
- (void) pause;
- (void) stop;
- (void) restorePlay;

- (void) dismissWaitView;
- (void) showWaitView;
- (void) freeBufferedFrames;

#pragma mark    Protected

- (UIView *) frameView;

- (void) didPlayOver;

- (void) didPlayProgressChanged:(int)percent;

- (void) updateGyroData:(int)frameNumber maxFrameNumber:(int)maxFrameNumber;

+ (int) increaseLiveObjectsCount:(id)retainer;
+ (int) decreaseLiveObjectsCount;

- (int) applyGyroDataOfVideoTime:(float)seconds;

@end
