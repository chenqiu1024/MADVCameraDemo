//
//  AMBACancelFileTransferResponse.m
//  Madv360_v1
//
//  Created by DOM QIU on 16/9/16.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "AMBACancelFileTransferResponse.h"

@implementation AMBACancelFileTransferResponse

- (NSString*) md5 {
    return @"N/A";
}

- (NSInteger) bytesSent {
    return self.transferred_size;
}

@end
