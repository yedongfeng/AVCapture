//
//  AVCaptureVC.m
//  自定义相机拍照
//
//  Created by 肖欣然 on 17/4/7.
//  Copyright © 2017年 肖欣然. All rights reserved.
//

#import <UIKit/UIKit.h>

//返回拍照的图片
typedef void (^takePhotoBlock)(UIImage *image,NSDictionary *imageMetadata);
//typedef void (^takePhotoBlock)(NSData *data);


/**
 * AVFoundation实现自定义相机拍照功能.
 * 基本功能：闪光灯、自拍、设置对焦点以及保存图片经纬度等信息.
 * 后期编辑：涂鸦功能（OpenGL）、马赛克、添加水印logo.
 */
@interface AVCaptureVC : UIViewController

/**
 * 返回拍照的图片
 */
- (void)takePhoto:(takePhotoBlock)block;

/**
 * 是否开启定位
 */
@property (nonatomic, assign) BOOL isLocation;

/**
 * 是否添加水印
 */
@property (nonatomic, assign) BOOL isLogo;

/**
 * 水印文字
 */
@property (nonatomic, strong) NSString *logoString;

/**
 * 水印图片
 */
@property (nonatomic, strong) UIImage  *logoImage;

@end
