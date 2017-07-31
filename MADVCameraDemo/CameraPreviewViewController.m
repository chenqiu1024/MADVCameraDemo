//
//  FirstViewController.m
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import "CameraPreviewViewController.h"
#import "MVCameraClient.h"
#import <AVFoundation/AVFoundation.h>

@interface CameraPreviewViewController () <MVCameraClientObserver>
{
    AVAudioPlayer* _audioPlayer;
    NSMutableArray<NSURL* >* _audioSourceURLs;
    
    NSTimeInterval _audioStartTime;
    NSTimeInterval _currentVideoTimeMills;
}

- (void) setShootButtonAppearance:(BOOL)shooting;

@end

@implementation CameraPreviewViewController

#pragma mark    Events

- (IBAction)connectButtonClicked:(id)sender {
    [[MVCameraClient sharedInstance] connectCamera];
    self.connectButton.enabled = NO;
}

- (IBAction)shootButtonTouchDown:(id)sender {
    self.shootButton.enabled = NO;
    [[MVCameraClient sharedInstance] startShooting];
}

- (IBAction)shootButtonTouchUp:(id)sender {
    NSLog(@"#Douyin# APP willStopCapturing, Before pauseAudioPlayer");
    [self pauseAudioPlayer];
    NSLog(@"#Douyin# APP willStopCapturing, After pauseAudioPlayer");
    
    self.shootButton.enabled = NO;
    NSLog(@"#Douyin# APP willStopCapturing, Before stopShooting");
    [[MVCameraClient sharedInstance] stopShooting];
    NSLog(@"#Douyin# APP willStopCapturing, After stopShooting");
}

- (void) setShootButtonAppearance:(BOOL)shooting {
    if (shooting)
    {
        self.shootButton.layer.cornerRadius = 3;
        self.shootButton.backgroundColor = [UIColor darkGrayColor];
    }
    else
    {
        self.shootButton.layer.cornerRadius = self.shootButton.bounds.size.width / 2;
        self.shootButton.backgroundColor = [UIColor redColor];
    }
}

- (IBAction)set15sButtonClicked:(id)sender {
    [[MVCameraClient sharedInstance] setVideoSegmentSeconds:15];
}

- (IBAction)set30sButtonClicked:(id)sender {
    [[MVCameraClient sharedInstance] setVideoSegmentSeconds:30];
}

#pragma mark    MVCameraClientObserver

- (void) willConnect {
    
}

/** 连接相机成功。此时state属性为CameraClientStateConnected
 * device: 连接到的相机设备，其中包含了其唯一ID、SSID、密码等等信息，见#MVCameraDevice#类
 */
-(void) didConnectSuccess:(MVCameraDevice*) device {
///!!!    self.connectButton.hidden = YES;
    self.connectButton.enabled = YES;
    self.shootButton.hidden = NO;
    [self setShootButtonAppearance:NO];
    
    [self setContentPath:@"rtsp://192.168.42.1/live" parameters:nil];
}

/** 连接相机失败。此时state属性为CameraClientStateNotConnected
 *  errorMessage: 错误提示信息
 */
- (void) didConnectFail:(NSString *)errorMessage {
    self.connectButton.enabled = YES;
}

/** 设置相机WiFi结果 */
-(void) didSetWifi:(BOOL)success errMsg:(NSString *)errMsg {
    
}

/** 重启相机WiFi结果 */
-(void) didRestartWifi:(BOOL)success errMsg:(NSString *)errMsg {
    
}

/** 即将断开
 * reason: 断开连接的原因，见#CameraDisconnectReason#枚举
 */
-(void) willDisconnect:(CameraDisconnectReason)reason {
    
}

/** 断开相机连接（包括主动断开和异常断开都会到这里）。此时state属性会返回CameraClientStateNotConnected
 * reason: 断开连接的原因，见#CameraDisconnectReason#枚举
 */
-(void) didDisconnect:(CameraDisconnectReason)reason {
    
}

/** 相机电量发生变化的通知
 * percent: 电量百分比数
 * isCharging: 是否正在充电
 */
-(void) didVoltagePercentChanged:(int)percent isCharging:(BOOL)isCharging {
    
}

/** 相机拍摄模式发生变化
 * mode: 主模式，见#MVCameraDevice#的#CameraMode#枚举值
 * subMode: 子模式，见#MVCameraDevice#的#CameraSubMode#枚举值
 * param: 子模式下具体设置值，如延时摄像时是倍速数，定时拍照时是倒计时秒数
 */
-(void) didCameraModeChange:(CameraMode)mode subMode:(CameraSubMode)subMode param:(NSInteger) param {
    
}

/** 相机模式切换失败
 *
 * @param errMsg
 */
- (void) didSwitchCameraModeFail:(NSString *)errMsg {
    
}

-(void) willStopCapturing:(id)param {
    NSLog(@"#Douyin# APP willStopCapturing");
    ///!!![self shootButtonTouchUp:self.shootButton];
    [self pauseAudioPlayer];
    
    if (param && [param intValue] == 1)
    {
        [self resetAudioPlayer:[self randomSelectAudioSource]];
    }
}

-(void) willStartCapturing:(id)param {
    NSLog(@"#Douyin# APP willStartCapturing");
    ///!!![self shootButtonTouchUp:self.shootButton];
    [self resumeAudioPlayer];
    ///!!![[MVCameraClient sharedInstance] startShooting];
    [[MVCameraClient sharedInstance] startShootingWithTimeoutMills:500];
}

/** 摄像启动
 * error: 错误代码。如果正常启动摄像应为0
 */
- (void) didBeginShooting:(int)error numberOfPhoto:(int)numberOfPhoto {
    if (!error)
    {
        NSLog(@"#Douyin# APP didBeginShooting, Before resumeAudioPlayer");
        ///!!![self resumeAudioPlayer];
        NSLog(@"#Douyin# APP didBeginShooting, After resumeAudioPlayer");
        
        [self setShootButtonAppearance:YES];
        self.shootButton.enabled = YES;
    }
    else
    {
        [self pauseAudioPlayer];
//        [self setShootButtonAppearance:NO];
        self.shootButton.enabled = YES;
    }
}

/** 摄像时长计时器回调
 * 拍摄预览界面上的计时显示应该以此回调的数值为准。应用层无需自己设置计时器
 * shootTime: 摄像开始到当前时刻的秒数
 * videoTime: 实际拍摄出的视频的当前时长（只在延时摄像时有意义，其它情况下与shootTime一致）
 */
- (void) didShootingTimerTick:(int)shootTime videoTime:(int)videoTime {
    
}

/** 定时拍照倒计时回调 */
- (void) didCountDownTimerTick:(int)timingStart {
    
}

/** 摄像（或定时拍照）已停止 参数没什么用  只是告诉摄像已完成*/
-(void) didEndShooting:(NSString *)remoteFilePath videoDurationMills:(NSInteger)videoDurationMills error:(int)error errMsg:(NSString *)errMsg {
    if (!error)
    {
        [self setShootButtonAppearance:NO];
        self.shootButton.enabled = YES;
    }
    else
    {
        //        [self setShootButtonAppearance:YES];
        self.shootButton.enabled = YES;
    }
    
    _currentVideoTimeMills += videoDurationMills;
    _audioStartTime = (_currentVideoTimeMills - DOUYIN_T2_AUDIO_MILLS) / 1000.f;
    if (_audioStartTime < 0)
    {
        _audioStartTime = 0;
    }
    NSLog(@"#Douyin# duration=%ld, _currentVideoTimeMills=%d, _audioStartTime=%.3f", (long)videoDurationMills, (int)_currentVideoTimeMills, _audioStartTime);
}

/** 存储卡写入缓慢的通知 */
- (void) didSDCardSlowlyWrite {
    
}

/** 录像停止
 * error: 错误代码。如果正常停止摄像应为0
 */
- (void)didStopShooting:(int)error {
}

///** 摄像或拍照结束后得到缩略图 */
//-(void) didTakeMedia:(UIImage *)thumbnailImage;

///** 录剪已启动 */
//-(void) didClippingBegin;
///** 录剪片段计时器回调，secondsLeft为当前录剪片段还剩余的时长（秒） */
//-(void) didClippingTimerTick:(int)secondsLeft;
///** 录剪已结束，totalClips为当前摄像过程总共录剪的片段数 */
//-(void) didClippingEnd:(int)totalClips;

/** 相机设置发生变化
 * optionUID: 设置项ID
 * paramUID: 设置项下子项的ID
 * errMsg: 发生错误时错误信息
 */
-(void) didSettingsChange:(int)optionUID paramUID:(int)paramUID errMsg:(NSString *)errMsg {
    
}

-(void) didReceiveAllSettingItems:(int)errorCode {
    
}

/**
 * 相机工作状态发生变化
 * @param workState 相机工作状态，见#CameraWorkState#枚举
 */
-(void) didWorkStateChange:(CameraWorkState)workState {
    
}

/**
 * 相机存储卡加载状态发生变化
 * @param mounted:存储卡加载状态，见#StorageMountState#枚举
 */
-(void) didStorageMountedStateChanged:(StorageMountState)mounted {
    
}

/**
 * 相机SD卡存储容量发生变化
 * @param capacity StorageCapacityAvailable:未满; StorageCapacityAboutFull:将满; StorageCapacityFull:已满;
 */
-(void) didStorageStateChanged:(StorageState)newState oldState:(StorageState)oldState {
    
}

/** 存储卡容量发生变化 */
- (void) didStorageTotalFreeChanged:(int)total free:(int)free {
    
}

/**
 * 收到相机发来的通知，需要UI通知给用户
 * @param notification: 以字符串常量表示的通知，如#NotificationFormatWithoutSD#等
 */
-(void) didReceiveCameraNotification:(NSString*)notification {
    
}

#pragma mark    KxMovieViewController

- (void) didSetupPresentView:(UIView*)presentView {
    presentView.contentMode = UIViewContentModeScaleAspectFit;
    presentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:presentView];
    [self.view sendSubviewToBack:presentView];
}

#pragma mark    Ctor & Dtor

- (void) dealloc {
    [[MVCameraClient sharedInstance] removeObserver:self];
}

#pragma mark    UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd";
    NSDateFormatter* timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.dateFormat = @"hh:mm:ss.SSS";
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.016 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSDate* now = [NSDate date];
        self.dateLabel.text = [dateFormatter stringFromDate:now];
        self.timerLabel.text = [timeFormatter stringFromDate:now];
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
    [[MVCameraClient sharedInstance] addObserver:self];
    
    NSMutableArray<NSString* >* paths = [[[NSBundle mainBundle] pathsForResourcesOfType:@"mp3" inDirectory:nil] mutableCopy];
    NSString* documentDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSDirectoryEnumerator<NSString* >* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:documentDirectory];
    for (NSString* filename in enumerator)
    {
        if ([[[filename pathExtension] lowercaseString] isEqualToString:@"mp3"])
        {
            [paths addObject:[documentDirectory stringByAppendingPathComponent:filename]];
        }
    }
    _audioStartTime = -1.f;
    _audioSourceURLs = [[NSMutableArray alloc] init];
    for (NSString* path in paths)
    {
        [_audioSourceURLs addObject:[NSURL fileURLWithPath:path]];
    }
    
    srand48((long) [[NSDate date] timeIntervalSince1970]);

    [self resetAudioPlayer:[self randomSelectAudioSource]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark    Private

- (NSURL*) randomSelectAudioSource {
    if (!_audioSourceURLs || 0 == _audioSourceURLs.count)
        return nil;
    else if (1 == _audioSourceURLs.count)
        return _audioSourceURLs[0];
    else
    {
        NSURL* ret = _audioSourceURLs[0];
        int index = rand() % (_audioSourceURLs.count - 1) + 1;
        [_audioSourceURLs exchangeObjectAtIndex:index withObjectAtIndex:0];
        return ret;
    }
}

- (void) resetAudioPlayer:(NSURL*)sourceURL {
    if (!sourceURL)
        return;
    
    _currentVideoTimeMills = 0;
    _audioStartTime = 0;
    if (!_audioPlayer || ![_audioPlayer.url isEqual:sourceURL])
    {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:sourceURL error:nil];
        //设置声音的大小
        _audioPlayer.volume = 1;//范围为（0到1）；
        //设置循环次数，如果为负数，就是无限循环
        _audioPlayer.numberOfLoops =-1;
        //设置播放进度
        _audioPlayer.currentTime = 0;
        //准备播放
        [_audioPlayer prepareToPlay];
    }
    else
    {
        //设置播放进度
        _audioPlayer.currentTime = 0;
    }
}

- (void) pauseAudioPlayer {
//    [self.logView addTimedLogLine:@"#Douyin# pauseAudioPlayer : Before dispatch_async" ofTag:@"Douyin"];
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//    [self.logView addTimedLogLine:@"#Douyin# pauseAudioPlayer : Before audioPlayer pause" ofTag:@"Douyin"];
        [_audioPlayer pause];
//    [self.logView addTimedLogLine:@"#Douyin# pauseAudioPlayer : After audioPlayer pause" ofTag:@"Douyin"];
//    [self.logView show];
    //});
    _audioStartTime = _audioPlayer.currentTime;
    NSLog(@"#Douyin# pauseAudioPlayer at _audioStartTime=%.3f", _audioStartTime);
}

- (void) resumeAudioPlayer {
    NSLog(@"#Douyin# resumeAudioPlayer from _audioStartTime=%.3f", _audioStartTime);
    if (_audioStartTime >= 0)
    {
        _audioPlayer.currentTime = _audioStartTime;
    }
    NSLog(@"#Douyin# resumeAudioPlayer [_audioPlayer play] at currentTime=%.3f", _audioPlayer.currentTime);
//    [self.logView addTimedLogLine:@"#Douyin# resumeAudioPlayer : Before dispatch_async" ofTag:@"Douyin"];
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        [self.logView addTimedLogLine:@"#Douyin# resumeAudioPlayer : Before audioPlayer play" ofTag:@"Douyin"];
        [_audioPlayer play];
//        [self.logView addTimedLogLine:@"#Douyin# resumeAudioPlayer : After audioPlayer play" ofTag:@"Douyin"];
//        [self.logView show];
    //});
}

@end
