//
//  AMBAGetFileRequest.m
//  Madv360_v1
//
//  Created by DOM QIU on 16/9/16.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "AMBAGetFileRequest.h"
#import "AMBAGetFileResponse.h"

@implementation AMBAGetFileRequest

- (instancetype) initWithReceiveBlock:(AMBAResponseReceivedBlock)receiveBlock errorBlock:(AMBAResponseErrorBlock)errorBlock {
    if (self = [super initWithReceiveBlock:receiveBlock errorBlock:errorBlock responseClass:AMBAGetFileResponse.class])
    {
        
    }
    return self;
}

+ (NSDictionary*) mj_replacedKeyFromPropertyName {
    static NSDictionary* dict = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary* tmpDict = [[AMBAResponse mj_replacedKeyFromPropertyName] mutableCopy];
        [tmpDict addEntriesFromDictionary:@{@"fetchSize":@"fetch_size"}];
        dict = [NSDictionary dictionaryWithDictionary:tmpDict];
    });
    return dict;
}

@end
