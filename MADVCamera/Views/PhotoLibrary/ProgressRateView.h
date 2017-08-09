//
//  ProgressRateView.h
//  Madv360_v1
//
//  Created by 张巧隔 on 16/7/28.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import <UIKit/UIKit.h>
@class ProgressRateView;
@protocol ProgressRateViewDelegate <NSObject>

- (void)progressRateViewaGreementDidClick:(ProgressRateView *)progressRateView;

- (void)progressRateViewaDidFinish:(ProgressRateView *)progressRateView index:(NSInteger)index;

- (void)progressRateViewaStartShare:(ProgressRateView *)progressRateView;

- (void)progressRateViewaClose:(ProgressRateView *)progressRateView;

- (void)progressRateViewUploadError:(ProgressRateView *)progressRateView;
- (void)progressRateViewUploadSuc:(ProgressRateView *)progressRateView;

@end

@interface ProgressRateView : UIView
@property(nonatomic,weak)id<ProgressRateViewDelegate>delegate;

@property(nonatomic,copy)NSString * fileName;
@property(nonatomic,assign)BOOL isUsedAsEncoder;
@property(nonatomic,assign)CGFloat rate;
@property(nonatomic,weak)UIView * uploadView;
@property(nonatomic,weak)UIView * finishView;
@property(nonatomic,assign)BOOL isEdit;
@property(nonatomic,assign)BOOL isScreencap;

- (void)loadProgressRateView;

- (void)updateRate:(CGFloat)rate;
- (void)caprefresh;
@end
