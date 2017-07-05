//
//  MVMedia.h
//  Madv360_v1
//
//  Created by 张巧隔 on 16/8/10.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RLModel.h"

// 下载状态枚举值：
typedef enum : NSInteger {
    MVMediaDownloadStatusNone = 0,//不在下载队列中,
    MVMediaDownloadStatusDownloading = 0x02,//正在下载,
    MVMediaDownloadStatusPending = 0x04,//排队中未下载,
    MVMediaDownloadStatusStopped = 0x08,//停止,
    MVMediaDownloadStatusFinished = 0x10,//已下载完成,
    MVMediaDownloadStatusError = 0x20,//发生错误而中止,
} MVMediaDownloadStatus;

typedef enum : NSInteger {
        MVMediaTypePhoto = 0,
        MVMediaTypeVideo = 1,
} MVMediaType;

typedef enum : int {
    StitchTypeFishEye = 0x54590000,
    StitchTypeStitched = 0,
    StitchTypePreserved = 0,
} StitchType;

@interface MVMedia : RLModel <NSCopying>
/**
 * 获得该媒体文件的下载状态
 */
@property(nonatomic,assign) MVMediaDownloadStatus downloadStatus;

/**
 * 获得该媒体文件的类型
 */
@property(nonatomic,assign) MVMediaType mediaType;
@property(nonatomic,assign) MVMediaType dbMediaType;

/**
 * 如果该媒体文件来自相机，则返回该相机的唯一ID；否则若该媒体纯粹来自手机本地，则返回null
 */
@property(nonatomic,copy)NSString * cameraUUID;
@property(nonatomic,copy)NSString * dbCameraUUID;

/**
 * 如果该媒体文件来自相机，则返回其在相机上的相对路径（相对于存储卡根目录）；否则若该媒体纯粹来自手机本地，则返回null
 */
@property(nonatomic,copy)NSString * remotePath;
@property(nonatomic,copy)NSString * dbRemotePath;

/**
 * 若该媒体纯粹来自手机本地，返回自本地存储根目录(Documents目录)的相对路径
 */
@property(nonatomic,copy)NSString * localPath;
@property(nonatomic,copy)NSString * dbLocalPath;

/**
 * 返回该媒体文件的缩略图文件的本地路径（.png格式）
 */
@property(nonatomic,copy)NSString * thumbnailImagePath;
@property(nonatomic,copy)NSString * dbThumbnailImagePath;

/**
 * 获得该媒体文件的创建日期
 */
@property(nonatomic,strong) NSDate * createDate;
@property(nonatomic,strong) NSDate * dbCreateDate;

/**
 * 获得该媒体文件的最后修改日期
 */
@property(nonatomic,strong)NSDate * modifyDate;
@property(nonatomic,strong)NSDate * dbModifyDate;

/**
 * 获得该媒体文件的总大小（字节数）
 */
@property(nonatomic,assign) NSInteger size;
@property(nonatomic,assign) NSInteger dbSize;

/**
 * 获得该媒体文件已下载到本地的大小（字节数）
 */
@property(nonatomic,assign) NSInteger downloadedSize;
@property(nonatomic,assign) NSInteger dbDownloadedSize;

@property (nonatomic, copy) NSData* downloadResumeData;
@property (nonatomic, copy) NSData* dbDownloadResumeData;

/**
 * 获得视频时长
 */
@property(nonatomic,assign) NSInteger videoDuration;
@property(nonatomic,assign) NSInteger dbVideoDuration;

/**
 * 获得该媒体文件所应用的图像滤镜ID（目前仅针对图片）
 */
@property(nonatomic,assign) NSInteger filterID;
@property(nonatomic,assign) NSInteger dbFilterID;

/**
 * 图片是否是已拼接好的
 */
@property(nonatomic,assign) BOOL isStitched;
@property(nonatomic,assign) BOOL dbIsStitched;

@property(nonatomic,copy) NSString* gyroMatrixString;
@property(nonatomic,copy) NSString* dbGyroMatrixString;

/** 可唯一标识一个媒体对象的字符串，可以用作字典的key使用 */
- (NSString *)storageKey;

/** 判断该MVMedia对象与other是否源自同一个相机媒体文件 */
- (BOOL)isEqualRemoteMedia:(MVMedia *)other;

/**
 * 根据指定的(cameraUUID, remotePath, localPath)三元组查询MVMedia
 * */
+ (instancetype) querySavedMediaWithCameraUUID:(NSString *)cameraUUID remotePath:(NSString *)remotePath localPath:(NSString *)localPath;

/**
 * 查询包含指定的(cameraUUID, remotePath)二元组的所有MVMedia。
 * 如果没有(cameraUUID, remotePath)二元组，表示是纯本地媒体，则只按localPath查询
 * @param cameraUUID
 * @param remotePath
 * @param localPath
 * @return
 */
+ (NSArray<MVMedia *> *)querySavedMediasWithCameraUUID:(NSString *)cameraUUID remotePath:(NSString *)remotePath localPath:(NSString *)localPath;

#pragma mark    Protected

/**
 * 保存到手机相册后标示用;分割开
 */
@property(nonatomic,copy)NSString * localIdentifier;

@property(nonatomic,copy)NSString * dbLocalIdentifier;

@property(nonatomic,assign)NSInteger finishDownloadedSize;
@property(nonatomic,assign)int error;

+ (NSString *)storageKeyWithCameraUUID:(NSString *)cameraUUID remotePath:(NSString *)remotePath localPath:(NSString *)localPath;

+ (NSString*) uniqueLocalPathWithCameraUUID:(NSString*)cameraUUID remotePath:(NSString*)remotePath;

+ (instancetype) create;

+ (instancetype) createWithCameraUUID:(NSString *)cameraUUID remoteFullPath:(NSString *)remoteFullPath;

+ (NSArray<MVMedia *> *)queryDownloadedMedias;

+ (NSDictionary<NSString*, MVMedia* >*) querySavedMediasWithCameraUUID:(NSString*)cameraUUID;

+ (instancetype) querySavedMediaWithRemotePath:(NSString*)remotePath localPath:(NSString*)localPath;

//获取已经下载好的media
+ (MVMedia *)obtainDownloadedMedia:(MVMedia *)media;

+ (NSString *)StringOfDownloadStatus:(int)status;

+ (NSDate*) dateFromFileName:(NSString*)lowerFileName;

- (MVMedia *) obtainDownloadedOrThisMedia;

- (void)saveCommonFields;
- (void)copyCommonFields:(MVMedia *)media;

- (void)update;

- (id) copy:(id)obj;

+ (void) test;

@end
