//
//  AMBAGetMediaInfoResponse.h
//  Madv360_v1
//
//  Created by QiuDong on 16/10/11.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "AMBAResponse.h"

// '{"rval":0,"msg_id":1026,"size":37748736,"date":"2017-01-01 20:46:24","resolution":"2304x1152","duration":6,"media_type":"mov"}'
@interface AMBAGetMediaInfoResponse : AMBAResponse

@property (nonatomic, assign) int duration;

@property (nonatomic, assign) NSInteger jsonSize;

@property (nonatomic, copy) NSString* media_type;

@property (nonatomic, assign) int scene_type;

@property (nonatomic, copy) NSString* gyro;

- (NSInteger) size;

@end
