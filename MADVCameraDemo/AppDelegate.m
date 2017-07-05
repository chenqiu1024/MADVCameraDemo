//
//  AppDelegate.m
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import "AppDelegate.h"
#import "MVCameraClient.h"
#import "MVMediaManager.h"

NSString* kNotificationAddNewMVMedia = @"kNotificationAddNewMVMedia";

NSString* kNotificationRefreshMVMedia = @"kNotificationRefreshMVMedia";

@interface AppDelegate () <MVCameraClientObserver, MVMediaDataSourceObserver, MVMediaDownloadStatusObserver>
{
    NSMutableDictionary<NSString*, NSMutableArray<MVMedia* >* >* _dataSet;
    
    NSArray<NSArray<MVMedia* >* >* _dataSetValuesCopy;
    NSArray<NSString* >* _dataSetKeysCopy;
    NSMutableDictionary<NSString*, NSIndexPath* >* _indexPathsOfMedia;
    
    NSString* _currentGroupName;
    BOOL _groupFinished;
}

- (NSMutableArray<MVMedia*> *) obtainMediaArrayOfGroup:(NSString*)groupName;

- (void) copyDataSet;

@end

static AppDelegate* s_singleton = nil;

@implementation AppDelegate

#pragma mark    MVCameraClientObserver

-(void) didConnectSuccess:(MVCameraDevice*) device {
    [[MVMediaManager sharedInstance] cameraMedias:YES];
}

- (void) willStopCapturing:(id)param {
    if (param && [param intValue] == 1)
    {
        _groupFinished = YES;
    }
}

-(void) didEndShooting:(NSString *)remoteFilePath error:(int)error errMsg:(NSString *)errMsg {
    //TODO:
}

- (void)didStopShooting:(int)error {
}

#pragma mark    MVMediaDataSourceObserver

-(void)didCameraMediasReloaded:(NSArray<MVMedia *> *) medias dataSetEvent:(DataSetEvent)dataSetEvent errorCode:(int)errorCode {
    if (DataSetEventAddNew == dataSetEvent && medias.count > 0)
    {
        if (!_currentGroupName)
        {
            _currentGroupName = [[NSDate date] description];
        }
        
        NSMutableArray<MVMedia*>* mediaArray = [self obtainMediaArrayOfGroup:_currentGroupName];
        [mediaArray addObject:medias[0]];
        
        if (_groupFinished)
        {
            _currentGroupName = nil;
            _groupFinished = NO;
        }
        
        [[MVMediaManager sharedInstance] addDownloading:medias[0]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddNewMVMedia object:medias];
    }
}

-(void)didFetchThumbnailImage:(UIImage *)image ofMedia:(MVMedia*)media error:(int)error {
    [self reloadCellOfMedia:media];
}

/**
 * 异步获取媒体信息的回调
 * @param media 获取到媒体信息的媒体对象，可以从其中用get方法读取视频时长等信息
 */
-(void)didFetchMediaInfo:(MVMedia *)media error:(int)error {
    [self reloadCellOfMedia:media];
}

/** 异步获取到最近拍摄的一个媒体文件的缩略图
 * @param media 获取到媒体信息的媒体对象，可以从其中用get方法读取视频时长等信息
 * @param image 缩略图UIImage对象
 */
- (void) didFetchRecentMediaThumbnail:(MVMedia*)media image:(UIImage*)image error:(int)error {
    
}

#pragma mark    MVMediaDownloadStatusObserver

- (void) didDownloadStatusChange:(int)downloadStatus errorCode:(int)errorCode ofMedia:(MVMedia*)media {
    [self reloadCellOfMedia:media];
}

/** 多项媒体文件的下载状态发生批量变化（发生在下载管理页面用户批量操作时）
 *
 */
- (void) didBatchDownloadStatusChange:(int)downloadStatus ofMedias:(NSArray<MVMedia *>*)medias {
    [self reloadCellOfMedias:medias];
}

/** 下载进度通知回调
 * media: 发生下载进度变化的媒体对象
 */
- (void) didDownloadProgressChange:(NSInteger)downloadedBytes totalBytes:(NSInteger)totalBytes ofMedia:(MVMedia*)media {
    [self reloadCellOfMedia:media];
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
    [self copyDataSet];
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

- (void) reloadCellOfMedia:(MVMedia*)media {
    if (_indexPathsOfMedia)
    {
        NSIndexPath* indexPath = [_indexPathsOfMedia objectForKey:media.remotePath];
        if (indexPath)
        {
//            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshMVMedia object:@[indexPath]];
        }
    }
}

- (void) reloadCellOfMedias:(NSArray<MVMedia* >*)medias {
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
//            [self.collectionView reloadItemsAtIndexPaths:indexPaths];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshMVMedia object:indexPaths];
        }
    }
}

- (void) copyDataSet {
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
        int section = 0, row = 0;
        for (NSString* key in _dataSet.keyEnumerator)
        {
            [keys addObject:key];
            NSMutableArray<MVMedia* >* valuesOfKey = [_dataSet objectForKey:key];
            [values addObject:[NSArray arrayWithArray:valuesOfKey]];
            
            row = 0;
            for (MVMedia* media in valuesOfKey)
            {
                NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row++ inSection:section];
                [_indexPathsOfMedia setObject:indexPath forKey:media.remotePath];
            }
            section++;
        }
        _dataSetKeysCopy = keys;
        _dataSetValuesCopy = values;
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    s_singleton = self;
    
    _currentGroupName = nil;
    _groupFinished = NO;
    
    _dataSet = [[NSMutableDictionary alloc] init];
    _dataSetValuesCopy = nil;
    _dataSetKeysCopy = nil;
    _indexPathsOfMedia = nil;
    
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    int32_t intTime = (int32_t)time;
    seed48((unsigned short*) &intTime);
    
    [[MVCameraClient sharedInstance] addObserver:self];
    [[MVMediaManager sharedInstance] addMediaDataSourceObserver:self];
    [[MVMediaManager sharedInstance] addMediaDownloadStatusObserver:self];
    
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