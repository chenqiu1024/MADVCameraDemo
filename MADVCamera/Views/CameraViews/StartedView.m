//
//  StartedView.m
//  Madv360_v1
//
//  Created by 张巧隔 on 16/8/19.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "StartedView.h"
#import "Masonry.h"

@implementation StartedView
- (void)loadStartedView
{
    UIImageView * backgroundView=[[UIImageView alloc] init];
    [self addSubview:backgroundView];
    [backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(@0);
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.bottom.equalTo(@0);
    }];
    backgroundView.image=[UIImage imageNamed:@"backimage.png"];
    
    UIView * backView=[[UIView alloc] init];
    [self addSubview:backView];
    [backView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(@0);
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.bottom.equalTo(@0);
    }];
    backView.backgroundColor=[UIColor colorWithHexString:@"#414347" alpha:0.85];
    
    UIImageView * imageView=[[UIImageView alloc] init];
    [self addSubview:imageView];
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.mas_centerX);
        make.centerY.equalTo(self.mas_centerY);
        make.width.equalTo(@150);
        make.height.equalTo(@144);
    }];
    imageView.image=[UIImage imageNamed:@"icon_camera_hig.png"];
    
    UILabel * subDescLabel=[[UILabel alloc] init];
    [self addSubview:subDescLabel];
    [subDescLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(imageView.mas_top).offset(-20);
        make.centerX.equalTo(imageView.mas_centerX);
        make.width.equalTo(@(ScreenWidth));
        make.height.equalTo(@13);
    }];
    subDescLabel.font=[UIFont systemFontOfSize:13];
    subDescLabel.textColor=[UIColor colorWithHexString:@"#F6F6F6"];
    subDescLabel.textAlignment=NSTextAlignmentCenter;
    subDescLabel.text=FGGetStringWithKeyFromTable(SHORTWIFI, nil);
    
    UILabel * descLabel=[[UILabel alloc] init];
    [self addSubview:descLabel];
    [descLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(subDescLabel.mas_top).offset(-5);
        make.centerX.equalTo(imageView.mas_centerX);
        make.width.equalTo(@250);
        make.height.equalTo(@13);
    }];
    descLabel.font=[UIFont systemFontOfSize:13];
    descLabel.textColor=[UIColor colorWithHexString:@"#F6F6F6"];
    descLabel.textAlignment=NSTextAlignmentCenter;
    descLabel.text=FGGetStringWithKeyFromTable(SURECAMERASTARTING, nil);
    
    UILabel * titleLabe=[[UILabel alloc] init];
    [self addSubview:titleLabe];
    [titleLabe mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(descLabel.mas_top).offset(-10);
        make.centerX.equalTo(self.mas_centerX);
        make.width.equalTo(@150);
        make.height.equalTo(@20);
    }];
    titleLabe.textAlignment=NSTextAlignmentCenter;
    titleLabe.font=[UIFont systemFontOfSize:20];
    titleLabe.textColor=[UIColor colorWithHexString:@"#F6F6F6"];
    titleLabe.text=FGGetStringWithKeyFromTable(OPENWIFI, nil);
    
    UIButton * startBtn=[[UIButton alloc] init];
    [self addSubview:startBtn];
    [startBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(@-20);
        make.left.equalTo(@15);
        make.right.equalTo(@-15);
        make.height.equalTo(@44);
    }];
    startBtn.backgroundColor=[UIColor clearColor];
    startBtn.layer.borderColor=[UIColor colorWithRed:0.50f green:0.50f blue:0.51f alpha:1.00f].CGColor;
    startBtn.layer.borderWidth=1;
    startBtn.layer.masksToBounds=YES;
    startBtn.layer.cornerRadius=15;
    [startBtn addTarget:self action:@selector(startBtn:) forControlEvents:UIControlEventTouchUpInside];
    [startBtn setTitle:FGGetStringWithKeyFromTable(STARTED, nil) forState:UIControlStateNormal];
    startBtn.titleLabel.font=[UIFont systemFontOfSize:15];
    [startBtn setTitleColor:[UIColor colorWithHexString:@"#FFFFFF" alpha:0.9] forState:UIControlStateNormal];
    
}

#pragma mark --启动--
- (void)startBtn:(UIButton *)btn
{
    NSLog(@"已启动");
    if ([self.delegate respondsToSelector:@selector(startedViewStarted:)]) {
        [self.delegate startedViewStarted:self];
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end