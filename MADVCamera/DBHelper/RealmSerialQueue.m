//
//  RealmQueue.m
//  Madv360_v1
//
//  Created by 张巧隔 on 16/10/9.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "RealmSerialQueue.h"
#import "NSRecursiveCondition.h"
#import "NSMutableArray+Extensions.h"

@interface AsyncBlockTask : NSObject
{
    BOOL _isFinished;
    dispatch_block_t _block;
    NSThread* _myThread;
}

@property (nonatomic, assign) BOOL isFinished;
@property (nonatomic, strong) dispatch_block_t block;

- (instancetype) initWithBlock:(dispatch_block_t)block;

- (void) waitForFinishing:(NSRecursiveCondition*)cond;

@end

@implementation AsyncBlockTask

@synthesize isFinished = _isFinished;
@synthesize block = _block;

- (instancetype) initWithBlock:(dispatch_block_t)block {
    if (self = [super init])
    {
        _isFinished = NO;
        _block = block;
        
        _myThread = [NSThread currentThread];
    }
    return self;
}

- (void) waitForFinishing:(NSRecursiveCondition*)cond {
    [cond lock];
    {
        while (!_isFinished)
        {
            //NSLog(@"#RLMDeadLock# waitForFinishing WAITing @ %@, cond=%@", self, cond);
            [cond wait];
        }
    }
    //NSLog(@"#RLMDeadLock# waitForFinishing WokeUp @ %@, cond=%@", self, cond);
    [cond unlock];
}

@end

@interface RealmSerialQueue ()
{
    NSThread* _thread;
    NSRecursiveCondition* _cond;
    NSMutableArray<AsyncBlockTask*>* _tasks;
    BOOL _isRunning;
}

@end


@implementation RealmSerialQueue

- (void) dealloc {
    [self finish];
}

- (instancetype) init {
    if (self = [super init])
    {
        _tasks = [[NSMutableArray alloc] init];
        _isRunning = YES;
        _cond = [[NSRecursiveCondition alloc] init];
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(process:) object:nil];
        _thread.name = @"RealmSerailQueue";
        [_thread start];
    }
    return self;
}

+ (id)shareRealmQueue
{
    static dispatch_once_t once;
    static RealmSerialQueue* instance = nil;
    dispatch_once(&once, ^{
        if (instance == nil)
        {
            instance = [[RealmSerialQueue alloc] init];
            instance.realmQueue = dispatch_queue_create("Realm", DISPATCH_QUEUE_SERIAL);
        }
    });
    return instance;
}

- (void) addTask:(AsyncBlockTask*)task {
    //NSArray* callbackStacktrace = [NSThread callStackSymbols];
    //NSLog(@"#RLMDeadLock# addTask #0");/// in %@", callbackStacktrace);
    [_cond lock];
    {
        //NSLog(@"#RLMDeadLock# addTask #1 : cond=%@", _cond);
        [_tasks addObject:task];
        //NSLog(@"#RLMDeadLock# addTask #2 : _tasks(%lx).count = %d, task = %@", (long)_tasks.hash, (int)_tasks.count, task);
        [_cond broadcast];
        //NSLog(@"#RLMDeadLock# addTask #3");
    }
    [_cond unlock];
}

- (void)async:(dispatch_block_t)asyncblock
{
#ifndef DEBUG_DISABLE_REALM
    AsyncBlockTask* task = [[AsyncBlockTask alloc] initWithBlock:asyncblock];
    [self addTask:task];
#else
    asyncblock();
#endif
}

- (void)sync:(dispatch_block_t)syncblock
{
#ifndef DEBUG_DISABLE_REALM
    NSThread* realmThread = [[RealmSerialQueue shareRealmQueue] myThread];
    NSThread* currentThread = [NSThread currentThread];
    if (realmThread == currentThread)
    {
#endif
        syncblock();
#ifndef DEBUG_DISABLE_REALM
    }
    else
    {
        AsyncBlockTask* task = [[AsyncBlockTask alloc] initWithBlock:syncblock];
        [self addTask:task];
        [task waitForFinishing:_cond];
    }
#endif
}

- (void) finish {
    [_cond lock];
    {
        _isRunning = NO;
        [_cond broadcast];
    }
    [_cond unlock];
}

- (void) process:(id)object {
    while (_isRunning)
    {
        AsyncBlockTask* task = nil;
        [_cond lock];
        {
            while (_isRunning && _tasks.count == 0)
            {
                //NSLog(@"#RLMDeadLock# wait #0, _isRunning=%d, _tasks(%lx).count=%d", _isRunning, (long)_tasks.hash, (int)_tasks.count);
                [_cond wait];
            }
            //NSLog(@"#RLMDeadLock# After wait #1");
            
            if (!_isRunning)
            {
                for (AsyncBlockTask* task in _tasks)
                {
//                    NSLog(@"RLMDeadLock : process In Bunch Waking up @ %@", task);
                    task.isFinished = YES;
                }
                [_cond broadcast];
                
                [_cond unlock];
                break;
            }
            
            task = [_tasks poll];
        }
        [_cond unlock];
        
        if (task)
        {
            if (task.block)
            {
                @try
                {
                    //NSLog(@"#RLMDeadLock# task.block() in %s", __PRETTY_FUNCTION__);
                    task.block();
                }
                @catch (NSException *exception)
                {
                    NSLog(@"#RLMDeadLock# Exception : %@", exception);
                }
                @finally
                {
                    
                }
            }
            
            [_cond lock];
            {
                task.isFinished = YES;
                //NSLog(@"#RLMDeadLock# process Waking up @ %@, cond=%@", task, _cond);
                [_cond broadcast];
            }
            [_cond unlock];
        }
    }
}

- (NSThread*) myThread {
    return _thread;
}

+ (void) test {
    RealmSerialQueue* queue = [RealmSerialQueue shareRealmQueue];
    __block int number = 0;
    for (int i=0; i<1048576; ++i)
    {
        int prevNumber = number;
        [queue async:^{
            number += i;
        }];
        if (number - prevNumber == i)
        {
            NSLog(@"Passed. number=%d, prevNumber=%d, i=%d", number, prevNumber, i);
        }
        else
        {
            NSLog(@"Failed!");
            exit(-17);
        }
    }
}

@end
