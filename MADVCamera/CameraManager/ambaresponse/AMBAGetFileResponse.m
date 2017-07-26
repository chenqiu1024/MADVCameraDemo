//
//  AMBAGetFileResponse.m
//  Madv360_v1
//
//  Created by DOM QIU on 16/9/16.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "AMBAGetFileResponse.h"

@implementation AMBAGetFileResponse

+ (NSDictionary*) mj_replacedKeyFromPropertyName {
    static NSMutableDictionary* dict = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dict = [[AMBAResponse mj_replacedKeyFromPropertyName] mutableCopy];
        [dict addEntriesFromDictionary:@{@"siRemSize":@"rem_size", @"siSize":@"size"}];
    });
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (NSInteger) remSize {
    if (self.siRemSize < 0)
        return (1L << 32) + self.siRemSize;
    else
        return self.siRemSize;
}

- (NSInteger) size {
    if (self.siSize < 0)
        return (1L << 32) + self.siSize;
    else
        return self.siSize;
}

@end
