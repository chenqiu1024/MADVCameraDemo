//
//  ImageFilterBean.m
//  Madv360_v1
//
//  Created by 张巧隔 on 16/8/10.
//  Copyright © 2016年 Cyllenge. All rights reserved.
//

#import "ImageFilterBean.h"
#ifdef MADVPANO_BY_SOURCE
#import "GLFilterCache.h"
#else
#import <MADVPano/GLFilterCache.h>
#endif

@interface ImageFilterBean ()
@end

@implementation ImageFilterBean

- (instancetype) initWithUUID:(int)uuid name:(NSString *)name enName:(NSString *)enName
                  iconPNGPath:(NSString *)iconPNGPath roundIconPNGPath:(NSString*)roundIconPNGPath {
    if (self = [super init])
    {
        self.uuid = uuid;
        self.name = name;
        self.enName = enName;
        self.iconPNGPath = iconPNGPath;
        self.roundIconPNGPath = roundIconPNGPath;
    }
    return self;
}

+ (NSMutableArray *)allImageFilters
{
    static dispatch_once_t once;
    static NSMutableArray* imageFilters;
    dispatch_once(&once, ^{
        typedef struct {
            int filterID;
            NSString* zhName;
            NSString* enName;
            NSString* iconPathName;
            NSString* roundIconPathName;
        } ImageFilterItem;
        static ImageFilterItem items[] = {
            {GLFilterNone, FGGetStringWithKeyFromTable(ORIGINAL, nil), @"Original", @"nothing_1", @"nothing_2"},
            {GLFilterBilateralID, FGGetStringWithKeyFromTable(BILATERAL, nil), @"Bilateral", @"exfoliating_1", @"exfoliating_2"},
            {GLFilterSepiaToneID, FGGetStringWithKeyFromTable(SEPIATONE, nil), @"Sepia Tone", @"past_1", @"past_2"},
            {GLFilterAmatorkaID, FGGetStringWithKeyFromTable(AMATORKA, nil), @"Amatorka", @"young_1", @"young_2"},
//            {GLFilterMissEtikateID, FGGetStringWithKeyFromTable(MISSETIKATE, nil), @"Miss Etikate", @"sea_1", @"sea_2"},
            {GLFilterInverseColorID, FGGetStringWithKeyFromTable(FILM, nil), @"Color Inverse", @"film_1", @"film_2"},
        };
        imageFilters = [[NSMutableArray alloc] init];
        NSBundle* bundle = [NSBundle mainBundle];
        for (int i = 0; i < sizeof(items) / sizeof(ImageFilterItem); ++i)
        {
            ImageFilterItem item = items[i];
            NSString* iconPNGPath = [bundle pathForResource:item.iconPathName ofType:@"png"];
            NSString* roundIconPNGPath = [bundle pathForResource:item.roundIconPathName ofType:@"png"];
            ImageFilterBean* bean = [[ImageFilterBean alloc] initWithUUID:item.filterID name:item.zhName enName:item.enName iconPNGPath:iconPNGPath roundIconPNGPath:roundIconPNGPath];
            [imageFilters addObject:bean];
        }
    });
    return imageFilters;
}

+ (ImageFilterBean *)findImageFilterByID:(int)uuid {
    NSMutableArray* imageFilters = [self allImageFilters];
    for (ImageFilterBean* filter in imageFilters)
    {
        if (filter.uuid == uuid)
            return filter;
    }
    return nil;
}

@end

