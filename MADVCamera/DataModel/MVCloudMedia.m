//
//  MVCloudMedia.m
//  Madv360_v1
//
//  Created by QiuDong on 16/4/29.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "MVCloudMedia.h"

@implementation MVCloudMedia

- (void)setFavor:(NSString *)favor
{
    _favor=favor;
    CGSize size=CGSizeMake(ScreenWidth-82, 17);
    size=[favor boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes: @{NSFontAttributeName:[UIFont systemFontOfSize:15]} context:nil].size;
    self.favorWidth=size.width;
}

//+ (NSDictionary*) mj_objectClassInArray {
//    return @{@"keywords":NSString.class};
//}


@end

@implementation MVCloudMediaListResponse

+ (NSDictionary*) mj_objectClassInArray {
    return @{@"result":MVCloudMedia.class};
}

@end
