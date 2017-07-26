//
//  AMBAGetMediaInfoResponse.m
//  Madv360_v1
//
//  Created by QiuDong on 16/10/11.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "AMBAGetMediaInfoResponse.h"

@implementation AMBAGetMediaInfoResponse

+ (NSArray*) mj_ignoredPropertyNames {
    return [AMBAResponse mj_ignoredPropertyNames];
}

+ (NSDictionary*) mj_replacedKeyFromPropertyName {
    static NSDictionary* dict = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary* tmpDict = [[AMBAResponse mj_replacedKeyFromPropertyName] mutableCopy];
        [tmpDict addEntriesFromDictionary:@{@"jsonSize":@"size"}];
        dict = [NSDictionary dictionaryWithDictionary:tmpDict];
    });
    return dict;
}

- (NSInteger) size {
    if (self.jsonSize < 0)
        return (1L << 32) + self.jsonSize;
    else
        return self.jsonSize;
}

@end
