//
//  MyMovieSegmentMerger.h
//  MADVCameraDemo
//
//  Created by Nuo Chen on 2017/07/07.
//  Copyright © 2017年 MADV. All rights reserved.
//

#ifndef MyMovieSegmentMerger_h
#define MyMovieSegmentMerger_h

#import "AppDelegate.h"

#import <AVFoundation/AVFoundation.h>
//#import <AVFoundation/AVAudioSession.h>

@interface MyMovieSegmentMerger : NSObject
-(void)mergeVideoToOneVideo:(NSArray *)tArray toStorePath:(NSString *)storePath WithStoreName:(NSString *)storeName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok;
-(void)mergeVideoToOneVideo:(NSArray *)tArray intoFile:(NSString *)intoFile andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok;
-(AVMutableComposition *)mergeVideostoOnevideo:(NSArray*)array;
-(NSURL *)joinStorePaht:(NSString *)sPath togetherStoreName:(NSString *)sName;
-(void)storeAVMutableComposition:(AVMutableComposition*)mixComposition withStoreUrl:(NSURL *)storeUrl andVideoUrl:(NSURL *)videoUrl WihtName:(NSString *)aName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok;
@end

#endif /* MyMovieSegmentMerger_h */
