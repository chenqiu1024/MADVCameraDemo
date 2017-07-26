//
//  AMBARequest.m
//  Madv360_v1
//
//  Created by DOM QIU on 16/9/5.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "AMBARequest.h"
#import "AMBAResponse.h"

@interface AMBARequest ()
{
    Class _responseClass;
}
// 响应对象的类别（isKindOf AMBAResponse.class）
@property (nonatomic, strong) Class responseClass;

@end

@implementation AMBARequest

+ (NSArray*) mj_ignoredPropertyNames {
    return @[@"shouldWaitUntilPreviousResponded", @"timestamp", @"timeout", @"requestKey", @"responseClass", @"ambaResponseReceived", @"ambaResponseError", @"ambaRequestSent"];
}

+ (NSDictionary*) mj_replacedKeyFromPropertyName {
    return @{@"msgID":@"msg_id"};
}

- (instancetype) initWithReceiveBlock:(AMBAResponseReceivedBlock)receiveBlock errorBlock:(AMBAResponseErrorBlock)errorBlock responseClass:(Class)responseClass {
    if (self = [super init])
    {
        self.btwifi = 2;
        
        self.ambaResponseError = errorBlock;
        self.ambaResponseReceived = receiveBlock;
        self.responseClass = responseClass;
        
        self.shouldWaitUntilPreviousResponded = YES;
        
        self.timeout = 0;
    }
    return self;
}

- (instancetype) initWithReceiveBlock:(AMBAResponseReceivedBlock)receiveBlock errorBlock:(AMBAResponseErrorBlock)errorBlock {
    if (self = [self initWithReceiveBlock:receiveBlock errorBlock:errorBlock responseClass:AMBAResponse.class])
    {
    }
    return self;
}

- (Class) responseClass {
    return _responseClass;
}

- (void) setResponseClass:(Class)responseClass {
    _responseClass = responseClass;
}

- (NSString*) requestKey {
    return [@(self.msgID) stringValue];
}

@end
