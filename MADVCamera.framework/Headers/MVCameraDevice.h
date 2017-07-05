//
//  MVCameraDevice.h
//  此类表示一个相机设备对象
//
//  Created by 张巧隔 on 16/8/9.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SettingTreeNode.h"
#import "RLModel.h"

#define STATE_WIFI_CONNECTED 0x01
#define STATE_SESSION_CONNECTING 0x10
#define STATE_SESSION_CONNECTED 0x20

/** 前一次连接相机后固件升级的结果 */
typedef enum : int {
    FirmwareUpdateNone = 0, //未进行固件升级
    FirmwareUpdateSuccess = 1, //固件升级成功
    FirmwareUpdateFail = 2, //固件升级失败
} FirmwareUpdateState;

/** 拍摄主模式 */
typedef enum : NSInteger {
    CAMERA_MODE_VIDEO = AMBA_PARAM_CAMERA_MODE_VIDEO,//摄像
    CAMERA_MODE_PHOTO = AMBA_PARAM_CAMERA_MODE_PHOTO,//拍照
} CameraMode;

/** 拍摄子模式 */
typedef enum : NSInteger {
    CAMERA_SUBMODE_VIDEO_NORMAL = 0,//摄像子模式：常规
    CAMERA_SUBMODE_VIDEO_SLOW = AMBA_MSGID_SET_VIDEO_SLOW_PARAM,//摄像子模式：延时
    CAMERA_SUBMODE_VIDEO_MICRO = AMBA_MSGID_SET_VIDEO_MICRO_PARAM,//摄像子模式：秒拍
    CAMERA_SUBMODE_VIDEO_FILTER = AMBA_MSGID_SET_VIDEO_FILTER,//摄像子模式：滤镜（目前不用）
//    CAMERA_SUBMODE_VIDEO_LIVE = 5,//摄像子模式：直播（预留）
    
    CAMERA_SUBMODE_PHOTO_NORMAL = 0,//拍照子模式：常规
    CAMERA_SUBMODE_PHOTO_TIMING = AMBA_MSGID_SET_PHOTO_TIMING_PARAM,//拍照子模式：定时
    CAMERA_SUBMODE_PHOTO_FILTER = 3,//拍照子模式：美颜
} CameraSubMode;

@class MVMedia;

@interface MVCameraDevice : RLModel

// 持久化的数据：

@property(nonatomic,copy)NSString * SSID;//wifi的名称
@property(nonatomic,copy)NSString * DBSSID;//wifi的名称
@property(nonatomic,copy)NSString * password;//wifi的密码，用于判断是否需要强制用户设置密码
@property(nonatomic,copy)NSString * DBPassword;//wifi的密码，用于判断是否需要强制用户设置密码
@property(nonatomic,copy)NSString * uuid;//相机的唯一ID
@property(nonatomic,copy)NSString * DBUuid;//相机的唯一ID

@property (nonatomic, copy) NSString* fwVer;//相机固件版本号
@property (nonatomic, copy) NSString* DBFwVer;
@property (nonatomic, copy) NSString* rcFwVer;//遥控器固件版本号
@property (nonatomic, copy) NSString* DBRcFwVer;
@property (nonatomic, copy) NSString* serialID;//序列号
@property (nonatomic, copy) NSString* DBSerialID;

@property(nonatomic,copy) NSDate * lastSyncTime;//最近连接时间
@property(nonatomic,copy) NSDate * DBLastSyncTime;//最近连接时间

@property (nonatomic, assign) int jpgCaptured; //相机一共拍摄照片的数量
@property (nonatomic, assign) int DBJpgCaptured;

@property (nonatomic, assign) int mp4Captured; //相机一共拍摄的视频的数量
@property (nonatomic, assign) int DBMp4Captured;

// 非持久化的数据：

// 前一次连接相机后的固件升级结果
@property (nonatomic, assign) FirmwareUpdateState firmwareUpdateState;

// 预览模式
@property (nonatomic, assign) int cameraPreviewMode;

//是否连接
@property(nonatomic,assign)BOOL isConnect;

//当前电量的百分比
@property(nonatomic,assign)int voltagePercent;

//是否正在充电
@property(nonatomic,assign)BOOL isCharging;

//wifi是否连接
@property(nonatomic,assign)BOOL isWifiConnect;

//最近拍摄的媒体文件的缩略图
@property(nonatomic,strong)UIImage * thumbnailImage;
//最近拍摄的媒体文件对象
@property(nonatomic,strong) MVMedia* recentMedia;

@property(nonatomic,assign)BOOL isConnecting;


//拍摄主模式
@property(nonatomic,assign) CameraMode cameraMode;
//拍摄子模式
@property(nonatomic,assign) CameraSubMode cameraSubMode;
//拍摄子模式下设置参数
@property(nonatomic,assign) NSInteger cameraSubModeParam;

#pragma mark    用于相机设置的方法
/**
 * 获取相机全部设置项，以树状结构给出
 * 第一级列表：分组标题
 * 第二级列表：分组中的设置项
 * 第三级列表：分组中设置项下可选的全部设置值，如果该列表为空则说明是一个单一功能选项，比如当设置项为“格式化SD卡”时
 * @return
 */
+ (NSArray<SettingTreeNode *> *)getCameraSettings;

+ (SettingTreeNode *)getCameraModeParameters:(CameraMode)cameraMode cameraSubMode:(CameraSubMode)cameraSubMode;

#pragma mark    Protected

@property(nonatomic,assign)int connectionState;

+ (SettingTreeNode *)findOptionNodeByUID:(int)optionUID;

//之前有这个数据就更新  没有就插入
- (MVCameraDevice *)save;
//- (void) update;

- (void) delete;

- (BOOL)shouldSetWiFiPassword;

+ (MVCameraDevice *)selectWithUUID:(NSString *)uuid;

- (void)copy:(id)sender;

+ (instancetype) create;


@end
