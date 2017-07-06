//
//  AppDelegate.h
//  MADVCameraDemo
//
//  Created by DOM QIU on 2017/7/4.
//  Copyright © 2017年 MADV. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString* kNotificationAddNewMVMedia;

extern NSString* kNotificationRefreshMVMedia;

@class MVMedia;

@protocol MovieSegmentsMerger

-(void) mergeVideoSegments:(NSArray<NSString* >*)segmentPaths intoFile:(NSString*)filePath progressHandler:(void(^)(int))progressHandler completionHandler:(void(^)())completionHandler;

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (instancetype) sharedApplication;

- (NSInteger) numberOfSections;

- (NSInteger) numberOfMediasInSection:(NSInteger)section;

- (NSString*) groupNameOfIndexPath:(NSIndexPath*)indexPath;

- (MVMedia*) mvMediaOfIndexPath:(NSIndexPath*)indexPath;

@end

