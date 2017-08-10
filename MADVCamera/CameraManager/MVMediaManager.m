//
//  MVMediaManager.m
//  Madv360_v1
//
//  Created by 张巧隔 on 16/8/10.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "MVMediaManager.h"
#import "MVCameraClient.h"
#import "MVCameraDevice.h"
#import "MVCameraDownloadManager.h"
#import "AMBARequest.h"
#import "AMBAResponse.h"
#import "AMBAListResponse.h"
#import "AMBAGetMediaInfoResponse.h"
#import "PathTreeNode.h"
#import "RealmSerialQueue.h"
#import "z_Sandbox.h"
#import "MadvGLRenderer_iOS.h"
#import "NSRecursiveCondition.h"

#ifdef USE_IMAGE_BLENDER
#import "ImageBlender.h"
#endif

#ifdef MADVPANO_BY_SOURCE
#import "EXIFParser.h"
#import "MadvUtils.h"
#import "JPEGUtils.h"
#else
#import <MADVPano/EXIFParser.h>
#import <MADVPano/MadvUtils.h>
#import <MADVPano/JPEGUtils.h>
#endif

#import <AVFoundation/AVFoundation.h>

typedef enum : int {
    FileIteratingIdle = 0,
    FileIteratingBusy = 1,
    FileIteratingPausing = 2,
} FileIteratingState;

#define MsgDataSourceCameraUpdated 0
#define MsgDataSourceLocalUpdated 1
#define MsgMediaInfoFetched 2
#define MsgDownloadStatusChanged 3
#define MsgDownloadProgressUpdated 4
#define MsgThumbnailFetched 5
#define MsgLowDiskSpace 6
#define MsgDownloadingsHung 7

//#ifdef LUT_STITCH_PICTURE
//static const BOOL STITCH_PICTURE = YES;
//#else
//static const BOOL STITCH_PICTURE = NO;
//#endif

@implementation MediaThummaryResult

    @synthesize thumbnail;
    @synthesize thumbnailPath;
    @synthesize isMediaInfoAvailable;

@end

@interface MediaDownloadTaskPair : NSObject

@property (nonatomic, strong) MVMedia* media;
@property (nonatomic, strong) MVDownloadTask* downloadTask;

- (instancetype) initWithMedia:(MVMedia*)media downloadTask:(MVDownloadTask*)downloadTask;

@end

@implementation MediaDownloadTaskPair

- (instancetype) initWithMedia:(MVMedia *)media downloadTask:(MVDownloadTask *)downloadTask {
    if (self = [super init])
    {
        self.media = media;
        self.downloadTask = downloadTask;
    }
    return self;
}

@end

@interface ThumbnailDecodeTask : NSObject
{
    MVMedia* _media;
    uint8_t* _data;
}

- (instancetype) initWithMedia:(MVMedia*)media data:(uint8_t*)data;

@property (nonatomic, strong) MVMedia* media;
@property (nonatomic, assign) uint8_t* data;

@end

@implementation ThumbnailDecodeTask

@synthesize media = _media;
@synthesize data = _data;

- (instancetype) initWithMedia:(MVMedia *)media data:(uint8_t *)data {
    if (self = [super init])
    {
        _media = media;
        _data = data;
    }
    return self;
}

- (BOOL) isEqual:(id)object {
    if (![object isKindOfClass:ThumbnailDecodeTask.class]) return NO;
    
    ThumbnailDecodeTask* other = (ThumbnailDecodeTask*) object;
    if (_media.remotePath && _media.remotePath.length > 0)
    {
        return [_media isEqualRemoteMedia:other.media];
    }
    else
    {
        return [_media.localPath isEqualToString:other.media.localPath];
    }
}

@end


@interface ThumbnailCacheItem : NSObject

@property (nonatomic, strong) UIImage* thumbnail;
@property (nonatomic, copy) NSString* key;

- (instancetype) initWithKey:(NSString*)key thumbnail:(UIImage*)thumbnail;

@end

@implementation ThumbnailCacheItem

@synthesize thumbnail;
@synthesize key;

- (instancetype) initWithKey:(NSString*)cacheKey thumbnail:(UIImage*)cacheThumbnail {
    if (self = [super init])
    {
        self.key = cacheKey;
        self.thumbnail = cacheThumbnail;
    }
    return self;
}

@end

@interface MVMediaManager () <PathTreeIteratorDelegate, NSCacheDelegate>
{
    NSMutableArray<id<MVMediaDataSourceObserver> >* _dataSourceObservers;
    NSMutableArray<id<MVMediaDownloadStatusObserver> >* _downloadStatusObservers;
    
    NSMutableArray<MVMedia* >* _cameraMedias;
    NSMutableArray<MVMedia* >* _localMedias;
    BOOL _cameraMediasInvalid;
    BOOL _localMediasInvalid;
    
    FileIteratingState _fileIteratingState;
    NSRecursiveCondition* _fileIteratingCond;
    NSMutableArray<NSString* >* _remoteFilePaths;
    PathTreeIterator* _fileIterator;
    
    NSMutableArray<MVDownloadTask* >* _downloadTasks;
    NSMutableArray<MVMedia* >* _hangingDownloadMedias;
    BOOL _isDownloadingHanging;
    
    NSCache<NSString*, ThumbnailCacheItem* >* _thumbnailCache;
    
    dispatch_queue_t _enqueDownloadQueue;
    dispatch_queue_t _thummaryQueue;
    dispatch_queue_t _imageRenderQueue;
    
    NSRecursiveCondition* _thummaryCond;
    BOOL _isBusyFetchingThummary;
    
    NSMutableDictionary<NSString*, MVMedia* >* _fetchingThummaryMedias;
    NSMutableDictionary<NSString*, NSNumber* >* _thummaryFetchedTime;
    NSMutableDictionary<NSString*, NSDate* >* _justCreatedMediaTime;
}

@property (nonatomic, strong) NSMutableArray<MVDownloadTask* >* downloadTasks;
@property (nonatomic, strong) dispatch_queue_t imageRenderQueue;

@property (nonatomic, assign) FileIteratingState fileIteratingState;
@property (nonatomic, strong) NSRecursiveCondition* fileIteratingCond;
@property (nonatomic, strong) NSMutableArray<NSString* >* remoteFilePaths;
@property (nonatomic, strong) PathTreeIterator* fileIterator;

@property (nonatomic, strong) NSMutableArray<MVMedia* >* cameraMedias;
@property (nonatomic, assign) BOOL cameraMediasInvalid;

- (NSArray<MVMedia*>*) cameraMediasAsync;

//- (void) setMediaThummaryFetched:(MVMedia*)media;

/** 置当前的相机媒体文件列表为需要更新状态，使得下次调用cameraMedias时强制刷新
 *  应用层可能不会直接用到
 * @param refresh : 是否立即刷新
 */
-(void) invalidateCameraMedias:(BOOL)refresh;

/** 添加媒体文件到相机媒体文件列表
 * 应用层可能不会直接用到
 */
- (void)addNewCameraMedia:(MVMedia *)media justCreated:(BOOL)justCreated;

//// 目前save和load没有用到
///** 在App被关闭或切到后台时调用此方法。它会将需要持久化存储的数据（如下载队列）保存 */
//-(void) save;
///** 在App被启动或切到前台时调用此方法。它会将需要持久化存储的数据（如下载队列）加载 */
//-(void)load;

@end

@implementation MVMediaManager

@synthesize downloadTasks = _downloadTasks;
@synthesize imageRenderQueue = _imageRenderQueue;

@synthesize fileIteratingState = _fileIteratingState;
@synthesize fileIteratingCond = _fileIteratingCond;
@synthesize remoteFilePaths = _remoteFilePaths;
@synthesize fileIterator = _fileIterator;

@synthesize cameraMedias = _cameraMedias;
@synthesize cameraMediasInvalid = _cameraMediasInvalid;

+ (id)sharedInstance
{
    static dispatch_once_t once;
    static MVMediaManager * instance = nil;
    dispatch_once(&once, ^{
        /*
        if ([MRDIAMABAGER_ENVIRONMENT isEqualToString:ENVIRONMENT_DEVELOPMENT])
            instance = [[MVMediaManagerCase alloc] init];
        else
         //*/
            instance = [[MVMediaManager alloc] init];
    });
    return instance;
}

- (void) dealloc {
    [[MVCameraClient sharedInstance] removeObserver:self];
}

- (instancetype) init {
    if (self = [super init])
    {
        [[MVCameraClient sharedInstance] addObserver:self];
        
        _dataSourceObservers = [[NSMutableArray alloc] init];
        _downloadStatusObservers = [[NSMutableArray alloc] init];
        
        _cameraMedias = [[NSMutableArray alloc] init];
        _localMedias = [[NSMutableArray alloc] init];
        
        _fileIteratingState = FileIteratingIdle;
        _fileIteratingCond = [[NSRecursiveCondition alloc] init];
        _remoteFilePaths = [[NSMutableArray alloc] init];
        _cameraMediasInvalid = YES;
        _localMediasInvalid = YES;
        
        _downloadTasks = [[NSMutableArray alloc] init];
        _hangingDownloadMedias = [[NSMutableArray alloc] init];
        _isDownloadingHanging = NO;
        
        _thumbnailCache = [[NSCache alloc] init];
        _thumbnailCache.name = @"ThumbnailCache";
        _thumbnailCache.totalCostLimit = 1048576 * 32;
        _thumbnailCache.delegate = self;
        
        _enqueDownloadQueue = dispatch_queue_create("EnqueueDownload", DISPATCH_QUEUE_SERIAL);
        _thummaryQueue = dispatch_queue_create("Thummary", DISPATCH_QUEUE_SERIAL);
        _imageRenderQueue = dispatch_queue_create("ImageRender", DISPATCH_QUEUE_SERIAL);
        
        _thummaryCond = [[NSRecursiveCondition alloc] init];
        _isBusyFetchingThummary = NO;
        
        _fetchingThummaryMedias = [[NSMutableDictionary alloc] init];
        _thummaryFetchedTime = [[NSMutableDictionary alloc] init];
        _justCreatedMediaTime = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) addMediaDataSourceObserver:(id<MVMediaDataSourceObserver>)observer {
    @synchronized (self)
    {
        [_dataSourceObservers addObject:observer];
    }
}

- (void) removeMediaDataSourceObserver:(id<MVMediaDataSourceObserver>)observer {
    @synchronized (self)
    {
        [_dataSourceObservers removeObject:observer];
    }
}

- (void) addMediaDownloadStatusObserver:(id<MVMediaDownloadStatusObserver>)observer {
//    @synchronized (self)
    {
        [_downloadStatusObservers addObject:observer];
    }
}

- (void) removeMediaDownloadStatusObserver:(id<MVMediaDownloadStatusObserver>)observer {
//    @synchronized (self)
    {
        [_downloadStatusObservers removeObject:observer];
    }
}

- (BOOL) isCameraMediaLibraryAvailable {
    return (nil != [MVCameraClient sharedInstance].connectingCamera);
}

- (void) addNewCameraMedia:(MVMedia *)media justCreated:(BOOL)justCreated {
    @synchronized (self)
    {
        if (![_cameraMedias containsObject:media])
        {
            [_cameraMedias insertObject:media atIndex:0];
            if (justCreated)
            {
                [_justCreatedMediaTime setObject:[NSDate date] forKey:media.storageKey];
            }
            //NSLog(@"ThummaryRequested : UpdateAll addNewCameraMedia : %@", media.storageKey);
            [self sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventAddNew arg2:0 object:_cameraMedias];
        }
    }
}

- (void) removeCameraMedia:(MVMedia*)media {
    @synchronized (self)
    {
        [_cameraMedias removeObject:media];
        //NSLog(@"ThummaryRequested : UpdateAll removeCameraMedia : %@", media.storageKey);
        [self sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventDeletes arg2:0 object:_cameraMedias];
    }
}

- (MVMedia*) obtainCameraMedia:(NSString *)cameraUUID remotePath:(NSString *)remotePath willRefreshCameraMediasSoon:(BOOL)willRefreshCameraMediasSoon {
    __block MVMedia* media;
    [[RealmSerialQueue shareRealmQueue] sync:^{
        NSArray<MVMedia* >* medias = [MVMedia querySavedMediasWithCameraUUID:cameraUUID remotePath:remotePath localPath:nil];
        if (!medias || 0 == medias.count)
        {
            media = [MVMedia createWithCameraUUID:cameraUUID remoteFullPath:remotePath];
            [media insert];
            NSLog(@"Download: obtainCameraMedia #0 : media(isFromDB=%d) = %@", media.isFromDB, media);
            
            if (!willRefreshCameraMediasSoon)
            {
                [self addNewCameraMedia:media justCreated:YES];
            }
        }
        else
        {
            media = medias[0];
            if (media.localPath && media.localPath.length > 0
                && (media.downloadedSize < media.size || 0 == media.size))
            {
                media.downloadStatus = MVMediaDownloadStatusStopped;
            }
            else
            {
                media.downloadStatus = MVMediaDownloadStatusNone;
            }
            
            if (!willRefreshCameraMediasSoon)
            {
                [self updateCameraMedia:media];
            }
        }
    }];
    NSLog(@"Download: obtainCameraMedia #1 : media(isFromDB=%d) = %@", media.isFromDB, media);
    return media;
}

- (NSArray<MVMedia* >*) obtainCameraMedias:(NSString *)cameraUUID remotePaths:(NSArray<NSString* >*)remotePaths willRefreshCameraMediasSoon:(BOOL)willRefreshCameraMediasSoon {
    NSMutableArray<MVMedia* >* ret = [[NSMutableArray alloc] init];
    NSMutableArray<MVMedia* >* mediasToInsert = [[NSMutableArray alloc] init];
    [[RealmSerialQueue shareRealmQueue] sync:^{
        NSDictionary<NSString*, MVMedia* >* savedMedias = [MVMedia querySavedMediasWithCameraUUID:cameraUUID];
        for (NSString* remotePath in remotePaths)
        {
            MVMedia* savedMedia = [savedMedias objectForKey:remotePath];
            if (!savedMedia)
            {
                savedMedia = [MVMedia createWithCameraUUID:cameraUUID remoteFullPath:remotePath];
                [mediasToInsert addObject:savedMedia];
                ///!!!NSLog(@"Download: obtainCameraMedias #0 : media(isFromDB=%d) = %@", savedMedia.isFromDB, savedMedia);
                
                if (!willRefreshCameraMediasSoon)
                {
                    [self addNewCameraMedia:savedMedia justCreated:NO];
                }
            }
            else
            {
                if (savedMedia.localPath && savedMedia.localPath.length > 0
                    && (savedMedia.downloadedSize < savedMedia.size || 0 == savedMedia.size))
                {
                    savedMedia.downloadStatus = MVMediaDownloadStatusStopped;
                }
                else
                {
                    savedMedia.downloadStatus = MVMediaDownloadStatusNone;
                }
                
                if (!willRefreshCameraMediasSoon)
                {
                    [self updateCameraMedia:savedMedia];
                }
            }
            [ret addObject:savedMedia];
        }
    }];
    [RLModel insert:mediasToInsert];
    
    return [NSArray arrayWithArray:ret];
}

- (MVMedia*) obtainCameraMediaInMedias:(NSDictionary<NSString*, MVMedia* >*)medias cameraUUID:(NSString*)cameraUUID remotePath:(NSString *)remotePath willRefreshCameraMediasSoon:(BOOL)willRefreshCameraMediasSoon {
    MVMedia* ret = nil;
    MVMedia* savedMedia = [medias objectForKey:remotePath];
    if (!savedMedia)
    {
        ret = [MVMedia createWithCameraUUID:cameraUUID remoteFullPath:remotePath];
        //*///!!!
        [ret insert];
        //*
        if (!willRefreshCameraMediasSoon)
        {
            [self addNewCameraMedia:ret justCreated:NO];
        }
        //*/
    }
    else
    {
        ret = savedMedia;
        if (ret.localPath && ret.localPath.length > 0
            && (ret.downloadedSize < ret.size || 0 == ret.size))
        {
            ret.downloadStatus = MVMediaDownloadStatusStopped;
        }
        else
        {
            ret.downloadStatus = MVMediaDownloadStatusNone;
        }
        
        if (!willRefreshCameraMediasSoon)
        {
            [self updateCameraMedia:ret];
        }
    }
    return ret;
}

- (BOOL) beginCameraFilesIterating:(NSString*)cameraUUID {
    DoctorLog(@"#FileIterator# beginCameraFilesIterating : Before lock. _fileIterator = %@", _fileIterator);
    [_fileIteratingCond lock];
    {DoctorLog(@"#FileIterator# beginCameraFilesIterating : After lock. _fileIterator = %@", _fileIterator);
        if (_fileIterator)
        {
            [_fileIteratingCond unlock];
            DoctorLog(@"#FileIterator# beginCameraFilesIterating : After unlock. _fileIterator = %@", _fileIterator);
            return NO;
        }
        
        [_remoteFilePaths removeAllObjects];
        [_cameraMedias removeAllObjects];
        
        _fileIterator = [PathTreeIterator beginFileTraverse:@"/tmp/SD0/DCIM/" delegate:self];
        __weak typeof(self) wSelf = self;
        _fileIterator.callback = ^BOOL(NSString* fullPath, BOOL isDirectory, BOOL hasMore) {
            __strong typeof(self) pSelf = wSelf;
            if (isDirectory)
                return NO;
            NSLog(@"#FileIterator# GotFile : %@, isDirectory = %d, hasMore = %d", fullPath, isDirectory, hasMore);
            if (fullPath)
            {
                [pSelf.remoteFilePaths addObject:fullPath];
            }
            
            if (!hasMore)
            {
                @synchronized (pSelf)
                {
                    NSArray* remoteFilePaths = (1 >= pSelf.remoteFilePaths.count) ? pSelf.remoteFilePaths : [pSelf.remoteFilePaths subarrayWithRange:NSMakeRange(1, pSelf.remoteFilePaths.count - 1)];
                    NSArray<MVMedia* >* medias = [pSelf obtainCameraMedias:cameraUUID remotePaths:remoteFilePaths willRefreshCameraMediasSoon:YES];
                    DoctorLog(@"#FileIterator# GotFile : Finally After obtainCameraMedias");
                    [pSelf.cameraMedias addObjectsFromArray:medias];
                    [pSelf sortMediasByCreateDate:pSelf.cameraMedias];
                    DoctorLog(@"#FileIterator# GotFile : Finally After sortMediasByCreateDate");
                    pSelf.cameraMediasInvalid = NO;
                }
                //NSLog(@"ThummaryRequested : UpdateAll cameraMedias : count=%ld", (long)_cameraMedias.count);
                [pSelf sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventRefresh arg2:0 object:pSelf.cameraMedias];
            }
            else if (1 == pSelf.remoteFilePaths.count)
            {// Give UI-level caller an opportunity to pause iterating:
                @synchronized (pSelf)
                {
                    DoctorLog(@"#FileIterator# GotFile :#0 Finally Before obtainCameraMedias");
                    NSArray<MVMedia* >* medias = [pSelf obtainCameraMedias:cameraUUID remotePaths:pSelf.remoteFilePaths willRefreshCameraMediasSoon:YES];
                    DoctorLog(@"#FileIterator# GotFile :#0 Finally After obtainCameraMedias");
                    [pSelf.cameraMedias addObjectsFromArray:medias];
                }
                [pSelf sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventRefresh arg2:0 object:pSelf.cameraMedias];
            }
            
            return NO;
        };
    }
    [_fileIteratingCond unlock];
    DoctorLog(@"#FileIterator# beginCameraFilesIterating : After unlock#1. _fileIterator = %@", _fileIterator);
    return YES;
}

- (BOOL) continueCameraFilesIterating {
    DoctorLog(@"#FileIterator# continueCameraFilesIterating : Before lock. _fileIteratingState = %d, _fileIterator = %@", _fileIteratingState, _fileIterator);
    [_fileIteratingCond lock];
    {DoctorLog(@"#FileIterator# continueCameraFilesIterating : After lock. _fileIteratingState = %d, _fileIterator = %@", _fileIteratingState, _fileIterator);
        if (FileIteratingBusy == _fileIteratingState || !_fileIterator)
        {
            [_fileIteratingCond unlock];
            DoctorLog(@"#FileIterator# continueCameraFilesIterating : After unlock#0. _fileIterator = %@", _fileIterator);
            return NO;
        }
        
        while (FileIteratingIdle != _fileIteratingState && FileIteratingPausing != _fileIteratingState)
        {DoctorLog(@"#FileIterator# continueCameraFilesIterating : Before wait");
            [_fileIteratingCond wait];
        }
        DoctorLog(@"#FileIterator# continueCameraFilesIterating : After wait#0. _fileIteratingState = %d", _fileIteratingState);
        /*
        if (FileIteratingPausing == _fileIteratingState)
        {
            _fileIteratingState = FileIteratingIdle;
            [_fileIteratingCond broadcast];
            [_fileIteratingCond unlock];
            return NO;
        }
        //*/
        _fileIteratingState = FileIteratingBusy;
    }
    [_fileIteratingCond unlock];
    DoctorLog(@"#FileIterator# continueCameraFilesIterating : After unlock#1. _fileIteratingState = %d, _fileIterator = %@", _fileIteratingState, _fileIterator);
    PathTreeIterator* iterator = _fileIterator;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (FileIteratingPausing != _fileIteratingState && iterator.hasNext)
        {
            [iterator next];
        }
        DoctorLog(@"#FileIterator# continueCameraFilesIterating : After while{}. _fileIteratingState = %d, iterator = %@, _fileIterator = %@", _fileIteratingState, iterator, _fileIterator);
        [_fileIteratingCond lock];
        {DoctorLog(@"#FileIterator# continueCameraFilesIterating : After {lock}");
            _fileIteratingState = FileIteratingIdle;
            if (!iterator.hasNext && iterator == _fileIterator)
            {
                _fileIterator = nil;
            }
            
            [_fileIteratingCond broadcast];
        }
        [_fileIteratingCond unlock];
        DoctorLog(@"#FileIterator# continueCameraFilesIterating : After {unlock}. _fileIteratingState=%d, _fileIterator=%@", _fileIteratingState, _fileIterator);
    });
    
    return YES;
}

- (BOOL) pauseCameraFilesIterating {
    BOOL succ = NO;
    DoctorLog(@"#FileIterator# pauseCameraFilesIterating : Before lock. _fileIteratingState=%d, _fileIterator=%@", _fileIteratingState, _fileIterator);
    [_fileIteratingCond lock];
    {DoctorLog(@"#FileIterator# pauseCameraFilesIterating : After lock");
        if (FileIteratingBusy == _fileIteratingState)
        {
            _fileIteratingState = FileIteratingPausing;
            succ = YES;
        }
    }
    [_fileIteratingCond unlock];
    DoctorLog(@"#FileIterator# pauseCameraFilesIterating : After unlock. _fileIteratingState=%d, _fileIterator=%@", _fileIteratingState, _fileIterator);
    return succ;
}

- (BOOL) stopCameraFilesIterating {
    DoctorLog(@"#FileIterator# stopCameraFilesIterating : #0. _fileIteratingState=%d, _fileIterator=%@", _fileIteratingState, _fileIterator);
    _fileIterator = nil;
    return [self pauseCameraFilesIterating];
}

- (NSArray<MVMedia*>*) cameraMedias:(BOOL)forceUpdate {
    if (![MVCameraClient sharedInstance].connectingCamera)
    {
        return nil;
    }
    
    @synchronized (self)
    {
        if (!_cameraMediasInvalid && !forceUpdate && _cameraMedias.count > 0)
        {
            return _cameraMedias;
        }
        else
        {
            NSString* cameraUUID = [MVCameraClient sharedInstance].connectingCamera.uuid;
            [self beginCameraFilesIterating:cameraUUID];
            [self continueCameraFilesIterating];
            
            return nil;
        }
    }
    
    return _cameraMedias;
}

- (void) pathTreeIteratorFetchContentsInFullPath:(NSString *)fullPath feedContentsBlock:(PathTreeIteratorFeedContentsBlock)feedContentsBlock callback:(PathTreeIteratorCallback)callback {
    AMBARequest* cdRequest = [[AMBARequest alloc] initWithReceiveBlock:^(AMBAResponse *response) {
        DoctorLog(@"#FileIterator# CD response : %d", response.isRvalOK);
        if (!response.isRvalOK)
        {
            if (feedContentsBlock)
            {
                feedContentsBlock(nil);
            }
            return;
        }
        
        AMBARequest* lsRequest = [[AMBARequest alloc] initWithReceiveBlock:^(AMBAResponse *response) {
            AMBAListResponse* lsResponse = (AMBAListResponse*) response;
            DoctorLog(@"#FileIterator# LS response : %d", lsResponse.isRvalOK);
            if (!lsResponse || !lsResponse.isRvalOK)
                return;
            
            NSMutableArray<NSString* >* filesList = [[NSMutableArray alloc] init];
            for (NSDictionary<NSString*, NSString* >* item in lsResponse.listing)
            {
                for (NSString* file in item.allKeys)
                {
                    [filesList addObject:file];
                }
            }
            [filesList sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                NSString* str1 = obj1;
                NSString* str2 = obj2;
                NSComparisonResult result = [str1 compare:str2 options:NSCaseInsensitiveSearch];
                switch (result)
                {
                    case NSOrderedSame:
                        return NSOrderedSame;
                    case NSOrderedAscending:
                        return NSOrderedDescending;
                    case NSOrderedDescending:
                        return NSOrderedAscending;
                }
            }];
            if (feedContentsBlock)
            {
                feedContentsBlock(filesList);
            }
        } errorBlock:^(AMBARequest *response, int error, NSString *msg) {
            DoctorLog(@"#FileIterator# LS ERROR");
            if (feedContentsBlock)
            {
                feedContentsBlock(nil);
            }
            /*///???
            if (callback)
            {
                callback(nil, NO, NO);
            }
            //*/
        } responseClass:AMBAListResponse.class];
        lsRequest.token = [MVCameraClient sharedInstance].sessionToken;
        lsRequest.msgID = AMBA_MSGID_LS;
        [[CMDConnectManager sharedInstance] sendRequest:lsRequest];
        DoctorLog(@"#FileIterator# Send LS");
    } errorBlock:^(AMBARequest *response, int error, NSString *msg) {
        DoctorLog(@"#FileIterator# CD ERROR");
        if (callback)
        {
            callback(nil, NO, NO);
        }
    }];
    cdRequest.token = [MVCameraClient sharedInstance].sessionToken;
    cdRequest.msgID = AMBA_MSGID_CD;
    cdRequest.param = fullPath;
    [[CMDConnectManager sharedInstance] sendRequest:cdRequest];
    DoctorLog(@"#FileIterator# Send CD");
}

- (BOOL) pathTreeIteratorIsDirectory:(NSString *)path file:(NSString *)file {
    NSString* fullPath = path ? [path stringByAppendingString:file] : file;
    if (fullPath && fullPath.length > 0)
    {
        return [fullPath hasSuffix:@PATH_SEPARATOR];
    }
    else
    {
        return NO;
    }
}

- (BOOL) pathTreeIteratorShouldPassFilter:(NSString *)fullPath isDirectory:(BOOL)isDirectory {
    if (!fullPath || 0 == fullPath.length) return NO;
    
    if (!isDirectory)
    {
        NSString* lowerFullPath = [fullPath lowercaseString];
        if (([lowerFullPath hasSuffix:@".mp4"] && ![lowerFullPath hasSuffix:@"ab.mp4"]) || [lowerFullPath hasSuffix:@".jpg"])
        {
            return ![[lowerFullPath lastPathComponent] hasPrefix:@"."];
        }
        else
        {
            return NO;
        }
    }
    else
    {
        NSString* lowerFullDir = [[fullPath substringToIndex:fullPath.length-1] lowercaseString];
        if ([lowerFullDir hasPrefix:@"/tmp/sd0/amba"] || [lowerFullDir hasPrefix:@"/tmp/sd0/dcim"] || [lowerFullDir hasPrefix:@"/tmp/sd0/mijia"] || [lowerFullDir hasPrefix:@"/tmp/sd0/madv"])
        {
            if ([lowerFullDir pathComponents].count < 6)
                return YES;
        }
        return NO;
    }
}

- (BOOL) pathTreeIteratorShouldStop {
    return NO;
}

- (void) pathTreeIteratorFinished:(BOOL)isStopped {
    
}

- (NSMutableArray<MVMedia*>*) sortMediasByCreateDate:(NSMutableArray<MVMedia*>*)medias {
    //[[RealmSerialQueue shareRealmQueue] sync:^{
        [medias sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            MVMedia* lhs = (MVMedia*) obj1;
            MVMedia* rhs = (MVMedia*) obj2;
            switch ([lhs.createDate compare:rhs.createDate])
            {
                case NSOrderedSame:
                    return NSOrderedSame;
                case NSOrderedAscending:
                    return NSOrderedDescending;
                default:
                    return NSOrderedAscending;
            }
        }];
    //}];
    return medias;
}

- (NSMutableArray<MVMedia*>*) sortMediasByModifyDate:(NSMutableArray<MVMedia*>*)medias {
    //[[RealmSerialQueue shareRealmQueue] sync:^{
        [medias sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            MVMedia* lhs = (MVMedia*) obj1;
            MVMedia* rhs = (MVMedia*) obj2;
            switch ([lhs.modifyDate compare:rhs.modifyDate])
            {
                case NSOrderedSame:
                    return NSOrderedSame;
                case NSOrderedAscending:
                    return NSOrderedDescending;
                default:
                    return NSOrderedAscending;
            }
        }];
    //}];
    return medias;
}

- (void) invalidateCameraMedias:(BOOL)refresh {
    @synchronized (self)
    {
        _cameraMediasInvalid = YES;
    }
    if (refresh)
    {
        [self cameraMediasAsync];
    }
}

- (NSArray<MVMedia*>*) localMedias:(BOOL)forceRefresh {
    @synchronized (self)
    {
        if (!_localMediasInvalid && !forceRefresh)
        {
            return _localMedias;
        }
        else
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self importPrestoredMedias];
                NSArray<MVMedia*>* list = [MVMedia queryDownloadedMedias];
                @synchronized (self)
                {
                    _localMedias = [list mutableCopy];
                   // [self sortMediasByModifyDate:_localMedias];
                    _localMediasInvalid = NO;
                }
                [self sendCallbackMessage:MsgDataSourceLocalUpdated arg1:DataSetEventRefresh arg2:0 object:_localMedias];
            });
            return nil;
        }
    }
}

- (void) invalidateLocalMedias:(BOOL)refresh {
    @synchronized (self)
    {
        _localMediasInvalid = YES;
    }
    if (refresh)
    {
        [self localMedias];
    }
}

#pragma mark    NSCacheDelegate

- (NSString*) externalThumbnailCacheDirectory {
    NSString* cacheDirectoryPath = [z_Sandbox documentPath:@"cache/thumbs"];
    BOOL isPathDirectory;
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:cacheDirectoryPath isDirectory:&isPathDirectory])
    {
        if (!isPathDirectory)
        {
            [fm removeItemAtPath:cacheDirectoryPath error:nil];
            [fm createDirectoryAtPath:cacheDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    else
    {
        [fm createDirectoryAtPath:cacheDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return cacheDirectoryPath;
}

- (void) cache:(NSCache *)cache willEvictObject:(id)obj {
    ThumbnailCacheItem* cacheItem = (ThumbnailCacheItem*) obj;
    if (!cacheItem) return;
    
    NSString* thumbnailPath = [self.externalThumbnailCacheDirectory stringByAppendingPathComponent:cacheItem.key];
    if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
    {
        NSData* pngData = UIImagePNGRepresentation(cacheItem.thumbnail);
        [pngData writeToFile:thumbnailPath atomically:NO];
    }
}

- (void) saveMediaThumbnail:(MVMedia*)media thumbnail:(UIImage*)thumbnail {
    ThumbnailCacheItem* cacheItem = [[ThumbnailCacheItem alloc] initWithKey:media.storageKey thumbnail:thumbnail];
    [_thumbnailCache setObject:cacheItem forKey:media.storageKey];
    
    NSString* thumbnailPath = [self.externalThumbnailCacheDirectory stringByAppendingPathComponent:cacheItem.key];
    ///!!!if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
    {
        NSData* pngData = UIImagePNGRepresentation(cacheItem.thumbnail);
        [pngData writeToFile:thumbnailPath atomically:NO];
    }
    
    [media transactionWithBlock:^{
        media.thumbnailImagePath = cacheItem.key;
    }];
    [media saveCommonFields];
    if ([[MVCameraClient sharedInstance] connectingCamera]) {
        [self updateCameraMedia:media];
    }
    [self invalidateLocalMedias:NO];
}

UIImage* getVideoImage(NSString* videoURL)
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoURL] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return thumb;
}

#define MIN_THUMMARY_FETCH_INTERVAL_MILLS 5000

- (BOOL) getMediaThummaryAsync:(MVMedia*)mediaToFetch {
    if (!mediaToFetch) return NO;

    NSString* mediaKey = mediaToFetch.storageKey;
    @synchronized (_thummaryFetchedTime)
    {
        long long nowTimeMills = [[NSDate date] timeIntervalSince1970] * 1000;
        NSNumber* lastFetchedTimeMillsNumber = [_thummaryFetchedTime objectForKey:mediaKey];
        if (lastFetchedTimeMillsNumber)
        {
            long long lastFetchedTimeMills = [lastFetchedTimeMillsNumber longLongValue];
            if (0 > lastFetchedTimeMills)
            {
                //NSLog(@"ThummaryRequested : Media already being fetched : %@", mediaKey);
                return NO;
            }
            else if (nowTimeMills - lastFetchedTimeMills < MIN_THUMMARY_FETCH_INTERVAL_MILLS)
            {
                //NSLog(@"ThummaryRequested : Too frequently fetching thummary : %@, now=%lld, lastFetchedTime=%lld", mediaKey, nowTimeMills, lastFetchedTimeMills);
                return NO;
            }
            else
            {
                //NSLog(@"ThummaryRequested : Thummary fetching request after CD time : %@", mediaKey);
                [_thummaryFetchedTime setObject:@(-1) forKey:mediaKey];
                [_fetchingThummaryMedias setObject:mediaToFetch forKey:mediaKey];
            }
        }
        else
        {
            //NSLog(@"ThummaryRequested : First time fetching thummary of media : %@", mediaKey);
            [_thummaryFetchedTime setObject:@(-1) forKey:mediaKey];
            [_fetchingThummaryMedias setObject:mediaToFetch forKey:mediaKey];
        }
    }
    
    void(^procedureBlock)(void) = ^{
        _isBusyFetchingThummary = YES;
        
        MVMedia* theMedia = nil;
        @synchronized (_thummaryFetchedTime)
        {
            //theMedia = [[_fetchingThummaryMedias allValues] firstObject];
            theMedia = [_fetchingThummaryMedias objectForKey:mediaKey];///!!!
            if (!theMedia)
            {
                //NSLog(@"ThummaryRequested : getMediaThummaryAsync : No thummaryTask, return. %@", mediaKey);
                return;
            }
        }
        //NSLog(@"ThummaryRequested : Begin to fetch thummary : %@", mediaKey);
        void(^thumbnailCompletion)() = ^() {
            NSLog(@"#ThummaryRequested# getMediaThummaryAsync >> thumbnailCompletion : %@", mediaKey);
            [_thummaryCond lock];
            {
                _isBusyFetchingThummary = NO;
                [_thummaryCond broadcast];
            }
            [_thummaryCond unlock];
        };
        
        void(^getThumbnailBlock)(MVMedia*) = ^(MVMedia* m) {
            NSLog(@"#ThummaryRequested# getMediaThummaryAsync >> getThumbnailBlock Begin : %@, media=%@", mediaKey, m);
            //*
            ThumbnailDownloadCallback* callback = [[ThumbnailDownloadCallback alloc] initWithCompletedBlock:^(Byte *data, int bytesReceived, BOOL isNotStitched, MVDownloadTask* downloadTask) {
                //NSLog(@"ThummaryRequested : getThumbnailBlock : Callback @ %@, bytesReceived=%d", mediaKey, bytesReceived);
                NSString* thumbnailPath = [self.externalThumbnailCacheDirectory stringByAppendingPathComponent:m.storageKey];
                NSData* thumbData = [NSData dataWithBytes:data length:bytesReceived];
                dispatch_async(_imageRenderQueue, ^{
                    @autoreleasepool //#1
                    {
                        UIImage* thumbnailBitmap;
                        float gyroMatrix[9];
                        copyGyroMatrixFromString(gyroMatrix, m.gyroMatrixString.UTF8String);
                        if (MVMediaTypeVideo == m.mediaType)
                        {
                            NSString* idrFilePath = [thumbnailPath stringByAppendingPathExtension:@"idr"];
                            [thumbData writeToFile:idrFilePath atomically:YES];
                            thumbnailBitmap = MadvGLRenderer_iOS::renderImageWithIDR(idrFilePath, CGSizeMake(ThumbnailWidth, ThumbnailHeight), YES, nil, 0, gyroMatrix, 3);
                        }
                        else
                        {
                            UIImage* originalImage = [UIImage imageWithData:thumbData];
                            thumbnailBitmap = MadvGLRenderer_iOS::renderImage(originalImage, CGSizeMake(ThumbnailWidth, ThumbnailHeight), !m.isStitched, nil, (int)m.filterID, gyroMatrix, 3);
                        }
                        
                        [self saveMediaThumbnail:m thumbnail:thumbnailBitmap];
                        [self sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:m];
                    }
                });
                thumbnailCompletion();
            } errorBlock:^(NSString *errMsg, MVDownloadTask* downloadTask) {
                //NSLog(@"ThummaryRequested : getThumbnailBlock : Error @ %@, errMsg=%@", mediaKey, errMsg);
                //[self removeCameraMedia:m];
                [self sendCallbackMessage:MsgThumbnailFetched arg1:-1 arg2:0 object:m];
                thumbnailCompletion();
            }];
            ThumbnailDownloadTask* task = [[ThumbnailDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityHigh remotePath:m.remotePath isVideo:(MVMediaTypeVideo == m.mediaType) callback:callback];
            [[MVCameraDownloadManager sharedInstance] addTask:task addAsFirst:YES];
            /*/
             thumbnailCompletion();
             //*/
        };
        
        if (theMedia.size <= 0)
        {// Get MediaInfo asynchronously:
            __block MVMedia* blkMedia = theMedia;
            //NSLog(@"ThummaryRequested : getMediaThummaryAsync : No MediaInfo @ %@, media=%@", mediaKey, blkMedia);
            AMBARequest* getMediaInfoRequest = [[AMBARequest alloc] initWithReceiveBlock:^(AMBAResponse *response) {
                NSLog(@"#ThummaryRequested# getMediaThummaryAsync >> getMediaInfoRequest callback : %@, response=%@", mediaKey, response);
                if (response.isRvalOK)
                {
                    AMBAGetMediaInfoResponse* getMediaInfoResponse = (AMBAGetMediaInfoResponse*) response;
                    NSLog(@"MVMediaManager $ getMediaThummaryAsync # getMediaInfoResponse.duration = %d, .mediaType = %@, blkMedia = %@", getMediaInfoResponse.duration, getMediaInfoResponse.media_type, blkMedia);
                    [blkMedia transactionWithBlock:^{
                        if (getMediaInfoResponse.duration > 0)
                            blkMedia.videoDuration = getMediaInfoResponse.duration;
                        if (getMediaInfoResponse.size > 0)
                        {
                            ///!!!For Debug
                            if (getMediaInfoResponse.size < 1048576)
                            {
                                DoctorLog(@"#MVMediaWrongSize# getMediaThummaryAsync : getMediaInfoResponse.size = %ld", (long)getMediaInfoResponse.size);
                            }
                            blkMedia.size = getMediaInfoResponse.size;
                        }
                        blkMedia.isStitched = (getMediaInfoResponse.scene_type == StitchTypeStitched);
                        blkMedia.gyroMatrixString = getMediaInfoResponse.gyro;
                    }];
                    [blkMedia saveCommonFields];
                    
                    [self updateCameraMedia:blkMedia];
                    [self invalidateLocalMedias:NO];
                    [self sendCallbackMessage:MsgMediaInfoFetched arg1:0 arg2:0 object:blkMedia];
                    
                    getThumbnailBlock(blkMedia);
                }
                else
                {
                    //[self removeCameraMedia:blkMedia];
                    [self sendCallbackMessage:MsgMediaInfoFetched arg1:response.rval arg2:0 object:blkMedia];
                    thumbnailCompletion();
                }
                
            } errorBlock:^(AMBARequest *response, int error, NSString *msg) {
                NSLog(@"#ThummaryRequested# getMediaThummaryAsync >> getMediaInfoRequest error : %@, response=%@, error=%d, msg=%@", mediaKey, response, error, msg);
                [self sendCallbackMessage:MsgMediaInfoFetched arg1:error arg2:0 object:blkMedia];
                thumbnailCompletion();
            } responseClass:AMBAGetMediaInfoResponse.class];
            getMediaInfoRequest.msgID = AMBA_MSGID_GET_MEDIA_INFO;
            getMediaInfoRequest.token = [MVCameraClient sharedInstance].sessionToken;
            getMediaInfoRequest.param = theMedia.remotePath;
            [[CMDConnectManager sharedInstance] sendRequest:getMediaInfoRequest];
        }
        else
        {
            getThumbnailBlock(theMedia);
        }
        
        // Should not return before MediaInfo&Thumbnail are all fetched(or failure):
        [_thummaryCond lock];
        {
            while (_isBusyFetchingThummary)
            {
                [_thummaryCond wait];
            }
        }
        [_thummaryCond unlock];
        
        long long nowTimeMills = [[NSDate date] timeIntervalSince1970] * 1000;
        @synchronized (_thummaryFetchedTime)
        {
            [_thummaryFetchedTime setObject:@(nowTimeMills) forKey:theMedia.storageKey];
            [_fetchingThummaryMedias removeObjectForKey:theMedia.storageKey];
        }
    };
    
    if ([_justCreatedMediaTime objectForKey:mediaKey])
    {
        [_justCreatedMediaTime removeObjectForKey:mediaKey];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1L * NSEC_PER_SEC), _thummaryQueue, procedureBlock);
    }
    else
    {
        dispatch_async(_thummaryQueue, procedureBlock);
    }
    
    return YES;
}

- (UIImage*) getThumbnailImage:(MVMedia*)media {
    NSArray<MVMedia*>* savedMedias = [MVMedia querySavedMediasWithCameraUUID:media.cameraUUID remotePath:media.remotePath localPath:media.localPath];
    if (savedMedias && 0 < savedMedias.count)
    {
        MVMedia* savedMedia = [savedMedias lastObject];
        NSString* thumbnailPath = [self.externalThumbnailCacheDirectory stringByAppendingPathComponent:[savedMedia storageKey]];
        if (thumbnailPath && thumbnailPath.length > 0)
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
            {
                return [UIImage imageWithContentsOfFile:thumbnailPath];
            }
            else
            {
                NSString* localPath = [z_Sandbox documentPath:savedMedia.localPath];
                BOOL isDirectory = NO;
                BOOL isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory];
                if (isFileExists && !isDirectory && savedMedia.downloadedSize >= savedMedia.size && savedMedia.size > 0)
                {
                    dispatch_async(_imageRenderQueue, ^{
                        @autoreleasepool //#2
                        {
                            UIImage* thumbnailImage = nil;
                            UIImage* originalImage = nil;
                            if (savedMedia.mediaType == MVMediaTypeVideo)
                            {
                                originalImage = getVideoImage(localPath);
                                
                                if (originalImage)
                                {
                                    thumbnailImage = MadvGLRenderer_iOS::renderImage(originalImage, CGSizeMake(ThumbnailWidth, ThumbnailHeight), YES, localPath, 0, NULL, 0);
                                }
                            }
                            else
                            {
                                thumbnailImage = MadvGLRenderer_iOS::renderJPEG(localPath.UTF8String, CGSizeMake(ThumbnailWidth, ThumbnailHeight), NO, localPath, NO, 0, NULL, 0);
                            }
                            UIImage* finalThumbnail = (thumbnailImage ? : originalImage);
                            if (finalThumbnail)
                            {
                                [self saveMediaThumbnail:media thumbnail:finalThumbnail];
                                [self sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];
                                [self updateLocalMedia:media];
                            }
                        }
                    });
                    
                    return nil;
                }
            }
        }
    }
    
    [self getMediaThummaryAsync:media];
    return nil;
}

- (NSString*) getThumbnailLocalPath:(MVMedia *)media {
    NSArray<MVMedia*>* savedMedias = [MVMedia querySavedMediasWithCameraUUID:media.cameraUUID remotePath:media.remotePath localPath:media.localPath];
    if (savedMedias && 0 < savedMedias.count)
    {
        MVMedia* savedMedia = [savedMedias lastObject];
        NSString* thumbnailPath = [self.externalThumbnailCacheDirectory stringByAppendingPathComponent:[savedMedia storageKey]];
        if (thumbnailPath && thumbnailPath.length > 0)
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
            {
                return thumbnailPath;
            }
            else
            {
                NSString* localPath = [z_Sandbox documentPath:savedMedia.localPath];
                BOOL isDirectory = NO;
                BOOL isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory];
                if (isFileExists && !isDirectory && savedMedia.downloadedSize >= savedMedia.size && savedMedia.size > 0)
                {
                    dispatch_async(_imageRenderQueue, ^{
                        @autoreleasepool //#3
                        {
                            UIImage* originalImage = nil;
                            if (savedMedia.mediaType == MVMediaTypeVideo)
                            {
                                originalImage = getVideoImage(localPath);
                                if (originalImage)
                                {
                                    UIImage* thumbnailImage = MadvGLRenderer_iOS::renderImage(originalImage, CGSizeMake(ThumbnailWidth, ThumbnailHeight), YES, localPath, 0, NULL, 0);
                                    [self saveMediaThumbnail:media thumbnail:thumbnailImage];
                                    [self sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];
                                }
                            }
                            else
                            {
                                UIImage* thumbnailImage = MadvGLRenderer_iOS::renderJPEG(localPath.UTF8String, CGSizeMake(ThumbnailWidth, ThumbnailHeight), NO, localPath, NO, 0, NULL, 0);
                                [self saveMediaThumbnail:media thumbnail:thumbnailImage];
                                [self sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];
                            }
                        }
                    });
                    
                    return nil;
                }
            }
        }
    }
    
    [self getMediaThummaryAsync:media];
    return nil;
}

- (BOOL) getMediaInfo:(MVMedia *)media {
    //*
    if (!media)
        return NO;
    if (media.size > 0)
        return YES;
    
    [self getMediaThummaryAsync:media];
    return NO;
}

- (MediaThummaryResult*) getMediaThummary:(MVMedia *)media {
    MediaThummaryResult* result = [[MediaThummaryResult alloc] init];
    result.thumbnailPath = nil;
    result.thumbnail = nil;
    result.isMediaInfoAvailable = NO;
    if (!media) return result;
    
    // getThumbnailImage & getThumbnailLocalPath:
    NSArray<MVMedia*>* savedMedias = [MVMedia querySavedMediasWithCameraUUID:media.cameraUUID remotePath:media.remotePath localPath:media.localPath];
    if (savedMedias && 0 < savedMedias.count)
    {
        MVMedia* savedMedia = [savedMedias lastObject];
        NSString* thumbnailPath = [self.externalThumbnailCacheDirectory stringByAppendingPathComponent:[savedMedia storageKey]];
        if (thumbnailPath && thumbnailPath.length > 0)
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
            {
                result.thumbnail = [UIImage imageWithContentsOfFile:thumbnailPath];
                result.thumbnailPath = thumbnailPath;
            }
            else if (savedMedia.localPath && savedMedia.localPath.length > 0)
            {
                NSString* localPath = [z_Sandbox documentPath:savedMedia.localPath];
                BOOL isDirectory = NO;
                BOOL isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory];
                if (isFileExists && !isDirectory && savedMedia.downloadedSize >= savedMedia.size && savedMedia.size > 0)
                {
                    dispatch_async(_imageRenderQueue, ^{
                        @autoreleasepool //#0
                        {
                            UIImage* thumbnailImage = nil;
                            UIImage* originalImage = nil;
                            if (savedMedia.mediaType == MVMediaTypeVideo)
                            {
                                originalImage = getVideoImage(localPath);
                                if (originalImage)
                                {
                                    thumbnailImage = MadvGLRenderer_iOS::renderImage(originalImage, CGSizeMake(ThumbnailWidth, ThumbnailHeight), YES, localPath, 0, NULL, 0);
                                }
                            }
                            else
                            {
                                thumbnailImage = MadvGLRenderer_iOS::renderJPEG(localPath.UTF8String, CGSizeMake(ThumbnailWidth, ThumbnailHeight), NO, localPath, NO, 0, NULL, 0);
                            }
                            UIImage* finalThumbnail = (thumbnailImage ? : originalImage);
                            if (finalThumbnail)
                            {
                                [self saveMediaThumbnail:media thumbnail:finalThumbnail];
                                [self sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];///!!!
                                [self updateLocalMedia:media];///!!!
                                
                                result.thumbnail = finalThumbnail;
                                result.thumbnailPath = thumbnailPath;
                            }else
                            {
                                [self saveMediaThumbnail:media thumbnail:finalThumbnail];
                                [self sendCallbackMessage:MsgThumbnailFetched arg1:-1 arg2:0 object:media];///!!!
                                [self updateLocalMedia:media];///!!!
                                
                                result.thumbnail = finalThumbnail;
                                result.thumbnailPath = thumbnailPath;
                            }
                        }
                    });
                    
                    return result;
                }
            }
        }
    }
    // getMediaInfo:
    if (media.size > 0)
    {
        result.isMediaInfoAvailable = YES;
    }
    
    if (!result.thumbnail || !result.thumbnailPath || !result.isMediaInfoAvailable)
    {
        [self getMediaThummaryAsync:media];
    }
    
    return result;
}

- (void) deleteCameraMedias:(NSArray *)medias progressBlock:(void(^)(MVMedia* currentDeletedMedia, int deletedCount, int totalCount, BOOL* stop))progressBlock {
    if (!medias || medias.count == 0) return;
    
    NSMutableArray<MVMedia* >* mediasToDelete = [medias mutableCopy];
    NSMutableArray<MVMedia* >* mediasDeleted = [[NSMutableArray alloc] init];
    
    AMBARequest* delFileRequest = [[AMBARequest alloc] initWithReceiveBlock:nil errorBlock:nil];
    __weak AMBARequest* wDelFileRequest = delFileRequest;
    __block MVMedia* mediaToDelete = nil;
    __block BOOL stop = NO;
    void(^handleNextBlock)() = ^() {
        if (mediaToDelete)
        {
            [mediasToDelete removeObject:mediaToDelete];
            
            if (progressBlock)
            {
                progressBlock(mediaToDelete, (int)mediasDeleted.count, (int)medias.count, &stop);
            }
        }
        
        if (mediasToDelete.count > 0 && !stop)
        {
            __strong AMBARequest* pDelFileRequest = wDelFileRequest;
            mediaToDelete = [mediasToDelete lastObject];
            pDelFileRequest.msgID = AMBA_MSGID_DELETE_FILE;
            pDelFileRequest.token = [MVCameraClient sharedInstance].sessionToken;
            pDelFileRequest.param = mediaToDelete.remotePath;
            [[CMDConnectManager sharedInstance] sendRequest:pDelFileRequest];
        }
        else
        {
            @synchronized (self)
            {
                NSMutableArray<MVMedia* >* mediasToRemove = [[NSMutableArray alloc] init];
                for (MVMedia* mediaToRemove in mediasDeleted)
                {
                    NSEnumerator<MVMedia* >* enumerator = _cameraMedias.objectEnumerator;
                    for (MVMedia* media in enumerator)
                    {
                        if ([mediaToRemove isEqualRemoteMedia:media])
                        {
                            [mediasToRemove addObject:media];
                        }
                    }
                }
                
                for (MVMedia* mediaToRemove in mediasToRemove)
                {
                    [_cameraMedias removeObject:mediaToRemove];
                }
                _cameraMediasInvalid = NO;
            }
            
            MVCameraDevice* camera = [MVCameraClient sharedInstance].connectingCamera;
            if (_cameraMedias.count > 0)
            {
                if (camera)
                {
                    camera.recentMedia = _cameraMedias[0];
                }
            }
            else
            {
                camera.recentMedia = nil;
            }
            
            [[MVCameraClient sharedInstance] synchronizeCameraStorageAllState];
            
            if (mediasDeleted.count < medias.count)
            {
                //NSLog(@"ThummaryRequested : UpdateAll deleteCameraMedias #1 : Send MsgDataSourceCameraUpdated, count=%ld", (long)_cameraMedias.count);
                [self sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventDeletes arg2:MVMediaManagerErrorNotAllDeleted object:_cameraMedias];
            }
            else
            {
                //NSLog(@"ThummaryRequested : UpdateAll deleteCameraMedias #2 : Send MsgDataSourceCameraUpdated, count=%ld", (long)_cameraMedias.count);
                [self sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventDeletes arg2:0 object:_cameraMedias];
            }
            
            for (MVMedia* mediaToRemove in mediasDeleted)
            {
                NSArray<MVMedia*>* savedMedias = [MVMedia querySavedMediasWithCameraUUID:mediaToRemove.cameraUUID remotePath:mediaToRemove.remotePath localPath:mediaToRemove.localPath];
                for (MVMedia* savedMedia in savedMedias)
                {
                    if (savedMedia.size <= 0 || savedMedia.downloadedSize < savedMedia.size)
                    {
                        if (savedMedia.localPath && savedMedia.localPath.length > 0)
                        {
                            [[NSFileManager defaultManager] removeItemAtPath:[z_Sandbox documentPath:savedMedia.localPath] error:nil];
                        }
                        [savedMedia remove];
                    }
                }
            }
            
            if (progressBlock)
            {
                progressBlock(mediaToDelete, (int)mediasDeleted.count, (int)mediasDeleted.count, &stop);
            }
        }
    };
    
    void(^deleteABFileOrNextBlock)() = ^() {
        if (mediaToDelete && [mediaToDelete.remotePath hasSuffix:@"AA.MP4"])
        {
            NSString* abFilePath = [[mediaToDelete.remotePath substringToIndex:(mediaToDelete.remotePath.length - @"AA.MP4".length)] stringByAppendingString:@"AB.MP4"];
            AMBARequest* delABFileRequest = [[AMBARequest alloc] initWithReceiveBlock:^(AMBAResponse *response) {
                AMBARequest* pDelFileRequest = delFileRequest;///In order to retain the request
                handleNextBlock();
                pDelFileRequest = nil;
            } errorBlock:^(AMBARequest *response, int error, NSString *msg) {
                AMBARequest* pDelFileRequest = delFileRequest;///In order to retain the request
                handleNextBlock();
                pDelFileRequest = nil;
            }];
            delABFileRequest.msgID = AMBA_MSGID_DELETE_FILE;
            delABFileRequest.token = [MVCameraClient sharedInstance].sessionToken;
            delABFileRequest.param = abFilePath;
            [[CMDConnectManager sharedInstance] sendRequest:delABFileRequest];
        }
        else
        {
            handleNextBlock();
        }
    };
    
    delFileRequest.ambaResponseReceived = ^(AMBAResponse *response) {
        if (mediaToDelete)
        {
            if (response && response.isRvalOK)
            {
                [mediasDeleted addObject:mediaToDelete];
            }
        }
        
        deleteABFileOrNextBlock();
    };
    delFileRequest.ambaResponseError = ^(AMBARequest *response, int error, NSString *msg) {
        deleteABFileOrNextBlock();
    };
    
    handleNextBlock();
}

- (void) deleteLocalMedias:(NSArray *)medias {
    NSMutableArray<MVMedia* >* cameraMediasToReplace = [[NSMutableArray alloc] init];
    //RLMRealm* realm = [RLMRealm defaultRealm];
    for (MVMedia* m in medias)
    {
        NSFileManager* fm = [NSFileManager defaultManager];
        MVMedia* media = [MVMedia querySavedMediaWithCameraUUID:m.cameraUUID remotePath:m.remotePath localPath:m.localPath];
        [fm removeItemAtPath:[z_Sandbox documentPath:media.localPath] error:nil];
        
        if ([media.localPath hasSuffix:@"AA.MP4"])
        {
            NSString* abFilePath = [[media.remotePath substringToIndex:(media.remotePath.length - @"AA.MP4".length)] stringByAppendingString:@"AB.MP4"];
            [fm removeItemAtPath:[z_Sandbox documentPath:abFilePath] error:nil];
            
            NSString* gyroFilePath = [[media.remotePath substringToIndex:(media.remotePath.length - @".MP4".length)] stringByAppendingString:@".gyro"];
            [fm removeItemAtPath:[z_Sandbox documentPath:gyroFilePath] error:nil];
        }
        
        if (media.remotePath && media.remotePath.length > 0)
        {
            NSArray<MVMedia* >* savedMedias = [MVMedia querySavedMediasWithCameraUUID:media.cameraUUID remotePath:media.remotePath localPath:media.localPath];
            NSLog(@"deleteLocalMedias : savedMedias = %@", savedMedias);
            if (savedMedias && 1 == savedMedias.count)
            {
                //NSLog(@"#Bug3040# localPath=Empty #0 @ %@", media);
                [media transactionWithBlock:^{
                    media.localPath = @"";
                    media.downloadedSize = 0;
                }];
                [cameraMediasToReplace addObject:media];
            }
            else
            {
                MVMedia* tmp = [MVMedia createWithCameraUUID:media.cameraUUID remoteFullPath:media.remotePath];
                NSLog(@"deleteLocalMedias : Abount to remove : %@", [media localPath]);
                [media remove];
                
                NSArray<MVMedia* >* restMedias = [MVMedia querySavedMediasWithCameraUUID:tmp.cameraUUID remotePath:tmp.remotePath localPath:tmp.localPath];
                if (restMedias && restMedias.count > 0)
                {
                    NSLog(@"deleteLocalMedias : restMedias = %@", restMedias);
                    MVMedia* mediaToReplace = [restMedias lastObject];
                    NSLog(@"deleteLocalMedias : mediaToReplace : %@", [mediaToReplace localPath]);
                    [cameraMediasToReplace addObject:mediaToReplace];
                }
            }
        }
        else
        {
            [media remove];
        }
    }
    [self invalidateLocalMedias:YES];
    
    if (0 < cameraMediasToReplace.count)
    {
        [self updateCameraMedias:cameraMediasToReplace];
    }
}

- (void) setMediaDownloadStatus:(int)newStatus ofMedia:(MVMedia*)media errorCode:(int)errorCode {
    if (!media) return;
    @synchronized (media)
    {
        if (newStatus == media.downloadStatus)
            return;
        
        media.downloadStatus = (MVMediaDownloadStatus) newStatus;
        NSLog(@"#DownloadStatus# setMediaDownloadStatus:ofMedia:errorCode: newStatus=%d, @ %@", newStatus, media);
        [self sendCallbackMessage:MsgDownloadStatusChanged arg1:newStatus arg2:errorCode object:media];
    }
}

- (void) setMediaDownloadStatus:(int)newStatus ofMedias:(NSArray<MVMedia* >*)medias completion:(dispatch_block_t)completion {
    if (!medias) return;
    for (MVMedia* media in medias)
    {
        media.downloadStatus = (MVMediaDownloadStatus) newStatus;;
    }
    NSLog(@"#DownloadStatus# setMediaDownloadStatus:ofMedias: newStatus=%d, @ {%@}", newStatus, medias);
    [self sendCallbackMessage:MsgDownloadStatusChanged arg1:newStatus arg2:0 object1:medias object2:completion];
}

- (void) updateLocalMedia:(MVMedia*)media {
    NSArray<MVMedia* >* mediasToReplace = [NSArray arrayWithObjects:media, nil];
    [self updateLocalMedias:mediasToReplace];
}

- (void) updateLocalMedias:(NSArray<MVMedia*>*)mediasToReplace {
    [self sendCallbackMessage:MsgDataSourceLocalUpdated arg1:DataSetEventReplace arg2:0 object:mediasToReplace];
}

- (void) updateCameraMedia:(MVMedia*)media {
    NSArray<MVMedia* >* mediasToReplace = [NSArray arrayWithObjects:media, nil];
    [self updateCameraMedias:mediasToReplace];
}

- (void) updateCameraMedias:(NSArray<MVMedia*>*)mediasToReplace {
    @synchronized (self)
    {
        if (_cameraMedias && mediasToReplace)
        {
            for (NSInteger i=0; i<_cameraMedias.count; ++i)
            {
                MVMedia* prevMedia = _cameraMedias[i];
                for (MVMedia* media in mediasToReplace)
                {
                    if ([prevMedia isEqualRemoteMedia:media])
                    {
                        NSLog(@"updateCameraMedias : prevMedia=%@, mediaToReplace=%@", prevMedia, media);
                        [_cameraMedias replaceObjectAtIndex:i withObject:media];
                        break;
                    }
                }
            }
            //NSLog(@"ThummaryRequested : UpdateAll updateCameraMedias : mediasToReplace.count=%ld", (long)mediasToReplace.count);
            [self sendCallbackMessage:MsgDataSourceCameraUpdated arg1:DataSetEventReplace arg2:0 object:mediasToReplace];
        }
    }
}

- (void) notifyNoDiskSpace {
    static NSDate* s_lastNotifyTime = nil;
    NSDate* now = [NSDate date];
    if (!s_lastNotifyTime || [now timeIntervalSinceDate:s_lastNotifyTime] > 10.f)
    {
        s_lastNotifyTime = now;
        [self sendCallbackMessage:MsgLowDiskSpace arg1:0 arg2:0 object:nil];
    }
}

- (BOOL) addDownloading:(MVMedia *)media {
    if (_isDownloadingHanging)
    {
        [self sendCallbackMessage:MsgDownloadingsHung arg1:0 arg2:0 object:nil];
    }
    
    NSInteger freeDiskSpace = [self.class freeDiskSpace];
    if (media.size > 0 && media.size - media.downloadedSize >= freeDiskSpace)
    {
        [self notifyNoDiskSpace];
    }
    return [self addDownloading:media initChunkSize:DownloadInitChunkSize normalChunkSize:DownloadChunkSize addAsFirst:NO];
}

- (void) addDownloadingOfMedias:(NSArray<MVMedia* >*)medias completion:(dispatch_block_t)completion progressBlock:(ProgressiveActionBlock)progressBlock {
    if (_isDownloadingHanging)
    {
        [self sendCallbackMessage:MsgDownloadingsHung arg1:0 arg2:0 object:nil];
    }
    
    NSInteger freeDiskSpace = [self.class freeDiskSpace];
    NSUInteger totalSize = 0;
    for (MVMedia* m in medias)
    {
        if (m.size >= 0 && m.downloadedSize >= 0)
        {
            totalSize += (m.size - m.downloadedSize);
        }
    }
    if (totalSize >= freeDiskSpace)
    {
        [self notifyNoDiskSpace];
    }
    
    [self addDownloadingOfMedias:medias initChunkSize:DownloadInitChunkSize normalChunkSize:DownloadChunkSize addAsFirst:NO completion:completion progressBlock:progressBlock];
}

- (void)importMedias:(NSArray<MVMedia *> *)medias isVideo:(BOOL)isVideo
{
    for(MVMedia * media in medias)
    {
        [media insert];
    }
    [self invalidateLocalMedias:YES];
    
}

- (void) importPrestoredMedias {
    BOOL shouldInvalidateLocalMediasLater = NO;
    NSDirectoryEnumerator<NSString* >* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[z_Sandbox docPath]];
    for (NSString* originalFile in enumerator)
    {
        if (originalFile.pathComponents.count > 1)
            continue;
        
        NSString* ext = originalFile.pathExtension.lowercaseString;
        BOOL isVideo = [ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"];
        BOOL isImage = [ext isEqualToString:@"jpg"];
        if (!isVideo && !isImage) continue;
        
        // If is pre-stitch picture:
        NSString* cameraUUID = MadvGLRenderer_iOS::cameraUUIDOfPreStitchFileName(originalFile);
        if (cameraUUID)
        {
            NSString* localPath = MadvGLRenderer_iOS::stitchedPictureFileName(originalFile);
            MVMedia* media = [MVMedia querySavedMediaWithCameraUUID:cameraUUID remotePath:nil localPath:localPath];
            if (media)
            {
                shouldInvalidateLocalMediasLater = YES;
                dispatch_async(_imageRenderQueue, ^() {
                    NSString* sourcePath = [z_Sandbox documentPath:originalFile];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
                    {
                        return;
                    }
                    NSString* destPath = [z_Sandbox documentPath:localPath];
                    float* matrixData = (float*) malloc(sizeof(float) * 16);
                    MadvEXIFExtension madvExtension = readMadvEXIFExtensionFromJPEG(matrixData, sourcePath.UTF8String);
                    jpeg_decompress_struct jpegInfo = readImageInfoFromJPEG(sourcePath.UTF8String);
#ifdef USE_IMAGE_BLENDER
                    if (madvExtension.sceneType == StitchTypeStitched)
                    {
                        blendImage(sourcePath.UTF8String, sourcePath.UTF8String);
                    }
#endif
                    if (madvExtension.gyroMatrixBytes > 0)
                    {
                        MadvGLRenderer_iOS::renderJPEGToJPEG(destPath, YES, sourcePath, jpegInfo.image_width, jpegInfo.image_height, madvExtension.sceneType != StitchTypeStitched, madvExtension.withEmbeddedLUT, (int)media.filterID, matrixData, 3);
                    }
                    else
                    {
                        MadvGLRenderer_iOS::renderJPEGToJPEG(destPath, YES, sourcePath, jpegInfo.image_width, jpegInfo.image_height, madvExtension.sceneType != StitchTypeStitched, madvExtension.withEmbeddedLUT, (int)media.filterID, NULL, 0);
                    }
                    free(matrixData);
                    /*
                    long exivImageHandler = createExivImage(destPath.UTF8String);
                    if (StitchTypeStitched != madvExtension.sceneType)
                    {
                        exivImageEraseSceneType(exivImageHandler);
                    }
                    if (madvExtension.gyroMatrixBytes > 0)
                    {
                        exivImageEraseGyroData(exivImageHandler);
                    }
                    exivImageSaveMetaData(exivImageHandler);
                    releaseExivImage(exivImageHandler);
                    //*/
                    if (![destPath isEqualToString:sourcePath])
                    {
                        [[NSFileManager defaultManager] removeItemAtPath:sourcePath error:nil];
                    }
                    //*
                    UIImage* thumbnailImage = MadvGLRenderer_iOS::renderJPEG(destPath.UTF8String, CGSizeMake(ThumbnailWidth, ThumbnailHeight), false, destPath, false, 0, NULL, 0);
                    [self saveMediaThumbnail:media thumbnail:thumbnailImage];
                    //[self sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];
                    //[self updateLocalMedia:media];
                    //*/
                    [media transactionWithBlock:^{
                        media.modifyDate = [NSDate date];
                    }];
                    [self setMediaDownloadStatus:MVMediaDownloadStatusFinished ofMedia:media errorCode:0];
                    //[wSelf invalidateLocalMedias:YES];
                });
                continue;
            }
            else
            {
                ///!!!Should not happen!!!
                continue;
            }
        }
        
        //NSString* baseName = [file stringByDeletingPathExtension];
        //NSRange outputFilePatternRange = [originalFile rangeOfString:DECODE_FILENAME_EXTENDOTHER];
        if ([ext isEqualToString:@"mov"])
        {
            if ([[originalFile lastPathComponent] hasPrefix:SCREEN_CAPTURE_FILENAME_PREFIX])
            {
                [[NSFileManager defaultManager] removeItemAtPath:[z_Sandbox documentPath:originalFile] error:nil];
            }
            continue;
        }
        
        MVMedia* prestoredMedia = [MVMedia createWithCameraUUID:@"LOCAL" remoteFullPath:originalFile];
        MVMedia* savedMedia = [MVMedia querySavedMediaWithRemotePath:nil localPath:originalFile];
        if (!savedMedia)
        {
            NSString* filePath = [z_Sandbox documentPath:originalFile];
            NSInteger fileSize = fileSizeAtPath(filePath);
            if (isVideo)
            {
                NSDictionary* opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
                AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:filePath] options:opts];
                CMTime duration = asset.duration;
                Float64 seconds = (NSInteger) CMTimeGetSeconds(duration);
                [prestoredMedia transactionWithBlock:^{
                    prestoredMedia.localPath = prestoredMedia.remotePath;
                    prestoredMedia.size = fileSize;
                    prestoredMedia.downloadedSize = fileSize;
                    prestoredMedia.createDate = [NSDate date];
                    prestoredMedia.modifyDate = [NSDate date];
                    prestoredMedia.videoDuration = (int)seconds;
                }];
            }
            else
            {
                [prestoredMedia transactionWithBlock:^{
                    prestoredMedia.localPath = prestoredMedia.remotePath;
                    prestoredMedia.size = fileSize;
                    prestoredMedia.downloadedSize = fileSize;
                    prestoredMedia.createDate = [NSDate date];
                    prestoredMedia.modifyDate = [NSDate date];
                }];
            }
            [prestoredMedia insert];
            savedMedia = prestoredMedia;
        }
    }
    
    if (shouldInvalidateLocalMediasLater)
    {
        dispatch_async(_imageRenderQueue, ^() {
            [self invalidateLocalMedias:YES];
        });
    }
}

/*
NSString* uniqueLocalPath(NSString* cameraUUID, NSString* remotePath) {
    NSArray<MVMedia* >* savedMedias = [MVMedia querySavedMediasWithCameraUUID:cameraUUID remotePath:remotePath localPath:nil];
    NSString* baseFileName = [MVMedia storageKeyWithCameraUUID:cameraUUID remotePath:remotePath localPath:nil];
    int prefix = 0;
    while (YES)
    {
        if (savedMedias)
        {
            BOOL isNameUnique = YES;
            for (MVMedia* savedMedia in savedMedias)
            {
                if ([baseFileName isEqualToString:savedMedia.localPath])
                {
                    isNameUnique = NO;
                    break;
                }
                else
                {
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[z_Sandbox documentPath:baseFileName]])
                    {
                        isNameUnique = NO;
                        break;
                    }
                }
            }
            
            if (isNameUnique)
            {
                break;
            }
            else
            {
                baseFileName = [NSString stringWithFormat:@"%d%@", prefix, baseFileName];
                prefix++;
            }
        }
        else
        {
            break;
        }
    }
    return baseFileName;
}
//*/
+ (NSString*) httpURLFromRemotePath:(NSString*)remotePath {
    return [remotePath stringByReplacingOccurrencesOfString:HTTP_DOWNLOAD_REMOTE_ROOT withString:HTTP_DOWNLOAD_URL_PREFIX];
}
+ (NSString*) remotePathFromHttpURL:(NSString*)httpURL {
    return [httpURL stringByReplacingOccurrencesOfString:HTTP_DOWNLOAD_URL_PREFIX withString:HTTP_DOWNLOAD_REMOTE_ROOT];
}

+ (NSInteger) freeDiskSpace
{
    NSDictionary *fattributes = [[ NSFileManager defaultManager ] attributesOfFileSystemForPath : NSHomeDirectory() error : nil ];
    return [[fattributes objectForKey : NSFileSystemFreeSize] integerValue];
}

- (void) cancelDownloadingAfter {
    
}

- (BOOL) hasDownloadingTasks {
    return (_downloadTasks && _downloadTasks.count > 0);
}

- (void) enableCameraClientHeartbeatIfNecessary {
    static NSString* DownloaderHeartbeatDemander = @"Downloader";
    if ([self hasDownloadingTasks])
    {
        [[MVCameraClient sharedInstance] setHeartbeatEnabled:YES forDemander:DownloaderHeartbeatDemander];
    }
    else
    {
        [[MVCameraClient sharedInstance] setHeartbeatEnabled:NO forDemander:DownloaderHeartbeatDemander];
    }
}

- (BOOL) addDownloading:(MVMedia*)media initChunkSize:(int)initChunkSize normalChunkSize:(int)normalChunkSize addAsFirst:(BOOL)addAsFirst {
    //NSLog(@"#Bug3040# addDownloading :#0 localPath = '%@', media = %@", media.localPath, media);
#ifdef DEBUG_HTTP_DOWNLOADING
    [media transactionWithBlock:^{
        media.size = 0;
        media.downloadedSize = 0;
    }];
    [media update];
#else
    MVCameraDevice* connectingDevice = [MVCameraClient sharedInstance].connectingCamera;
    if (!connectingDevice || ![connectingDevice.uuid isEqualToString:media.cameraUUID])
    {
        return NO;
    }
#endif
    
#ifdef USE_HTTP_DOWNLOADING
    AFHTTPDownloadTask* downloadTask;
#else
    FileDownloadTask* downloadTask;
#endif
    @synchronized (self)
    {
        MVMedia* cameraMediaToDownload = nil;
        for (MVMedia* cameraMedia in _cameraMedias)
        {
            if ([cameraMedia isEqualRemoteMedia:media])
            {
                cameraMediaToDownload = cameraMedia;
                break;
            }
        }
        
        if (!cameraMediaToDownload)
        {
            [media transactionWithBlock:^{
                media.localPath = [MVMedia uniqueLocalPathWithCameraUUID:media.cameraUUID remotePath:media.remotePath];
            }];
            [media update];
            [self addNewCameraMedia:media justCreated:NO];
        }
        else if (!cameraMediaToDownload.localPath || 0 == cameraMediaToDownload.localPath.length)
        {
            [cameraMediaToDownload transactionWithBlock:^{
                cameraMediaToDownload.localPath = [MVMedia uniqueLocalPathWithCameraUUID:media.cameraUUID remotePath:media.remotePath];
            }];
            [cameraMediaToDownload update];
            
            media = cameraMediaToDownload;
        }
        else if (cameraMediaToDownload.downloadedSize >= cameraMediaToDownload.size && 0 != cameraMediaToDownload.size)
        {
            cameraMediaToDownload = [MVMedia createWithCameraUUID:media.cameraUUID remoteFullPath:media.remotePath];
            [cameraMediaToDownload copyCommonFields:media];
            [cameraMediaToDownload transactionWithBlock:^{
                cameraMediaToDownload.localPath = [MVMedia uniqueLocalPathWithCameraUUID:media.cameraUUID remotePath:media.remotePath];
            }];
            [cameraMediaToDownload insert];
            
            [self updateCameraMedia:cameraMediaToDownload];
            media = cameraMediaToDownload;
        }
        else
        {
            media = cameraMediaToDownload;
        }
        //NSLog(@"#Bug3040# addDownloading :#2 localPath = '%@', media = %@", media.localPath, media);
        long rangeStart, rangeLength;
        if (0 == media.size)
        {
            rangeStart = 0;
            rangeLength = initChunkSize;
        }
        else
        {
            rangeStart = media.downloadedSize;
            rangeLength = media.size - media.downloadedSize;
            if (rangeLength > normalChunkSize)
            {
                rangeLength = normalChunkSize;
            }
            else if (0 == rangeLength)
            {
                return YES;
            }
        }
        
        NSString* destLocalPath = (MVMediaTypePhoto == media.mediaType ? MadvGLRenderer_iOS::preStitchPictureFileName(media.cameraUUID, media.localPath) : media.localPath);
#ifdef USE_HTTP_DOWNLOADING
        
#ifdef DEBUG_HTTP_DOWNLOADING
        downloadTask = [[HTTPDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remoteFilePath:media.remotePath resumeData:media.downloadResumeData localFilePath:[z_Sandbox documentPath:[destLocalPath lastPathComponent]] chunkSize:DownloadChunkSize callback:nil];
#else
        NSString* httpSourceURL = [self.class httpURLFromRemotePath:media.remotePath];
        //downloadTask = [[HTTPDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remoteFilePath:httpSourceURL offset:media.downloadedSize resumeData:media.downloadResumeData localFilePath:[z_Sandbox documentPath:media.localPath] chunkSize:(int)rangeLength callback:nil];
        downloadTask = [[AFHTTPDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remoteFilePath:httpSourceURL offset:rangeStart length:DownloadChunkSize localFilePath:[z_Sandbox documentPath:destLocalPath] callback:nil];
#endif

#else
        downloadTask = [[FileDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remotePath:media.remotePath fileOffset:rangeStart chunkSize:rangeLength localFilePath:[z_Sandbox documentPath:destLocalPath] callback:nil];
#endif
        
        if (_isDownloadingHanging)
        {
            if (![_hangingDownloadMedias containsObject:media])
            {
                [_hangingDownloadMedias addObject:media];
            }
            [self setMediaDownloadStatus:MVMediaDownloadStatusStopped ofMedia:media errorCode:0];
            
            return YES;
        }
        else
        {
            if ([_downloadTasks containsObject:downloadTask])
            {
                return YES;
            }
            
            [_downloadTasks addObject:downloadTask];
            //NSLog(@"#Bug3269# addDownloading : add downloadTask=%@, media = %@", downloadTask, media);
            [self enableCameraClientHeartbeatIfNecessary];
            
            [self setMediaDownloadStatus:MVMediaDownloadStatusPending ofMedia:media errorCode:0];
        }
    }
    
    __weak __typeof(self) wSelf = self;
    __weak MVDownloadTask* wDownloadTask = downloadTask;
    
    //__block long currentDownloadedSize = 0;///!!!#Bug3040#
    __block BOOL gotFileSize = NO;
#ifndef USE_HTTP_DOWNLOADING
    __block BOOL transferCompleted = NO;
#endif
    __block BOOL canceled = NO;
    __block long lastProgressNotifyTime = -1;
    
    void(^completeDownloadingBlock)(long) = ^(long downloadedSize) {
        __strong __typeof(self) pSelf = wSelf;
        __strong MVDownloadTask* pDownloadTask = wDownloadTask;
        @synchronized (pSelf)
        {
            [pSelf.downloadTasks removeObject:pDownloadTask];
            //(@"#Bug3269# completeDownloadingBlock : remove pDownloadTask = %@, media = %@", pDownloadTask, media);
            [pSelf enableCameraClientHeartbeatIfNecessary];
        }
        
        if (media.size <= downloadedSize)
        {
            dispatch_async(_imageRenderQueue, ^() {
                //NSLog(@"#Bug3040# addDownloading :#3 localPath = '%@', media = %@", media.localPath, media);
                if (media.mediaType == MVMediaTypePhoto)
                {
                    NSString* sourcePath = [z_Sandbox documentPath:MadvGLRenderer_iOS::preStitchPictureFileName(media.cameraUUID, media.localPath)];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
                    {
                        return;
                    }
                    NSString* destPath = [z_Sandbox documentPath:media.localPath];
                    ///NSAssert(media.localPath && media.localPath.length > 0, @"media.localPath == null, media=%@", media);///!!!#Bug3040#
                    float* matrixData = (float*) malloc(sizeof(float) * 16);
                    MadvEXIFExtension madvExtension = readMadvEXIFExtensionFromJPEG(matrixData, sourcePath.UTF8String);
                    jpeg_decompress_struct jpegInfo = readImageInfoFromJPEG(sourcePath.UTF8String);
                    [media transactionWithBlock:^{
                        media.isStitched = (madvExtension.sceneType == StitchTypeStitched);
                    }];
#ifdef USE_IMAGE_BLENDER
                    if (madvExtension.sceneType == StitchTypeStitched)
                    {
                        blendImage(destPath.UTF8String, destPath.UTF8String);
                    }
#endif
                    if (madvExtension.gyroMatrixBytes > 0)
                    {
                        MadvGLRenderer_iOS::renderJPEGToJPEG(destPath, YES, sourcePath, jpegInfo.image_width, jpegInfo.image_height, madvExtension.sceneType != StitchTypeStitched, madvExtension.withEmbeddedLUT, (int)media.filterID, matrixData, 3);
                    }
                    else
                    {
                        MadvGLRenderer_iOS::renderJPEGToJPEG(destPath, YES, sourcePath, jpegInfo.image_width, jpegInfo.image_height, madvExtension.sceneType != StitchTypeStitched, madvExtension.withEmbeddedLUT, (int)media.filterID, NULL, 0);
                    }
                    free(matrixData);
                    /*
                    long exivImageHandler = createExivImage(destPath.UTF8String);
                    if (StitchTypeStitched != madvExtension.sceneType)
                    {
                        exivImageEraseSceneType(exivImageHandler);
                    }
                    if (madvExtension.gyroMatrixBytes > 0)
                    {
                        exivImageEraseGyroData(exivImageHandler);
                    }
                    exivImageSaveMetaData(exivImageHandler);
                    releaseExivImage(exivImageHandler);
                    //*/
                    if (![sourcePath isEqualToString:destPath])
                    {
                        [[NSFileManager defaultManager] removeItemAtPath:sourcePath error:nil];
                    }
                    /*
                     [media transactionWithBlock:^{
                     media.downloadedSize = downloadedSize;
                     }];///!!!#Bug3040#
                     //*/
                    //*
                    UIImage* thumbnailImage = MadvGLRenderer_iOS::renderJPEG(destPath.UTF8String, CGSizeMake(ThumbnailWidth, ThumbnailHeight), false, destPath, madvExtension.withEmbeddedLUT, 0, NULL, 0);
                    [pSelf saveMediaThumbnail:media thumbnail:thumbnailImage];
                    [pSelf sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];
                    [pSelf updateLocalMedia:media];
                    //*/
                }
                [media transactionWithBlock:^{
                    media.modifyDate = [NSDate date];
                }];
                [pSelf setMediaDownloadStatus:MVMediaDownloadStatusFinished ofMedia:media errorCode:0];
                [pSelf invalidateLocalMedias:YES];
            });
            
        }
#ifndef USE_HTTP_DOWNLOADING
        else if (!canceled)
        {
            /*///!!!#Bug3040#
            [media transactionWithBlock:^{
                media.downloadedSize = downloadedSize;
            }];
            //*/
            [pSelf addDownloading:media initChunkSize:initChunkSize normalChunkSize:normalChunkSize addAsFirst:YES];
        }
#endif
        else
        {
            /*///!!!#Bug3040#
            [media transactionWithBlock:^{
                media.downloadedSize = downloadedSize;
            }];
            //*/
        }
    };
    
    void(^onCompletedOrCanceledBlock)(long, MVDownloadTask*) = ^(long bytesReceived, MVDownloadTask* downloadTask) {
        __strong __typeof(self) pSelf = wSelf;
        long currentDownloadedSize = bytesReceived + media.downloadedSize;
        if (currentDownloadedSize > media.size && 0 < media.size)
        {
            currentDownloadedSize = media.size;
        }
        [media transactionWithBlock:^{
            media.downloadedSize = currentDownloadedSize;///!!!#Bug3040#
            
            if ([downloadTask isKindOfClass:HTTPDownloadTask.class])
            {
                HTTPDownloadTask* task = (HTTPDownloadTask*) downloadTask;
                media.downloadResumeData = task.resumeData;
            }
        }];
        //NSLog(@"#Download#RLMDeadLock#: onCompletedOrCanceledBlock #0 media = %@", media);
        [media update];
        //NSLog(@"#Download#RLMDeadLock#: onCompletedOrCanceledBlock #1 media = %@", media);
        
        if (!canceled)
        {
            [pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:currentDownloadedSize arg2:media.size object:media];
        }
#ifndef USE_HTTP_DOWNLOADING
        __strong MVDownloadTask* pDownloadTask = wDownloadTask;
        @synchronized (pDownloadTask)
        {
            transferCompleted = YES;
            if (!gotFileSize)
            {
                return;
            }
        }

        completeDownloadingBlock(currentDownloadedSize);///!!!#Bug3040#
#endif
    };
    
#ifdef USE_HTTP_DOWNLOADING
    downloadTask.callback = [[HTTPDownloadCallback alloc] initWithGotSizeBlock:^(NSInteger remSize, NSInteger totalSize, MVDownloadTask* downloadTask) {
#else
    downloadTask.callback = [[FileDownloadCallback alloc] initWithGotSizeBlock:^(NSInteger remSize, NSInteger totalSize, MVDownloadTask* downloadTask) {
#endif
        NSInteger freeDiskSpace = [self.class freeDiskSpace];
        if (remSize >= freeDiskSpace)
        {
            [self notifyNoDiskSpace];
        }
        
        __strong __typeof(self) pSelf = wSelf;
        if (totalSize >= media.size || totalSize - remSize != media.downloadedSize)
        {
            [media transactionWithBlock:^{
                ///!!!For Debug
                if (totalSize < 1048576)
                {
                    DoctorLog(@"#MVMediaWrongSize# downloadTask.callback : totalSize = %ld", (long)totalSize);
                }
                media.size = totalSize;
                media.downloadedSize = totalSize - remSize;///!!!
            }];
            [media saveCommonFields];
            [pSelf updateCameraMedia:media];
            [pSelf invalidateLocalMedias:NO];
            [pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:media.downloadedSize arg2:totalSize object:media];
        }
        
        [pSelf setMediaDownloadStatus:MVMediaDownloadStatusDownloading ofMedia:media errorCode:0];
#ifndef USE_HTTP_DOWNLOADING
        __strong MVDownloadTask* pDownloadTask = wDownloadTask;
        @synchronized (pDownloadTask)
        {
            gotFileSize = YES;
            if (!transferCompleted)
            {
                return;
            }
        }
        
        completeDownloadingBlock(downloadedSize);///!!!#Bug3040#
#endif
    } completedBlock:^(NSInteger bytesReceived, MVDownloadTask* downloadTask) {
        canceled = NO;
        onCompletedOrCanceledBlock(bytesReceived, downloadTask);
#ifdef USE_HTTP_DOWNLOADING
    } allCompletedBlock:^(MVDownloadTask *downloadTask) {
        [media transactionWithBlock:^{
            media.downloadedSize = media.size;///!!!#Bug3040#
            media.downloadResumeData = nil;
        }];
        completeDownloadingBlock(media.size);///!!!#Bug3040#
#endif
    } canceledBlock:^(NSInteger bytesReceived, MVDownloadTask* downloadTask) {
        canceled = YES;
        onCompletedOrCanceledBlock(bytesReceived, downloadTask);
    } progressBlock:^(NSInteger totalBytes, NSInteger downloadedBytes, MVDownloadTask* downloadTask) {
        __strong __typeof(self) pSelf = wSelf;
        if (canceled) return;
        
        long long nowTime = [[NSDate date] timeIntervalSince1970] * 1000;
        if (-1 == lastProgressNotifyTime)
        {
            lastProgressNotifyTime = nowTime;
        }
        else if (nowTime - lastProgressNotifyTime >= 1000)
        {
            [pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:(media.downloadedSize + downloadedBytes) arg2:media.size object:media];
            //[pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:(currentDownloadedSize + downloadedBytes) arg2:media.size object:media];///!!!#Bug3040#
            lastProgressNotifyTime = nowTime;
        }
    } errorBlock:^(int errorCode, MVDownloadTask* downloadTask) {
        __strong __typeof(self) pSelf = wSelf;
        __strong MVDownloadTask* pDownloadTask = wDownloadTask;
        [pSelf.downloadTasks removeObject:pDownloadTask];
        //NSLog(@"#Bug3269# errorBlock : remove pDownloadTask = %@, media = %@", pDownloadTask, media);
        [pSelf enableCameraClientHeartbeatIfNecessary];
        
        if (FileDownloadErrorCanceled == errorCode)
        {
            [pSelf setMediaDownloadStatus:MVMediaDownloadStatusStopped ofMedia:media errorCode:0];
        }
        else
        {
            [pSelf setMediaDownloadStatus:MVMediaDownloadStatusError ofMedia:media errorCode:errorCode];
        }
    }];
    [[MVCameraDownloadManager sharedInstance] addTask:downloadTask addAsFirst:addAsFirst];

    return YES;
}

#define V1
- (void) addDownloadingOfMedias:(NSArray<MVMedia* >*)medias initChunkSize:(int)initChunkSize normalChunkSize:(int)normalChunkSize addAsFirst:(BOOL)addAsFirst completion:(dispatch_block_t)completion progressBlock:(ProgressiveActionBlock)progressBlock {
     //NSLog(@"#Bug3040# addDownloading :#0 localPath = '%@', media = %@", media.localPath, media);
     dispatch_async(_enqueDownloadQueue, ^{
#ifdef V1
         BOOL canceled = NO;
         int totalCount = (int)medias.count;
         __block int completedCount = 0;
         for (MVMedia* media in medias)
         {
             [self addDownloading:media initChunkSize:initChunkSize normalChunkSize:normalChunkSize addAsFirst:addAsFirst];
             if (progressBlock)
             {
                 progressBlock(++completedCount, totalCount, &canceled);
                 if (canceled)
                     break;
             }
         }
         if (completion)
         {
             dispatch_async(dispatch_get_main_queue(), completion);
         }
#else // V1
         NSMutableArray<MVMedia* >* mediasHanging = [[NSMutableArray alloc] init];
         NSMutableArray<MediaDownloadTaskPair* >* mediaDownloadTasks = [[NSMutableArray alloc] init];
         MVCameraDevice* connectingDevice = [MVCameraClient sharedInstance].connectingCamera;
         BOOL canceled = NO;
         int totalCount = (int)medias.count;
         __block int completedCount = 0;
         
         for (MVMedia* m in medias)
         {
             if (progressBlock)
             {
                 progressBlock(++completedCount, totalCount, &canceled);
                 if (canceled)
                     break;
             }
             
             long rangeStart, rangeLength;
             MVMedia* media = m;
#ifdef DEBUG_HTTP_DOWNLOADING
             [media transactionWithBlock:^{
                 media.size = 0;
                 media.downloadedSize = 0;
             }];
             [media update];
#else
             if (!connectingDevice || ![connectingDevice.uuid isEqualToString:media.cameraUUID])
             {
                 continue;
             }
#endif
             @synchronized (self)
             {
                 MVMedia* cameraMediaToDownload = nil;
                 for (MVMedia* cameraMedia in _cameraMedias)
                 {
                     if ([cameraMedia isEqualRemoteMedia:media])
                     {
                         cameraMediaToDownload = cameraMedia;
                         break;
                     }
                 }
                 if (!cameraMediaToDownload)
                 {
                     [media transactionWithBlock:^{
                         media.localPath = [MVMedia uniqueLocalPathWithCameraUUID:media.cameraUUID remotePath:media.remotePath];
                     }];
                     [media update];
                     [self addNewCameraMedia:media justCreated:NO];
                 }
                 else if (!cameraMediaToDownload.localPath || 0 == cameraMediaToDownload.localPath.length)
                 {
                     [cameraMediaToDownload transactionWithBlock:^{
                         cameraMediaToDownload.localPath = [MVMedia uniqueLocalPathWithCameraUUID:media.cameraUUID remotePath:media.remotePath];
                     }];
                     [cameraMediaToDownload update];
                     
                     media = cameraMediaToDownload;
                 }
                 else if (cameraMediaToDownload.downloadedSize >= cameraMediaToDownload.size && 0 != cameraMediaToDownload.size)
                 {
                     cameraMediaToDownload = [MVMedia createWithCameraUUID:media.cameraUUID remoteFullPath:media.remotePath];
                     [cameraMediaToDownload copyCommonFields:media];
                     [cameraMediaToDownload transactionWithBlock:^{
                         cameraMediaToDownload.localPath = [MVMedia uniqueLocalPathWithCameraUUID:media.cameraUUID remotePath:media.remotePath];
                     }];
                     [cameraMediaToDownload insert];
                     
                     [self updateCameraMedia:cameraMediaToDownload];
                     media = cameraMediaToDownload;
                 }
                 else
                 {
                     media = cameraMediaToDownload;
                 }
                 //NSLog(@"#Bug3040# addDownloading :#2 localPath = '%@', media = %@", media.localPath, media);
                 if (0 == media.size)
                 {
                     rangeStart = 0;
                     rangeLength = initChunkSize;
                 }
                 else
                 {
                     rangeStart = media.downloadedSize;
                     rangeLength = media.size - media.downloadedSize;
                     if (rangeLength > normalChunkSize)
                     {
                         rangeLength = normalChunkSize;
                     }
                     else if (0 == rangeLength)
                     {
                         continue;
                     }
                 }
             }

             if (_isDownloadingHanging)
             {
                 if (![_hangingDownloadMedias containsObject:media])
                 {
                     [_hangingDownloadMedias addObject:media];
                 }
                 [mediasHanging addObject:media];
             }
             else
             {
#ifdef USE_HTTP_DOWNLOADING
                 AFHTTPDownloadTask* downloadTask;
#else
                 FileDownloadTask* downloadTask;
#endif
#ifdef USE_HTTP_DOWNLOADING
                 
#ifdef DEBUG_HTTP_DOWNLOADING
                 downloadTask = [[HTTPDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remoteFilePath:media.remotePath resumeData:media.downloadResumeData localFilePath:[z_Sandbox documentPath:[media.localPath lastPathComponent]] chunkSize:DownloadChunkSize callback:nil];
#else
                 NSString* httpSourceURL = [self.class httpURLFromRemotePath:media.remotePath];
                 //downloadTask = [[HTTPDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remoteFilePath:httpSourceURL offset:media.downloadedSize resumeData:media.downloadResumeData localFilePath:[z_Sandbox documentPath:media.localPath] chunkSize:(int)rangeLength callback:nil];
                 downloadTask = [[AFHTTPDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remoteFilePath:httpSourceURL offset:rangeStart length:DownloadChunkSize localFilePath:[z_Sandbox documentPath:media.localPath] callback:nil];
#endif
                 
#else
                 downloadTask = [[FileDownloadTask alloc] initWithPriority:MVDownloadTaskPriorityLow remotePath:media.remotePath fileOffset:rangeStart chunkSize:rangeLength localFilePath:[z_Sandbox documentPath:media.localPath] callback:nil];
#endif
                 if ([self.downloadTasks containsObject:downloadTask])
                 {
                     continue;
                 }
                 
                 [self.downloadTasks addObject:downloadTask];
                 //NSLog(@"#Bug3269# addDownloading#1 : add downloadTask=%@, media = %@", downloadTask, media);
                 MediaDownloadTaskPair* pair = [[MediaDownloadTaskPair alloc] initWithMedia:media downloadTask:downloadTask];
                 [mediaDownloadTasks addObject:pair];
             }
         }
         
         if (!mediaDownloadTasks || 0 == mediaDownloadTasks.count)
         {
             return;
         }
         
         [self enableCameraClientHeartbeatIfNecessary];

         for (MediaDownloadTaskPair* pair in mediaDownloadTasks)
         {
             MVMedia* media = pair.media;
#ifdef USE_HTTP_DOWNLOADING
             AFHTTPDownloadTask* downloadTask = (AFHTTPDownloadTask*) pair.downloadTask;
#else
             FileDownloadTask* downloadTask = (FileDownloadTask*) pair.downloadTask;
#endif
             __weak typeof(self) wSelf = self;
             __weak MVDownloadTask* wDownloadTask = downloadTask;
             
             //__block long currentDownloadedSize = 0;///!!!#Bug3040#
             __block BOOL gotFileSize = NO;
#ifndef USE_HTTP_DOWNLOADING
             __block BOOL transferCompleted = NO;
#endif
             __block BOOL canceled = NO;
             __block long lastProgressNotifyTime = -1;
             
             void(^completeDownloadingBlock)(long) = ^(long downloadedSize) {
                 __strong typeof(self) pSelf = wSelf;
                 __strong MVDownloadTask* pDownloadTask = wDownloadTask;
                 @synchronized (pSelf)
                 {
                     [pSelf.downloadTasks removeObject:pDownloadTask];
                     //NSLog(@"#Bug3269# completeDownloadingBlock#1 : remove pDownloadTask = %@, media = %@", pDownloadTask, media);
                     [pSelf enableCameraClientHeartbeatIfNecessary];
                 }
                 
                 if (media.size <= downloadedSize)
                 {
                     dispatch_async(pSelf.imageRenderQueue, ^() {
                         //NSLog(@"#Bug3040# addDownloading :#3 localPath = '%@', media = %@", media.localPath, media);
                         if (media.mediaType == MVMediaTypePhoto)
                         {
                             NSString* sourcePath = [z_Sandbox documentPath:MadvGLRenderer_iOS::preStitchPictureFileName(media.cameraUUID, media.localPath)];
                             if (![[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
                             {
                                 return;
                             }
                             NSString* destPath = [z_Sandbox documentPath:media.localPath];
                             ///NSAssert(media.localPath && media.localPath.length > 0, @"media.localPath == null, media=%@", media);///!!!#Bug3040#
                             float* matrixData = (float*) malloc(sizeof(float) * 16);
                             int matrixByteLength = readGyroDataFromJPEG(matrixData, sourcePath.UTF8String);
                             jpeg_decompress_struct jpegInfo = readImageInfoFromJPEG(sourcePath.UTF8String);
#ifdef USE_IMAGE_BLENDER
                             if (madvExtension.sceneType == StitchTypeStitched)
                             {
                                 blendImage(destPath.UTF8String, destPath.UTF8String);
                             }
#endif
                             if (matrixByteLength > 0)
                             {
                                 MadvGLRenderer_iOS::renderJPEGToJPEG(destPath, YES, sourcePath, jpegInfo.image_width, jpegInfo.image_height, STITCH_PICTURE, (int)media.filterID, matrixData, 3);
                             }
                             else
                             {
                                 MadvGLRenderer_iOS::renderJPEGToJPEG(destPath, YES, sourcePath, jpegInfo.image_width, jpegInfo.image_height, STITCH_PICTURE, (int)media.filterID, NULL, 0);
                             }
                             free(matrixData);
                             
                             if (![sourcePath isEqualToString:destPath])
                             {
                                 [[NSFileManager defaultManager] removeItemAtPath:sourcePath error:nil];
                             }
                             /*
                              [media transactionWithBlock:^{
                              media.downloadedSize = downloadedSize;
                              }];///!!!#Bug3040#
                              //*/
                             //*
                             UIImage* thumbnailImage = MadvGLRenderer_iOS::renderJPEG(destPath.UTF8String, CGSizeMake(ThumbnailWidth, ThumbnailHeight), false, destPath, 0, NULL, 0);
                             [pSelf saveMediaThumbnail:media thumbnail:thumbnailImage];
                             [pSelf sendCallbackMessage:MsgThumbnailFetched arg1:0 arg2:0 object:media];
                             [pSelf updateLocalMedia:media];
                             //*/
                         }
                         [media transactionWithBlock:^{
                             media.modifyDate = [NSDate date];
                         }];
                         [pSelf setMediaDownloadStatus:MVMediaDownloadStatusFinished ofMedia:media errorCode:0];
                         [pSelf invalidateLocalMedias:YES];
                     });
                     
                 }
#ifndef USE_HTTP_DOWNLOADING
                 else if (!canceled)
                 {
                     /*///!!!#Bug3040#
                      [media transactionWithBlock:^{
                      media.downloadedSize = downloadedSize;
                      }];
                      //*/
                     [pSelf addDownloading:media initChunkSize:initChunkSize normalChunkSize:normalChunkSize addAsFirst:YES];
                 }
#endif
                 else
                 {
                     /*///!!!#Bug3040#
                      [media transactionWithBlock:^{
                      media.downloadedSize = downloadedSize;
                      }];
                      //*/
                 }
             };
             
             void(^onCompletedOrCanceledBlock)(long, MVDownloadTask*) = ^(long bytesReceived, MVDownloadTask* downloadTask) {
                 __strong __typeof(self) pSelf = wSelf;
                 long currentDownloadedSize = bytesReceived + media.downloadedSize;
                 if (currentDownloadedSize > media.size && 0 < media.size)
                 {
                     currentDownloadedSize = media.size;
                 }
                 [media transactionWithBlock:^{
                     media.downloadedSize = currentDownloadedSize;///!!!#Bug3040#
                     
                     if ([downloadTask isKindOfClass:HTTPDownloadTask.class])
                     {
                         HTTPDownloadTask* task = (HTTPDownloadTask*) downloadTask;
                         media.downloadResumeData = task.resumeData;
                     }
                 }];
                 //NSLog(@"#Download#RLMDeadLock#: onCompletedOrCanceledBlock #0 media = %@", media);
                 [media update];
                 //NSLog(@"#Download#RLMDeadLock#: onCompletedOrCanceledBlock #1 media = %@", media);
                 
                 if (!canceled)
                 {
                     [pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:currentDownloadedSize arg2:media.size object:media];
                 }
#ifndef USE_HTTP_DOWNLOADING
                 __strong MVDownloadTask* pDownloadTask = wDownloadTask;
                 @synchronized (pDownloadTask)
                 {
                     transferCompleted = YES;
                     if (!gotFileSize)
                     {
                         return;
                     }
                 }
                 
                 completeDownloadingBlock(currentDownloadedSize);///!!!#Bug3040#
#endif
             };
             
#ifdef USE_HTTP_DOWNLOADING
             downloadTask.callback = [[HTTPDownloadCallback alloc] initWithGotSizeBlock:^(NSInteger remSize, NSInteger totalSize, MVDownloadTask* downloadTask) {
#else
             downloadTask.callback = [[FileDownloadCallback alloc] initWithGotSizeBlock:^(NSInteger remSize, NSInteger totalSize, MVDownloadTask* downloadTask) {
#endif
                 __strong typeof(self) pSelf = wSelf;
                 NSInteger freeDiskSpace = [self.class freeDiskSpace];
                 if (remSize >= freeDiskSpace)
                 {
                     [pSelf notifyNoDiskSpace];
                 }
                 
                 if (totalSize >= media.size || totalSize - remSize != media.downloadedSize)
                 {
                     [media transactionWithBlock:^{
                         media.size = totalSize;
                         media.downloadedSize = totalSize - remSize;///!!!
                     }];
                     [media saveCommonFields];
                     [pSelf updateCameraMedia:media];
                     [pSelf invalidateLocalMedias:NO];
                     [pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:media.downloadedSize arg2:totalSize object:media];
                 }
                 
                 [pSelf setMediaDownloadStatus:MVMediaDownloadStatusDownloading ofMedia:media errorCode:0];
#ifndef USE_HTTP_DOWNLOADING
                 __strong MVDownloadTask* pDownloadTask = wDownloadTask;
                 @synchronized (pDownloadTask)
                 {
                     gotFileSize = YES;
                     if (!transferCompleted)
                     {
                         return;
                     }
                 }
                 
                 completeDownloadingBlock(downloadedSize);///!!!#Bug3040#
#endif
             } completedBlock:^(NSInteger bytesReceived, MVDownloadTask* downloadTask) {
                 canceled = NO;
                 onCompletedOrCanceledBlock(bytesReceived, downloadTask);
#ifdef USE_HTTP_DOWNLOADING
             } allCompletedBlock:^(MVDownloadTask *downloadTask) {
                 [media transactionWithBlock:^{
                     media.downloadedSize = media.size;///!!!#Bug3040#
                     media.downloadResumeData = nil;
                 }];
                 completeDownloadingBlock(media.size);///!!!#Bug3040#
#endif
             } canceledBlock:^(NSInteger bytesReceived, MVDownloadTask* downloadTask) {
                 canceled = YES;
                 onCompletedOrCanceledBlock(bytesReceived, downloadTask);
             } progressBlock:^(NSInteger totalBytes, NSInteger downloadedBytes, MVDownloadTask* downloadTask) {
                 __strong __typeof(self) pSelf = wSelf;
                 if (canceled) return;
                 
                 long long nowTime = [[NSDate date] timeIntervalSince1970] * 1000;
                 if (-1 == lastProgressNotifyTime)
                 {
                     lastProgressNotifyTime = nowTime;
                 }
                 else if (nowTime - lastProgressNotifyTime >= 1000)
                 {
                     [pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:(media.downloadedSize + downloadedBytes) arg2:media.size object:media];
                     //[pSelf sendCallbackMessage:MsgDownloadProgressUpdated arg1:(currentDownloadedSize + downloadedBytes) arg2:media.size object:media];///!!!#Bug3040#
                     lastProgressNotifyTime = nowTime;
                 }
             } errorBlock:^(int errorCode, MVDownloadTask* downloadTask) {
                 __strong __typeof(self) pSelf = wSelf;
                 __strong MVDownloadTask* pDownloadTask = wDownloadTask;
                 [pSelf.downloadTasks removeObject:pDownloadTask];
                 //NSLog(@"#Bug3269# errorBlock#1 : remove pDownloadTask = %@, media = %@", pDownloadTask, media);
                 [pSelf enableCameraClientHeartbeatIfNecessary];
                 
                 if (FileDownloadErrorCanceled == errorCode)
                 {
                     [pSelf setMediaDownloadStatus:MVMediaDownloadStatusStopped ofMedia:media errorCode:0];
                 }
                 else
                 {
                     [pSelf setMediaDownloadStatus:MVMediaDownloadStatusError ofMedia:media errorCode:errorCode];
                 }
             }];
                 
             [[MVCameraDownloadManager sharedInstance] addTask:downloadTask addAsFirst:addAsFirst];
         }
                                      
         [self setMediaDownloadStatus:MVMediaDownloadStatusStopped ofMedias:mediasHanging completion:completion];
         NSMutableArray<MVMedia* >* mediasToDownload = [[NSMutableArray alloc] init];
         for (MediaDownloadTaskPair* pair in mediaDownloadTasks)
         {
             [mediasToDownload addObject:pair.media];
         }
         [self setMediaDownloadStatus:MVMediaDownloadStatusPending ofMedias:mediasToDownload completion:completion];
#endif // V1
     });
}
#undef V1
                                      
- (MVDownloadTask*) taskOfMedia:(MVMedia*)media {
    if (!media.remotePath || 0 == media.remotePath.length)
        return nil;
    
    MVDownloadTask* ret = nil;
    for (MVDownloadTask* task in _downloadTasks)
    {
        NSString* remotePath = nil;
        NSString* localPath = nil;
        if ([task isKindOfClass:HTTPDownloadTask.class])
        {
            HTTPDownloadTask* httpDownloadTask = (HTTPDownloadTask*) task;
            remotePath = [self.class remotePathFromHttpURL:httpDownloadTask.remoteFilePath];
            localPath = httpDownloadTask.localFilePath;
        }
        else if ([task isKindOfClass:AFHTTPDownloadTask.class])
        {
            AFHTTPDownloadTask* afDownloadTask = (AFHTTPDownloadTask*) task;
            remotePath = [self.class remotePathFromHttpURL:afDownloadTask.remoteFilePath];
            localPath = afDownloadTask.localFilePath;
        }
        else if ([task isKindOfClass:FileDownloadTask.class])
        {
            FileDownloadTask* fileDownloadTask = (FileDownloadTask*) task;
            remotePath = fileDownloadTask.remoteFilePath;
            localPath = fileDownloadTask.localFilePath;
        }
        
        NSString* stitchedPictureName = MadvGLRenderer_iOS::stitchedPictureFileName(localPath);
        if (stitchedPictureName)
        {
            localPath = stitchedPictureName;
        }
        
        if ([media.remotePath isEqualToString:remotePath] && [media.localPath isEqualToString:[localPath lastPathComponent]])
        {
            ret = task;
            break;
        }
        /*/!!!For Debug:
        else
        {
            if ([media.remotePath isEqualToString:remotePath])
            {
                NSLog(@"#Bug3269# taskOfMedia NG#A : remotePath = %@, localPath = %@, media.remotePath = %@, media.localPath = %@", remotePath, localPath, media.remotePath, media.localPath);
            }
            if ([media.localPath isEqualToString:[localPath lastPathComponent]])
            {
                NSLog(@"#Bug3269# taskOfMedia NG#B : remotePath = %@, localPath = %@, media.remotePath = %@, media.localPath = %@", remotePath, localPath, media.remotePath, media.localPath);
            }
        }
        //*/
        ///!!!:For Debug #Bug3269#
    }
    return ret;
}

- (void) removeDownloading:(MVMedia *)media {
    [_hangingDownloadMedias removeObject:media];
    
    MVDownloadTask* taskToRemove = [self taskOfMedia:media];
    if (taskToRemove)
    {
        //NSLog(@"#Bug3269#AFHTTPDownload#pause : removeDownloading OK : taskToRemove = %@, media = %@", taskToRemove, media);
        ///[taskToRemove cancel];
        [[MVCameraDownloadManager sharedInstance] removeTask:taskToRemove];
        [_downloadTasks removeObject:taskToRemove];
        [self enableCameraClientHeartbeatIfNecessary];
    }
    //else
    //{
    //    NSLog(@"#Bug3269#AFHTTPDownload#pause : removeDownloading NG @ %@, media = %@", taskToRemove, media);
    //}
    if (media.localPath && 0 != media.localPath.length)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[z_Sandbox documentPath:media.localPath] error:nil];
        NSString* tempFilePath = [MVCameraDownloadManager downloadingTempFilePath:media.localPath];
        [[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
    }
    
    MVMedia* cameraMediaToRemove = nil;
    @synchronized (self)
    {
        for (MVMedia* cameraMedia in _cameraMedias)
        {
            if ([cameraMedia isEqualRemoteMedia:media])
            {
                cameraMediaToRemove = cameraMedia;
                break;
            }
        }
    }
    
    if (cameraMediaToRemove && [cameraMediaToRemove.localPath isEqualToString:media.localPath])
    {
        [self setMediaDownloadStatus:MVMediaDownloadStatusNone ofMedia:cameraMediaToRemove errorCode:0];
        [cameraMediaToRemove transactionWithBlock:^{
            cameraMediaToRemove.localPath = @"";
            cameraMediaToRemove.downloadedSize = 0;
        }];
        [cameraMediaToRemove update];
    }
    else
    {
        [media remove];
        //[[RealmSerialQueue shareRealmQueue] sync:^{
        //    RLMRealm* realm = [RLMRealm defaultRealm];
        //    [realm deleteObject:media];
        //}];
    }
}

- (void) stopDownloading:(MVMedia *)media {
    [self setMediaDownloadStatus:MVMediaDownloadStatusStopped ofMedia:media errorCode:0];
    MVDownloadTask* taskToRemove = [self taskOfMedia:media];
    if (taskToRemove)
    {
        //NSLog(@"#Bug3269#AFHTTPDownload#pause : stopDownloading OK , remove taskToRemove = %@", taskToRemove);
        [[MVCameraDownloadManager sharedInstance] removeTask:taskToRemove];
        [_downloadTasks removeObject:taskToRemove];
        [self enableCameraClientHeartbeatIfNecessary];
    }
    //else
    //{
    //    NSLog(@"#Bug3269#AFHTTPDownload#pause : stopDownloading NG @ %@", taskToRemove);
    //}
}
                             
- (void) stopDownloadingOfMedias:(NSArray<MVMedia* >*)medias {
    //NSLog(@"#Bug3269# stopDownloadingOfMedias : medias.count = %d", (int)medias.count);
    NSMutableArray<MVDownloadTask* >* tasksToRemove = [[NSMutableArray alloc] init];
    for (MVMedia* media in medias)
    {
        MVDownloadTask* taskToRemove = [self taskOfMedia:media];
        if (taskToRemove)
        {
            [tasksToRemove addObject:taskToRemove];
        }
    }
    //NSLog(@"#Bug3269# stopDownloadingOfMedias : remove tasksToRemove.count = %d", (int)tasksToRemove.count);
    
    NSLog(@"AFHTTPDownload#pause : stopDownloadingOfMedias, tasksToRemove = %@", tasksToRemove);
    [self setMediaDownloadStatus:MVMediaDownloadStatusStopped ofMedias:medias completion:nil];
    [[MVCameraDownloadManager sharedInstance] removeTasks:tasksToRemove];
    [_downloadTasks removeObjectsInArray:tasksToRemove];
    [self enableCameraClientHeartbeatIfNecessary];
}
                             
- (NSArray<MVMedia* >*) mediasWithDownloadStatus:(int)downloadStatusCombo {
    NSMutableArray<MVMedia* >* ret = [[NSMutableArray alloc] init];
    if (_cameraMedias)
    {
        @synchronized (self)
        {
            for (MVMedia* media in _cameraMedias)
            {
                if (0 != (downloadStatusCombo & media.downloadStatus))
                {
                    [ret addObject:media];
                }
            }
        }
    }
    return [NSArray arrayWithArray:ret];
}
                             
- (void) pauseAllDownloadings {
    //@synchronized (self)
    {
        _isDownloadingHanging = YES;
        NSArray<MVMedia* >* downloadingMedias = [self mediasWithDownloadStatus:(MVMediaDownloadStatusDownloading | MVMediaDownloadStatusPending)];
        [_hangingDownloadMedias addObjectsFromArray:downloadingMedias];
        
        [self sendCallbackMessage:MsgDownloadingsHung arg1:0 arg2:0 object:nil];
        
        [self stopDownloadingOfMedias:_hangingDownloadMedias];
        [self enableCameraClientHeartbeatIfNecessary];
    }
}
                             
- (void) resumeAllDownloadings {
    //@synchronized (self)
    {
        _isDownloadingHanging = NO;
        [self addDownloadingOfMedias:_hangingDownloadMedias completion:nil progressBlock:nil];
        [_hangingDownloadMedias removeAllObjects];
        [self enableCameraClientHeartbeatIfNecessary];
    }
}

- (NSArray<MVMedia* >*) mediasInDownloader {
    return [self mediasWithDownloadStatus:(MVMediaDownloadStatusStopped | MVMediaDownloadStatusPending | MVMediaDownloadStatusDownloading | MVMediaDownloadStatusError)];
}

- (NSArray<MVMedia*>*) cameraMediasAsync
{
    return [self cameraMedias:YES];
}

- (NSArray<MVMedia*>*) localMedias
{
    return [self localMedias:YES];
}

- (void) sendCallbackMessage:(int)what arg1:(NSInteger)arg1 arg2:(NSInteger)arg2 object1:(id)object1 object2:(id)object2 {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self handleMessage:what arg1:arg1 arg2:arg2 object1:object1 object2:object2];
    });
}
                                      
- (void) sendCallbackMessage:(int)what arg1:(NSInteger)arg1 arg2:(NSInteger)arg2 object:(id)object {
  dispatch_async(dispatch_get_main_queue(), ^{
      [self handleMessage:what arg1:arg1 arg2:arg2 object1:object object2:nil];
  });
}

- (void) onDownloadProgressUpdated:(MVMedia*)media downloadedBytes:(NSInteger)downloadedBytes totalBytes:(NSInteger)totalBytes {
    [self invalidateLocalMedias:NO];
    for (id<MVMediaDownloadStatusObserver> downloadObserver in _downloadStatusObservers)
    {
        //[self setMediaThummaryFetched:media];
        if ([downloadObserver respondsToSelector:@selector(didDownloadProgressChange:totalBytes:ofMedia:)])
        {
            [downloadObserver didDownloadProgressChange:downloadedBytes totalBytes:totalBytes ofMedia:media];
        }
    }
}

- (void) onDownloadStatusChanged:(MVMedia*)media downloadStatus:(int)downloadStatus errorCode:(int)errorCode {
    [self invalidateLocalMedias:NO];
    for (id<MVMediaDownloadStatusObserver> downloadObserver in _downloadStatusObservers)
    {
        //[self setMediaThummaryFetched:media];
        if ([downloadObserver respondsToSelector:@selector(didDownloadStatusChange:errorCode:ofMedia:)])
        {
            [downloadObserver didDownloadStatusChange:downloadStatus errorCode:errorCode ofMedia:media];
        }
    }
}
                                      
- (void) onBatchDownloadStatusChanged:(NSArray<MVMedia* >*)medias downloadStatus:(int)downloadStatus errorCode:(int)errorCode completion:(dispatch_block_t)completion {
    [self invalidateLocalMedias:NO];
    for (id<MVMediaDownloadStatusObserver> downloadObserver in _downloadStatusObservers)
    {
        if ([downloadObserver respondsToSelector:@selector(didBatchDownloadStatusChange:ofMedias:)])
        {
            [downloadObserver didBatchDownloadStatusChange:downloadStatus ofMedias:medias];
        }
    }
    if (medias && medias.count > 0 && completion)
    {
        completion();
    }
}
    
- (void) onDownloadingsHung {
    for (id<MVMediaDownloadStatusObserver> downloadObserver in _downloadStatusObservers)
    {
        if ([downloadObserver respondsToSelector:@selector(didDownloadingsHung)])
        {
            [downloadObserver didDownloadingsHung];
        }
    }
}

- (void) onCameraDataSourceUpdated:(NSArray<MVMedia* >*)medias dataSetEvent:(DataSetEvent)dataSetEvent errorCode:(int)errorCode {
    NSMutableArray<MVMedia* >* observers;
    @synchronized (self)
    {
        observers = [_dataSourceObservers mutableCopy];
    }
    
    MVCameraDevice* camera = [MVCameraClient sharedInstance].connectingCamera;
    if (0 < _cameraMedias.count)
    {
        if (1 == _cameraMedias.count && DataSetEventRefresh == dataSetEvent)
        {
            MVMedia* recentMedia = _cameraMedias[0];
            if (camera)
            {
                camera.recentMedia = recentMedia;
            }
            
            //NSLog(@"ThummaryRequested : onCameraDataSourceUpdated # getThumbnailImageOfRecentMedia : %@", recentMedia.storageKey);
            UIImage* recentThumbnail = [self getThumbnailImage:recentMedia];
            if (recentThumbnail)
            {DoctorLog(@"#FileIterator# MVMediaManager$onCameraDataSourceUpdated didFetchRecentMediaThumbnail");
                for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
                {
                    if ([dataSourceObserver respondsToSelector:@selector(didFetchRecentMediaThumbnail:image:error:)])
                    {
                        [dataSourceObserver didFetchRecentMediaThumbnail:recentMedia image:recentThumbnail error:0];
                    }
                }
            }
        }
    }
    else if (camera)
    {
        camera.recentMedia = nil;
        for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
        {
            if ([dataSourceObserver respondsToSelector:@selector(didFetchRecentMediaThumbnail:image:error:)])
            {
                [dataSourceObserver didFetchRecentMediaThumbnail:nil image:nil error:0];
            }
        }
    }
    //NSLog(@"ThummaryRequested : onCameraDataSourceUpdated # didCameraMediasReloaded : count=%ld", (long)medias.count);
    for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
    {
        if ([dataSourceObserver respondsToSelector:@selector(didCameraMediasReloaded:dataSetEvent:errorCode:)])
        {
            [dataSourceObserver didCameraMediasReloaded:medias dataSetEvent:dataSetEvent errorCode:errorCode];
        }
    }
}

- (void) onLocalDataSourceUpdated:(NSArray<MVMedia* >*)medias dataSetEvent:(DataSetEvent)dataSetEvent {
    NSMutableArray<MVMedia* >* observers;
    @synchronized (self)
    {
        observers = [_dataSourceObservers mutableCopy];
    }
    NSLog(@"#RLMDeadLock# onLocalDataSourceUpdated : Call didLocalMediasReloaded");
    for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
    {
        if ([dataSourceObserver respondsToSelector:@selector(didLocalMediasReloaded:dataSetEvent:)])
        {
            [dataSourceObserver didLocalMediasReloaded:medias dataSetEvent:dataSetEvent];
        }
    }
}

- (void) onThumbnailFetched:(MVMedia*)media error:(int)error {
    if (!media) return;
    
    [self invalidateLocalMedias:NO];
    
    NSMutableArray<MVMedia* >* observers;
    @synchronized (self)
    {
        observers = [_dataSourceObservers mutableCopy];
    }
    //NSLog(@"ThummaryRequested : onThumbnailFetched # getThumbnailImageOfMedia : %@", media.storageKey);
    UIImage* image = error ? nil : [self getThumbnailImage:media];
    
    if (_cameraMedias.count > 0 && [_cameraMedias[0] isEqualRemoteMedia:media])
    {NSLog(@"#RLMDeadLock# onThumbnailFetched#1 Call didFetchThumbnailImage on %@", media);
        MVCameraDevice* camera = [MVCameraClient sharedInstance].connectingCamera;
        if (camera)
        {
            camera.recentMedia = media;
        }
        DoctorLog(@"#FileIterator# MVMediaManager$onThumbnailFetched didFetchRecentMediaThumbnail");
        for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
        {
            //[self setMediaThummaryFetched:media];
            if ([dataSourceObserver respondsToSelector:@selector(didFetchThumbnailImage:ofMedia:error:)])
            {
                [dataSourceObserver didFetchThumbnailImage:image ofMedia:media error:error];
            }
            
            //[self setMediaThummaryFetched:media];
            if ([dataSourceObserver respondsToSelector:@selector(didFetchRecentMediaThumbnail:image:error:)])
            {
                [dataSourceObserver didFetchRecentMediaThumbnail:media image:image error:error];
            }
        }
    }
    else
    {NSLog(@"#RLMDeadLock# onThumbnailFetched#2 Call didFetchThumbnailImage on %@", media);
        for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
        {
            //[self setMediaThummaryFetched:media];
            if ([dataSourceObserver respondsToSelector:@selector(didFetchThumbnailImage:ofMedia:error:)])
            {
                [dataSourceObserver didFetchThumbnailImage:image ofMedia:media error:error];
            }
        }
    }
}

- (void) onMediaInfoFetched:(MVMedia*)media error:(int)error {
    //NSLog(@"ThummaryRequested : onMediaInfoFetched : %@", media.storageKey);
    [self invalidateLocalMedias:NO];
    
    NSMutableArray<MVMedia* >* observers;
    @synchronized (self)
    {
        observers = [_dataSourceObservers mutableCopy];
    }
    for (id<MVMediaDataSourceObserver> dataSourceObserver in observers)
    {
        //[self setMediaThummaryFetched:media];
        if ([dataSourceObserver respondsToSelector:@selector(didFetchMediaInfo:error:)])
        {
            [dataSourceObserver didFetchMediaInfo:media error:error];
        }
    }
}

- (void) onLowDiskSpace {
 NSLog(@"onLowDiskSpace");
 NSMutableArray<MVMedia* >* observers;
 @synchronized (self)
 {
     observers = [_downloadStatusObservers mutableCopy];
 }
 for (id<MVMediaDownloadStatusObserver> observer in observers)
 {
     if ([observer respondsToSelector:@selector(didReceiveStorageWarning)])
     {
         [observer didReceiveStorageWarning];
     }
 }
}
                             
- (void) handleMessage:(int)what arg1:(NSInteger)arg1 arg2:(NSInteger)arg2 object1:(id)object1 object2:(id)object2 {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (what)
        {
            case MsgDownloadProgressUpdated:
            {
                long downloadedBytes = (arg1 < 0 ? (1L << 32) + arg1 : arg1);
                long totalBytes = (arg2 < 0 ? (1L << 32) + arg2 : arg2);
                [self onDownloadProgressUpdated:(MVMedia*)object1 downloadedBytes:downloadedBytes totalBytes:totalBytes];
            }
                break;
            case MsgDownloadStatusChanged:
                if ([object1 isKindOfClass:NSArray.class])
                {
                    NSArray* medias = (NSArray*) object1;
                    dispatch_block_t completion = (dispatch_block_t) object2;
                    [self onBatchDownloadStatusChanged:medias downloadStatus:(int)arg1 errorCode:(int)arg2 completion:completion];
                }
                else if ([object1 isKindOfClass:MVMedia.class])
                {
                    [self onDownloadStatusChanged:(MVMedia*)object1 downloadStatus:(int)arg1 errorCode:(int)arg2];
                }
                break;
            case MsgDownloadingsHung:
                [self onDownloadingsHung];
                break;
            case MsgDataSourceCameraUpdated:
                [self onCameraDataSourceUpdated:(NSArray<MVMedia *> *)object1 dataSetEvent:(DataSetEvent)arg1 errorCode:(int)arg2];
                break;
            case MsgDataSourceLocalUpdated:
                [self onLocalDataSourceUpdated:(NSArray<MVMedia *> *)object1 dataSetEvent:(DataSetEvent)arg1];
                break;
            case MsgThumbnailFetched:
                [self onThumbnailFetched:(MVMedia*)object1 error:(int)arg1];
                break;
            case MsgMediaInfoFetched:
                [self onMediaInfoFetched:(MVMedia*)object1 error:(int)arg1];
                break;
            case MsgLowDiskSpace:
                [self onLowDiskSpace];
                break;
        }
    });
}

- (void) didConnectSuccess:(MVCameraDevice *)device {
    //NSLog(@"#Bug3269# didConnectSuccess : remove all");
    [_downloadTasks removeAllObjects];
    
    [_thummaryCond lock];
    {
        _isBusyFetchingThummary = NO;
        [_thummaryCond broadcast];
    }
    [_thummaryCond unlock];
    
    @synchronized (_thummaryFetchedTime)
    {
        [_thummaryFetchedTime removeAllObjects];
        [_fetchingThummaryMedias removeAllObjects];
        [_justCreatedMediaTime removeAllObjects];
    }
    
    [self enableCameraClientHeartbeatIfNecessary];
    ///!!![[MVCameraDownloadManager sharedInstance] removeAllTasks];//#Bug3752#
    [self stopCameraFilesIterating];
    if (device)
    {
        _cameraMediasInvalid = YES;
    }
}

@end
