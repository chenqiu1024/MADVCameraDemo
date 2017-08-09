//
//  DiscoveryCell.m
//  Madv360_v1
//
//  Created by QiuDong on 16/5/13.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "DiscoveryCell.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "Masonry.h"

@interface DiscoveryCell()
@property(nonatomic,weak)UIImageView * thumImageView;
@property(nonatomic,weak)UIImageView * authorImageView;
@property(nonatomic,weak)UILabel * keyWordLabel;
@property(nonatomic,weak)UILabel * titleLabel;
@property(nonatomic,weak)UILabel * favorLabel;
@property(nonatomic,weak)UIImageView * typeImageView;
@property(nonatomic,weak)UILabel * nameLabel;
@property(nonatomic,weak)UILabel * timeLabel;
@property(nonatomic,weak)UILabel * publishTimeLabel;
@property(nonatomic,weak)UIButton * handleBtn;
@property(nonatomic,weak)UIImageView * vipImageView;
@property(nonatomic,weak)UIImageView * inviteImageView;
@end

@implementation DiscoveryCell

- (instancetype) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
    {
        [self setupSubviews];
    }
    return self;
}

- (void) setupSubviews {
    
    UIImageView * defaultImageView=[[UIImageView alloc] init];
    [self.contentView addSubview:defaultImageView];
    
    defaultImageView.image=[UIImage imageNamed:@"default_picture.png"];
    
    UIImageView * thumImageView=[[UIImageView alloc] init];
    [self.contentView addSubview:thumImageView];
    [thumImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(@0);
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.height.equalTo(@194);
    }];
    thumImageView.backgroundColor=[UIColor clearColor];
    self.thumImageView=thumImageView;
    
    [defaultImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.contentView.mas_centerX);
        make.centerY.equalTo(thumImageView.mas_centerY);
        make.width.equalTo(@100);
        make.height.equalTo(@100);
    }];
    
    UIImageView * maskImageView=[[UIImageView alloc] init];
    [self.contentView addSubview:maskImageView];
    [maskImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(@0);
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.height.equalTo(@194);
    }];
    maskImageView.image=[UIImage imageNamed:@"Mask"];
    
//    UIImageView * centerImage=[[UIImageView alloc] init];
//    [self.contentView addSubview:centerImage];
//    [centerImage mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.centerX.equalTo(self.contentView.mas_centerX);
//        make.centerY.equalTo(self.contentView.mas_centerY);
//        make.width.equalTo(@50);
//        make.height.equalTo(@50);
//    }];
//    centerImage.image=[UIImage imageNamed:@"newplay.png"];
//    self.centerImage=centerImage;
    
    
    
    UILabel * titleLabel=[[UILabel alloc] init];
    [self.contentView addSubview:titleLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(@15);
        make.left.equalTo(@15);
        make.right.equalTo(@-15);
        make.height.equalTo(@17);
    }];
    titleLabel.textColor=[UIColor colorWithHexString:@"#FFFFFF" alpha:0.9];
    titleLabel.font=[UIFont systemFontOfSize:15];
    self.titleLabel=titleLabel;
    
    UIImageView * typeImageView = [[UIImageView alloc] init];
    [self.contentView addSubview:typeImageView];
    self.typeImageView = typeImageView;
    
    UILabel * timeLabel = [[UILabel alloc] init];
    [self.contentView addSubview:timeLabel];
    [timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(typeImageView.mas_right).offset(5);
        make.top.equalTo(titleLabel.mas_bottom).offset(8);
        make.height.equalTo(@12);
        make.width.equalTo(@150);
    }];
    timeLabel.font = [UIFont systemFontOfSize:11];
    timeLabel.textColor = [UIColor colorWithHexString:@"#FFFFFF" alpha:0.7];
    self.timeLabel = timeLabel;
    
    
    UIView * bottomView = [[UIView alloc] init];
    [self.contentView addSubview:bottomView];
    [bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(thumImageView.mas_bottom);
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.height.equalTo(@65);
    }];
    bottomView.backgroundColor = [UIColor whiteColor];
    
    
    UIImageView * authorImageView=[[UIImageView alloc] init];
    [bottomView addSubview:authorImageView];
//    [authorImageView mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(@15);
//        make.centerY.equalTo(bottomView.mas_centerY);
//        make.width.equalTo(@35);
//        make.height.equalTo(@35);
//    }];
    authorImageView.frame = CGRectMake(15, (65-35)*0.5, 35, 35);
    authorImageView.layer.masksToBounds=YES;
    authorImageView.layer.cornerRadius=17.5;
    
    authorImageView.layer.borderWidth=1;
    authorImageView.layer.borderColor=[UIColor whiteColor].CGColor;
    self.authorImageView=authorImageView;
    
    UIImageView * vipImageView = [[UIImageView alloc] init];
    [self.contentView addSubview:vipImageView];
    [vipImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(authorImageView.mas_bottom).offset(-10);
        make.right.equalTo(authorImageView.mas_right);
        make.width.equalTo(@15);
        make.height.equalTo(@15);
    }];
    vipImageView.image = [UIImage imageNamed:@"vip.png"];
    vipImageView.hidden = YES;
    self.vipImageView = vipImageView;
    
    UILabel * nameLabel = [[UILabel alloc] init];
    [bottomView addSubview:nameLabel];
//    [nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(authorImageView.mas_right).offset(10);
//        make.top.equalTo(authorImageView.mas_top);
//        make.width.equalTo(@150);
//        make.height.equalTo(@16);
//    }];
    nameLabel.frame = CGRectMake(60, (65-35)*0.5, 150, 16);
    nameLabel.font = [UIFont systemFontOfSize:15];
    nameLabel.textColor = [UIColor colorWithHexString:@"#000000" alpha:0.9];
    self.nameLabel = nameLabel;
    
    UIImageView * inviteImageView = [[UIImageView alloc] init];
    [self.contentView addSubview:inviteImageView];
    
    inviteImageView.image = [UIImage imageNamed:@"invite.png"];
    inviteImageView.hidden = YES;
    self.inviteImageView = inviteImageView;
    
    UILabel * keyWordLabel=[[UILabel alloc] init];
    [bottomView addSubview:keyWordLabel];
    [keyWordLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(@(-(65-35)*0.5));
        make.left.equalTo(@60);
        make.width.equalTo(@(ScreenWidth-100-50));
        make.height.equalTo(@17);
    }];
    keyWordLabel.textColor=[UIColor colorWithHexString:@"#000000" alpha:0.6];
    keyWordLabel.font=[UIFont systemFontOfSize:12];
    self.keyWordLabel=keyWordLabel;
    
    UILabel * publishTimeLabel = [[UILabel alloc] init];
    [bottomView addSubview:publishTimeLabel];
    [publishTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(@-15);
        make.centerY.equalTo(bottomView.mas_centerY);
        make.height.equalTo(@13);
        make.width.equalTo(@85);
    }];
    publishTimeLabel.textColor = [UIColor colorWithHexString:@"#000000" alpha:0.6];
    publishTimeLabel.font = [UIFont systemFontOfSize:12];
    publishTimeLabel.textAlignment = NSTextAlignmentRight;
    self.publishTimeLabel = publishTimeLabel;
    
    UIButton * handleBtn = [[UIButton alloc] init];
    [bottomView addSubview:handleBtn];
    [handleBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(@-15);
        make.centerY.equalTo(bottomView.mas_centerY);
        make.width.equalTo(@30);
        make.height.equalTo(@60);
    }];
    [handleBtn setImage:[UIImage imageNamed:@"more-hui.png"] forState:UIControlStateNormal];
    [handleBtn addTarget:self action:@selector(handleBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    handleBtn.hidden = YES;
    self.handleBtn = handleBtn;
    
    
//    UIImageView * favorImageView=[[UIImageView alloc] init];
//    [self.contentView addSubview:favorImageView];
//    favorImageView.layer.cornerRadius=5;
//    favorImageView.layer.masksToBounds=YES;
//    favorImageView.image=[UIImage imageNamed:@"collect_unselected_white.png"];
//    favorImageView.userInteractionEnabled=YES;
//    self.favorImageView=favorImageView;
    
#pragma mark --目前先不要--
    
    
    
//    UILabel * favorLabel=[[UILabel alloc] init];
//    [self.contentView addSubview:favorLabel];
//    favorLabel.font=[UIFont systemFontOfSize:15];
//    favorLabel.textColor=[UIColor whiteColor];
//    self.favorLabel=favorLabel;
    
    UIView * lineView=[[UIView alloc] init];
    [self.contentView addSubview:lineView];
    [lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(@0);
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.height.equalTo(@10);
    }];
    lineView.backgroundColor=[UIColor colorWithRed:0.93f green:0.93f blue:0.93f alpha:1.00f];
}
//点击收藏的事件  目前先不要
- (void)favorTap:(UITapGestureRecognizer *)tap
{
    
    if ([self.delegate respondsToSelector:@selector(discoveryCellDidFavor:andIsFavor:andFileName:andImageView:andFavorLabel:title:)]) {
//        [self.delegate discoveryCellDidFavor:self andIsFavor:self.cloudMedia.favored andFileName:self.cloudMedia.filename andImageView:self.favorImageView andFavorLabel:self.favorLabel title:self.cloudMedia.title];
    }
}

- (void)setCloudMedia:(MVCloudMedia *)cloudMedia
{
    _cloudMedia=cloudMedia;
    
    
    [self.thumImageView sd_setImageWithURL:[NSURL URLWithString:cloudMedia.thumbnail]];
    self.titleLabel.text=cloudMedia.title;
    if ([cloudMedia.level isEqualToString:@"0"]) {
        self.vipImageView.hidden = YES;
        self.inviteImageView.hidden = YES;
    }else if([cloudMedia.level isEqualToString:@"1"])
    {
        self.vipImageView.hidden = NO;
        self.inviteImageView.hidden = NO;
    }
    if ([cloudMedia.type isEqualToString:@"0"]) {
        [self.typeImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.titleLabel.mas_left);
            make.centerY.equalTo(self.timeLabel.mas_centerY);
            make.height.equalTo(@11);
            make.width.equalTo(@11);
        }];
        self.typeImageView.image= [UIImage imageNamed:@"dis_picture.png"];
        if (![cloudMedia.picsize isEqualToString:@""]) {
            
            self.timeLabel.text = [NSString stringWithFormat:@"%@MB",[self formatFloat:(float)[cloudMedia.picsize integerValue]/(1024*1024)]];
        }else
        {
            self.timeLabel.text = @"";
        }
        
    }else
    {
        [self.typeImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.titleLabel.mas_left);
            make.centerY.equalTo(self.timeLabel.mas_centerY);
            make.height.equalTo(@9);
            make.width.equalTo(@12);
        }];
        self.typeImageView.image= [UIImage imageNamed:@"shoot.png"];
        if (![cloudMedia.playtime isEqualToString:@""]) {
            self.timeLabel.text = [self formatTimeInterval:[cloudMedia.playtime floatValue] isLeft:NO];
        }else
        {
            self.timeLabel.text = @"";
        }
        
    }
    
    
    [self.authorImageView sd_setImageWithURL:[NSURL URLWithString:cloudMedia.author_avatar] placeholderImage:[UIImage imageNamed:@"head.png"]];
    
    if (cloudMedia.keyword == nil || [cloudMedia.keyword isEqualToString:@""]) {
        
        if ([cloudMedia.type isEqualToString:@"0"])
        {
            self.keyWordLabel.text = [NSString stringWithFormat:@"#%@",FGGetStringWithKeyFromTable(PANPIC, nil)];
        }else
        {
            self.keyWordLabel.text = [NSString stringWithFormat:@"#%@",FGGetStringWithKeyFromTable(PANVIDEO, nil)];
        }
        
    }else
    {
        
        self.keyWordLabel.text=cloudMedia.keyword;
    }
    if (cloudMedia.author_name == nil) {
        cloudMedia.author_name = @"";
    }
    NSMutableAttributedString * authorNameAttributed = [[NSMutableAttributedString alloc] initWithString:cloudMedia.author_name];
    self.nameLabel.attributedText=authorNameAttributed;
    [self.nameLabel sizeToFit];
    [self.inviteImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nameLabel.mas_right).offset(9);
        make.centerY.equalTo(self.nameLabel.mas_centerY).offset(-5);
        make.width.equalTo(@39);
        make.height.equalTo(@24);
    }];
    if (self.isMine) {
        self.publishTimeLabel.hidden = YES;
        self.handleBtn.hidden = NO;
        self.timeLabel.text = [NSString stringWithFormat:@"%@/%@",self.timeLabel.text,[cloudMedia.createtime componentsSeparatedByString:@" "][0]];
    }else
    {
        self.publishTimeLabel.hidden = NO;
        self.handleBtn.hidden = YES;
        self.publishTimeLabel.text = [cloudMedia.createtime componentsSeparatedByString:@" "][0];
    }
    
    
    
    
    
    
    
   
//    if ([cloudMedia.favored isEqualToString:@"0"]) {
//        self.favorImageView.image=[UIImage imageNamed:@"like_h.png"];
//    }else
//    {
//        self.favorImageView.image=[UIImage imageNamed:@"like_n.png"];
//    }
    
}
- (void)handleBtnClick:(UIButton *)btn
{
    if ([self.delegate respondsToSelector:@selector(discoveryCellClick:)]) {
        [self.delegate discoveryCellClick:self];
    }
}

- (NSString *)formatFloat:(float)f
{
    if (fmodf(f, 1)==0) {//如果有一位小数点
        return [NSString stringWithFormat:@"%.2f",f];
    } else if (fmodf(f*10, 1)==0) {//如果有两位小数点
        return [NSString stringWithFormat:@"%.2f",f];
    } else {
        return [NSString stringWithFormat:@"%.2f",f];
    }
}

-(NSString*) formatTimeInterval:(CGFloat)seconds isLeft:(BOOL) isLeft
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%0.2ld:%0.2ld", (long)h, (long)m];
    else        [format appendFormat:@"%0.2ld′", (long)m];
    [format appendFormat:@"%0.2ld″", (long)s];
    //    [format appendFormat:@"%ld:%0.2ld", (long)h, (long)m];
    //    [format appendFormat:@":%0.2ld", (long)s];
    
    return format;
}



@end
