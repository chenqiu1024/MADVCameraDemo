//
//  DBMVCloudMedia.h
//  Madv360_v1
//
//  Created by 张巧隔 on 16/8/13.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Realm.h"
#import "MVCloudMedia.h"

@interface DBMVCloudMedia : RLMObject
@property(nonatomic,copy)NSString * filename;//文件名

@property (nonatomic, copy) NSString* title;//标题

@property(nonatomic,copy)NSString * thumbnail;//题图图片url前缀

@property(nonatomic,copy)NSString * author_name;//发布者昵称

@property(nonatomic,copy)NSString * author_avatar;//发布者头像url

@property(nonatomic,copy)NSString * keyword;

@property(nonatomic,copy)NSString * type;//类型(图片0视频1)

@property(nonatomic,copy)NSString * favor;//收藏总数

@property(nonatomic,copy)NSString * favored;//是否收藏过
@property(nonatomic,copy)NSString * playtime;
@property(nonatomic,copy)NSString * picsize;
@property(nonatomic,copy)NSString * createtime;
@property(nonatomic,copy)NSString * level;
@property(nonatomic,copy)NSString * view_count;//浏览量

@property(nonatomic,copy)NSString * isNewest;//0推荐  1最新


- (id)createWithMVCloudMedia:(MVCloudMedia *)cloudMedia;
@end
