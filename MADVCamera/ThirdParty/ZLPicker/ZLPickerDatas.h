//
//  PickerDatas.h
//  相册Demo
//
//  Created by 张磊 on 14-11-11.
//  Copyright (c) 2014年 com.zixue101.www. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>

@class ZLPickerGroup;

// 回调
typedef void(^callBackBlock)(id obj);

@interface ZLPickerDatas : NSObject

/**
 *  获取所有组
 */
+ (instancetype) defaultPicker;
/**
 * 获取所有组对应的图片
 */
- (void) getAllGroupWithPhotos : (callBackBlock ) callBack;

- (void) getAllGroupWithTypes:(ALAssetsGroupType)type callback:(callBackBlock)callBack;

/**
 *  传入一个组获取组里面的Asset
 */
- (void) getGroupPhotosWithGroup : (ZLPickerGroup *) pickerGroup finished : (callBackBlock ) callBack;

/**
 *  传入一个AssetsURL来获取UIImage
 */
- (void) getAssetsPhotoWithURLs:(NSURL *) url callBack:(callBackBlock ) callBack;

/**
 *  传入一个图片对象（ALAsset、URL）
 *
 *  @return 返回图片
 */
- (UIImage *) getImageWithImageObj:(id)imageObj;


@end
