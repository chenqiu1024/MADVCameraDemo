//
//  DBMVCloudMedia.m
//  Madv360_v1
//
//  Created by 张巧隔 on 16/8/13.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "DBMVCloudMedia.h"

@implementation DBMVCloudMedia
- (id)createWithMVCloudMedia:(MVCloudMedia *)cloudMedia
{
    DBMVCloudMedia * media=[[DBMVCloudMedia alloc] init];
    media.filename=cloudMedia.filename;
    media.title=cloudMedia.title;
    media.thumbnail=cloudMedia.thumbnail;
    media.author_name=cloudMedia.author_name;
    media.author_avatar=cloudMedia.author_avatar;
    media.keyword=cloudMedia.keyword;
    media.type=cloudMedia.type;
    media.favor=cloudMedia.favor;
    media.favored=cloudMedia.favored;
    media.playtime = cloudMedia.playtime;
    media.picsize = cloudMedia.picsize;
    media.createtime = cloudMedia.createtime;
    media.level = cloudMedia.level;
    media.view_count = cloudMedia.view_count;
    return media;
    
}
@end
