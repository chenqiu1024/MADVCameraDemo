//
//  MediaPlayerViewController.m
//  Madv360_v1
//
//  Created by QiuDong on 16/4/12.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "MediaPlayerViewController.h"
#import "MyGLView.h"
#import "MadvGLRenderer_iOS.h"
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
//#import "PostVideoViewController.h"
//#import "ALAsset+Extensions.h"
#import "UIViewController+Extensions.h"
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
//#import "WXApi.h"
//#import "helper.h"
//#import "MVCloudMediaFavor.h"
//#import "DBHelper.h"
//#import <Masonry/Masonry.h>
#import "z_Sandbox.h"

@interface MediaPlayerViewController ()

@end

@implementation MediaPlayerViewController

@synthesize media;
@synthesize parameters;

#pragma mark    Ctor & Dtor

- (void) dealloc {
}

+ (instancetype) showFromViewController:(UIViewController*)fromViewController media:(MVMedia*)media parameters:(NSDictionary*)parameters {
    //用runtime去把NaviBar的一些设置保存起来
    [fromViewController saveNaviBarAppearance];
    
    //得到MediaPlayerViewController并设置参数
    //UIStoryboard* sb = [UIStoryboard storyboardWithName:@"MediaPlayerStoryboard" bundle:[NSBundle mainBundle]];
    //MediaPlayerViewController* ret = (MediaPlayerViewController*) [sb instantiateViewControllerWithIdentifier:@"MediaPlayer"];
    MediaPlayerViewController* ret = [[MediaPlayerViewController alloc] init];
    ret.isUsedAsEncoder = NO;
    
    NSMutableDictionary* params = [parameters mutableCopy];
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering ///???
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        params[KxMovieParameterDisableDeinterlacing] = @(YES);
    // disable buffering ///!!!
    //            parameters[KxMovieParameterMinBufferedDuration] = @(2.0f);
    //            parameters[KxMovieParameterMaxBufferedDuration] = @(4.0f);
    //        KxPlayerViewController *vc = [[KxPlayerViewController alloc] initWithContentPath:filePath parameters:parameters];
    
    ret.parameters = params;
    ret.media = media;
    ret.panoramaMode = PanoramaDisplayModeStereoGraphic;
    
//    UINavigationController* navigationVC;
//    if (fromViewController.navigationController)
//    {
//        navigationVC = fromViewController.navigationController;
//        [navigationVC pushViewController:ret animated:YES];
//    }
//    else
//    {
//        navigationVC = [[UINavigationController alloc] initWithRootViewController:ret];
//        [fromViewController presentViewController:navigationVC animated:YES completion:nil];
//    }
    [fromViewController presentViewController:ret animated:YES completion:nil];
    return ret;
}

#pragma mark    KxMovieViewController

- (void) didSetupPresentView:(UIView*)presentView {
    presentView.contentMode = UIViewContentModeScaleAspectFit;
    presentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:presentView];
    [self.view sendSubviewToBack:presentView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton* backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [backButton addTarget:self action:@selector(backTap:) forControlEvents:UIControlEventTouchUpInside];
    [backButton setTitle:@"Back" forState:UIControlStateNormal];
    [self.view addSubview:backButton];
    [backButton sizeToFit];
    backButton.frame = CGRectMake(12, 12, backButton.bounds.size.width, backButton.bounds.size.height);

    [self setContentPath:[z_Sandbox documentPath:self.media.localPath] parameters:self.parameters];
}

#pragma mark --返回--
#pragma mark --返回--
- (void)backTap:(id)tap
{
    [self finishGLView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) finishGLView {
    [self stop];
    [self.glView removeFromSuperview];
    self.glView = nil;
#ifdef ENCODING_WITHOUT_MYGLVIEW
    if (self.isUsedAsEncoder) {
        self.encoderRenderLoop.encodingError = [NSError errorWithDomain:@"MadvErrorEncodingCanceled" code:-2 userInfo:@{}];
        //[self.encoderRenderLoop stopEncoding:nil];
    }
    [self.encoderRenderLoop stopRendering];
    [self.encoderRenderLoop stopEncoding];
    self.encoderRenderLoop = nil;
#endif
    NSLog(@"EAGLContext : KxMovieViewController $ finishGLView");
}

@end
