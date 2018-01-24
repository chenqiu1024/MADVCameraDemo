//
//  AppDelegate.m
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import "AppDelegate.h"
#import <MADVCamera/MVCameraClient.h>
#import "MVMediaManager.h"
#import "MyMovieSegmentMerger.h"
#import "MadvGLRenderer_iOS.h"
#import "MVMediaPlayerViewController.h"

#define MADV_DUAL_FISHEYE_VIDEO_TAG @"MADV_DUAL_FISHEYE_VIDEO"
NSString* kNotificationAddNewMVMedia = @"kNotificationAddNewMVMedia";

NSString* kNotificationRefreshMVMedia = @"kNotificationRefreshMVMedia";

NSString* kNotificationMergingMVMedia = @"kNotificationMergingMVMedia";

NSString* kNotificationMergingMVMediaProgress = @"kNotificationMergingMVMediaProgress";

NSString* kNotificationMergingMVMediaCompleted = @"kNotificationMergingMVMediaCompleted";

NSString* FORGED_MEDIA_TAG = @"[FORGED]";

@interface AppDelegate () <MVCameraClientObserver, MVMediaDataSourceObserver, MVMediaDownloadStatusObserver, MovieSegmentsMerger/*For Unit Test*/>
{
    NSMutableDictionary<NSString*, NSMutableArray<MVMedia* >* >* _dataSet;
    
    NSArray<NSArray<MVMedia* >* >* _dataSetValuesCopy;
    NSArray<NSString* >* _dataSetKeysCopy;
    NSMutableDictionary<NSString*, NSIndexPath* >* _indexPathsOfMedia;
    
    NSString* _currentGroupName;
    BOOL _groupFull;
    NSMutableSet<NSString* >* _filledGroups;
}

- (NSMutableArray<MVMedia*> *) obtainMediaArrayOfGroup:(NSString*)groupName;

- (void) copyDataSet:(NSSet<NSString* >*)knownCompletedGroupNames;

- (NSString*) checkIfGroupCompletelyDownloadedByIndexPath:(NSIndexPath*)indexPath;
- (NSString*) checkIfGroupCompletelyDownloaded:(MVMedia*)segmentMedia;

@end

static AppDelegate* s_singleton = nil;

@implementation AppDelegate

#pragma mark    MovieSegmentsMerger

-(void) mergeVideoSegments:(NSArray<NSString *> *)segmentPaths intoFile:(NSString *)filePath progressHandler:(void (^)(int))progressHandler completionHandler:(void (^)())completionHandler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        MyMovieSegmentMerger* myMerger = [[MyMovieSegmentMerger alloc] init];
        
        void(^successBlock)() = ^(void){};
        void(^failureBlock)() = ^(void){};
        
        //[myMerger mergeVideoToOneVideo:segmentPaths intoFile:filePath andIf3D:NO success:successBlock failure:failureBlock timeToCutFromEndInSec:(DOUYIN_T2_VIDEO_MILLS / 1000.f)];
        [myMerger mergeVideoToOneVideo:segmentPaths intoFile:filePath andIf3D:NO success:successBlock failure:failureBlock timeToCutFromEndInSec:0.f];
        
        for (int i=0; i<100; ++i)
        {
            NSLog(@"#Merging# Call progressHandler %d", i);
            if (progressHandler)
            {
                progressHandler(i);
            }
            
            [NSThread sleepForTimeInterval:0.1f];
        }
        
        NSLog(@"#Merging# Call completionHandler");
        if (completionHandler)
        {
            completionHandler();
        }
    });
}

#pragma mark    MVCameraClientObserver

-(void) didConnectSuccess:(MVCameraDevice*) device {
    ///!!![[MVMediaManager sharedInstance] cameraMedias:YES];
}

- (void) willStopCapturing:(id)param {
    if (param && [param intValue] == 1)
    {
        _groupFull = YES;
    }
}

- (void)didStopShooting:(int)error {
}

#pragma mark    MVMediaDataSourceObserver

-(void)didCameraMediasReloaded:(NSArray<MVMedia *> *) medias dataSetEvent:(DataSetEvent)dataSetEvent errorCode:(int)errorCode {
    if (DataSetEventAddNew == dataSetEvent && medias.count > 0)
    {
        if (!_currentGroupName)
        {
            NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = @"yyyyMMdd_hhmmss";
            _currentGroupName = [dateFormatter stringFromDate:[NSDate date]];
        }
        
        NSMutableArray<MVMedia*>* mediaArray = [self obtainMediaArrayOfGroup:_currentGroupName];
        [mediaArray addObject:medias[0]];
        
        if (_groupFull)
        {
            [_filledGroups addObject:_currentGroupName];
            _currentGroupName = nil;
            _groupFull = NO;
        }
        
        [[MVMediaManager sharedInstance] addDownloading:medias[0]];
        
        [self copyDataSet:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddNewMVMedia object:medias];
    }
}

-(void)didFetchThumbnailImage:(UIImage *)image ofMedia:(MVMedia*)media error:(int)error {
    [self reloadCellOfMedia:media checkIfGroupDownloaded:NO];
}

/**
 * 异步获取媒体信息的回调
 * @param media 获取到媒体信息的媒体对象，可以从其中用get方法读取视频时长等信息
 */
-(void)didFetchMediaInfo:(MVMedia *)media error:(int)error {
    [self reloadCellOfMedia:media checkIfGroupDownloaded:NO];
}

/** 异步获取到最近拍摄的一个媒体文件的缩略图
 * @param media 获取到媒体信息的媒体对象，可以从其中用get方法读取视频时长等信息
 * @param image 缩略图UIImage对象
 */
- (void) didFetchRecentMediaThumbnail:(MVMedia*)media image:(UIImage*)image error:(int)error {
    
}

#pragma mark    MVMediaDownloadStatusObserver

- (void) didDownloadStatusChange:(int)downloadStatus errorCode:(int)errorCode ofMedia:(MVMedia*)media {
    NSLog(@"#Merging# didDownloadStatusChange:%d errorCode:%d ofMedia:%@", downloadStatus, errorCode, media);
    [self reloadCellOfMedia:media checkIfGroupDownloaded:YES];
}

/** 多项媒体文件的下载状态发生批量变化（发生在下载管理页面用户批量操作时）
 *
 */
- (void) didBatchDownloadStatusChange:(int)downloadStatus ofMedias:(NSArray<MVMedia *>*)medias {
    [self reloadCellOfMedias:medias checkIfGroupDownloaded:YES];
}

/** 下载进度通知回调
 * media: 发生下载进度变化的媒体对象
 */
- (void) didDownloadProgressChange:(NSInteger)downloadedBytes totalBytes:(NSInteger)totalBytes ofMedia:(MVMedia*)media {
    [self reloadCellOfMedia:media checkIfGroupDownloaded:NO];
}

#pragma mark    Public

+ (instancetype) sharedApplication {
    return s_singleton;
}

- (NSInteger) numberOfMediasInSection:(NSInteger)section {
    if (!_dataSetValuesCopy || 0 == _dataSetValuesCopy.count || section >= _dataSetValuesCopy.count)
        return 0;
    
    NSArray* medias = _dataSetValuesCopy[section];
    if (!medias)
        return 0;
    
    return medias.count;
}

- (NSInteger) numberOfSections {
    return _dataSetKeysCopy ? _dataSetKeysCopy.count : 0;
}

- (NSString*) groupNameOfIndexPath:(NSIndexPath*)indexPath {
    NSString* groupName = [_dataSetKeysCopy objectAtIndex:indexPath.section];
    return groupName;
}

- (MVMedia*) mvMediaOfIndexPath:(NSIndexPath*)indexPath {
    NSArray<MVMedia* >* mediasOfGroup = [_dataSetValuesCopy objectAtIndex:indexPath.section];
    MVMedia* media = [mediasOfGroup objectAtIndex:indexPath.row];
    return media;
}

#pragma mark    Private

- (NSMutableArray<MVMedia*> *) obtainMediaArrayOfGroup:(NSString*)groupName {
    NSMutableArray<MVMedia*>* mediaArray = [_dataSet objectForKey:groupName];
    if (!mediaArray)
    {
        mediaArray = [[NSMutableArray alloc] init];
        [_dataSet setObject:mediaArray forKey:groupName];
    }
    return mediaArray;
}

- (void) reloadCellOfMedia:(MVMedia*)media checkIfGroupDownloaded:(BOOL)checkIfGroupDownloaded {
    if (_indexPathsOfMedia)
    {
        NSIndexPath* indexPath = [_indexPathsOfMedia objectForKey:media.remotePath];
        if (indexPath)
        {
            if (checkIfGroupDownloaded)
            {
                NSString* completedGroupName = [self checkIfGroupCompletelyDownloadedByIndexPath:indexPath];
                if (completedGroupName)
                {
                    NSSet* knownCompletedGroupNames = [NSSet setWithObjects:completedGroupName, nil];
                    [self copyDataSet:knownCompletedGroupNames];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMergingMVMedia object:knownCompletedGroupNames];
                    return;
                }
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshMVMedia object:@[indexPath]];
        }
    }
}

- (void) reloadCellOfMedias:(NSArray<MVMedia* >*)medias checkIfGroupDownloaded:(BOOL)checkIfGroupDownloaded {
    if (_indexPathsOfMedia)
    {
        NSMutableArray<NSString* >* keys = [[NSMutableArray alloc] init];
        for (MVMedia* media in medias)
        {
            [keys addObject:media.remotePath];
        }
        NSArray<NSIndexPath* >* indexPaths = [_indexPathsOfMedia objectsForKeys:keys notFoundMarker:[NSIndexPath indexPathForRow:NSNotFound inSection:NSNotFound]];
        if (indexPaths)
        {
            if (checkIfGroupDownloaded)
            {
                NSMutableSet<NSString* >* knownCompletedGroupNames = [[NSMutableSet alloc] init];
                for (NSIndexPath* indexPath in indexPaths)
                {
                    NSString* completedGroupName = [self checkIfGroupCompletelyDownloadedByIndexPath:indexPath];
                    if (completedGroupName)
                    {
                        [knownCompletedGroupNames addObject:completedGroupName];
                    }
                }
                if (knownCompletedGroupNames.count > 0)
                {
                    [self copyDataSet:knownCompletedGroupNames];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMergingMVMedia object:knownCompletedGroupNames];
                    return;
                }
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshMVMedia object:indexPaths];
        }
    }
}

- (NSString*) checkIfGroupCompletelyDownloadedByIndexPath:(NSIndexPath*)indexPath {
    if (indexPath)
    {
        NSString* groupName = [_dataSetKeysCopy objectAtIndex:indexPath.section];
        if (![_filledGroups containsObject:groupName])
            return nil;
        
        NSArray<MVMedia* >* mediasOfGroup = [_dataSetValuesCopy objectAtIndex:indexPath.section];
        if (!mediasOfGroup || 0 == mediasOfGroup.count)
            return nil;
        
        MVMedia* lastMedia = [mediasOfGroup lastObject];
        if ([lastMedia.cameraUUID isEqualToString:FORGED_MEDIA_TAG])
            return nil;
        
        for (MVMedia* media in mediasOfGroup)
        {
            if (0 == media.size || media.downloadedSize < media.size)
                return nil;
        }
        ///!!!For Debug:
        NSLog(@"#Merging# checkIfGroupCompletelyDownloadedByIndexPath passed. All medias in group:\n#Merging# {");
        for (MVMedia* media in mediasOfGroup)
        {
            NSLog(@"#Merging# media: %@", media);
        }
        NSLog(@"#Merging# }");
        
        return groupName;
    }
    return nil;
}

- (NSString*) checkIfGroupCompletelyDownloaded:(MVMedia*)segmentMedia {
    if (_indexPathsOfMedia)
    {
        NSIndexPath* indexPath = [_indexPathsOfMedia objectForKey:segmentMedia.remotePath];
        return [self checkIfGroupCompletelyDownloadedByIndexPath:indexPath];
    }
    return nil;
}

- (void) copyDataSet:(NSSet<NSString* >*)knownCompletedGroupNames {
    if (!_dataSet || 0 == _dataSet.count)
    {
        _dataSetValuesCopy = nil;
        _dataSetKeysCopy = nil;
        _indexPathsOfMedia = nil;
    }
    else
    {
        _indexPathsOfMedia = [[NSMutableDictionary alloc] init];
        NSMutableArray<NSString* >* keys = [[NSMutableArray alloc] init];
        NSMutableArray<NSArray<MVMedia* >* >* values = [[NSMutableArray alloc] init];
        __block int section = 0, row;
        [_dataSet enumerateKeysAndObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString * _Nonnull key, NSMutableArray<MVMedia *> * _Nonnull valuesOfKey, BOOL * _Nonnull stop) {
            [keys addObject:key];
            row = 0;
            
            //NSMutableArray<MVMedia* >* valuesOfKey = [_dataSet objectForKey:key];
            MVMedia* lastMedia = [valuesOfKey lastObject];
            BOOL allJustDownloaded = [_filledGroups containsObject:key] && ![lastMedia.cameraUUID isEqualToString:FORGED_MEDIA_TAG];
            
            for (MVMedia* media in valuesOfKey)
            {
                if (allJustDownloaded && (0 == media.size || media.downloadedSize < media.size))
                {
                    allJustDownloaded = NO;
                }
                
                NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row++ inSection:section];
                [_indexPathsOfMedia setObject:indexPath forKey:media.remotePath];
            }
            // Check if any group has all its medias completely downloaded, if so, append a stub MVMedia object representing the merging product:
            if (allJustDownloaded || (knownCompletedGroupNames && [knownCompletedGroupNames containsObject:key]))
            {
                ///!!!For Debug
                NSLog(@"#Merging# Check group completion passed. allJustDownloaded = %d, key='%@', knownCompletedGroupNames=%@\n#Merging# All medias in group:\n#Merging# {", allJustDownloaded, key, knownCompletedGroupNames);
                for (MVMedia* media in valuesOfKey)
                {
                    NSLog(@"#Merging# media: %@", media);
                }
                NSLog(@"#Merging# }");
                
                MVMedia* mergedMedia = [MVMedia createWithCameraUUID:FORGED_MEDIA_TAG remoteFullPath:key];
                mergedMedia.mediaType = MVMediaTypeVideo;
                mergedMedia.localPath = [[key stringByAppendingString:MADV_DUAL_FISHEYE_VIDEO_TAG] stringByAppendingPathExtension:@"mp4"];
                mergedMedia.size = 100;
                mergedMedia.downloadedSize = 0;//Percent of merging
                
                [valuesOfKey addObject:mergedMedia];
                
                NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row++ inSection:section];
                [_indexPathsOfMedia setObject:indexPath forKey:mergedMedia.remotePath];
                
                if (self.movieMerger)
                {
                    NSString* docDirPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
                    NSMutableArray<NSString* >* segmentFilePaths = [[NSMutableArray alloc] init];
                    for (NSInteger i=0; i<valuesOfKey.count-1; ++i)
                    {
                        MVMedia* segmentMedia = [valuesOfKey objectAtIndex:i];
                        NSString* segmentFilePath = [docDirPath stringByAppendingPathComponent:segmentMedia.localPath];
                        [segmentFilePaths addObject:segmentFilePath];
                    }
                    NSString* mergedFilePath = [docDirPath stringByAppendingPathComponent:mergedMedia.localPath];
                    [self.movieMerger mergeVideoSegments:segmentFilePaths intoFile:mergedFilePath progressHandler:^(int percent) {
                        NSLog(@"#Merging# In progressHandler : %d", percent);
#ifdef EXPORT_MERGED_VIDEO
                        mergedMedia.downloadedSize = percent / 2;
#else //#ifdef EXPORT_MERGED_VIDEO
                        mergedMedia.downloadedSize = percent;
#endif //#ifdef EXPORT_MERGED_VIDEO
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSIndexPath* theIndexPath = [_indexPathsOfMedia objectForKey:mergedMedia.remotePath];
                            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMergingMVMediaProgress object:theIndexPath];
                        });
                    } completionHandler:^{
                        NSLog(@"#Merging# In completionHandler");
#ifdef EXPORT_MERGED_VIDEO
                        mergedMedia.downloadedSize = 50;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __block MVMediaPlayerViewController* encoderVC;
                            MVMediaPlayerViewController* vc = [MVMediaPlayerViewController showEncoderControllerFrom:[AppDelegate sharedApplication].window.rootViewController media:mergedMedia qualityLevel:QualityLevel4K progressBlock:^(int percent) {
                                NSLog(@"#VideoExport# progressBlock : percent=%d", percent);
                                mergedMedia.downloadedSize = 50 + percent / 2;
                            } doneBlock:^(NSString* outputFilePath, NSError* error) {
                                NSLog(@"#VideoExport# doneBlock : outputFilePath=%@, error=%@", outputFilePath, error);
                                mergedMedia.downloadedSize = 100;
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSIndexPath* theIndexPath = [_indexPathsOfMedia objectForKey:mergedMedia.remotePath];
                                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMergingMVMediaCompleted object:theIndexPath];
                                    
                                    [encoderVC dismissViewControllerAnimated:YES completion:nil];
                                });
                            }];
                            encoderVC = vc;
                        });
#else
                        mergedMedia.downloadedSize = 100;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSIndexPath* theIndexPath = [_indexPathsOfMedia objectForKey:mergedMedia.remotePath];
                            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMergingMVMediaCompleted object:theIndexPath];
                        });
#endif
                    }];
                }
            }
            
            [values addObject:[NSArray arrayWithArray:valuesOfKey]];
            section++;
        }];
        _dataSetKeysCopy = keys;
        _dataSetValuesCopy = values;
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    s_singleton = self;
    
    _currentGroupName = nil;
    _groupFull = NO;
    _filledGroups = [[NSMutableSet alloc] init];
    
    _dataSet = [[NSMutableDictionary alloc] init];
    _dataSetValuesCopy = nil;
    _dataSetKeysCopy = nil;
    _indexPathsOfMedia = nil;
    
    [[MVCameraClient sharedInstance] addObserver:self];
    [[MVMediaManager sharedInstance] addMediaDataSourceObserver:self];
    [[MVMediaManager sharedInstance] addMediaDownloadStatusObserver:self];
    
    //For Unit Test Only:
    self.movieMerger = self;
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
