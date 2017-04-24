//
//  AVCaptureManager.h
//  自定义相册
//
//  Created by 肖欣然 on 17/4/24.
//  Copyright © 2017年 肖欣然. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
//AVFoundation
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
//屏幕方向判断
#import <CoreMotion/CoreMotion.h>
//图片信息写入，经纬度等
#import <ImageIO/ImageIO.h>
//定位功能
#import <CoreLocation/CoreLocation.h>

/**
 * AVFoundation实现自定义相机拍照功能.
 * 基本功能：闪光灯、自拍、设置对焦点以及保存图片经纬度等信息.
 * 后期编辑：涂鸦功能（OpenGL）、马赛克、添加水印logo.
 */

@interface AVCaptureManager : NSObject

/**
 * 单例初始化
 */
+ (id)sharedInstance;

/**
 *  方向
 */
@property (nonatomic, assign) AVCaptureVideoOrientation     avcaptureOrientation;

/**
 *  device
 */
@property (nonatomic, strong) AVCaptureDevice               *device;

/**
 *  AVCaptureSession对象来执行输入设备和输出设备之间的数据传递
 */
@property (nonatomic, strong) AVCaptureSession              *session;

/**
 *  输入
 */
@property (nonatomic, strong) AVCaptureDeviceInput          *input;

/**
 *  照片输出流
 */
@property (nonatomic, strong) AVCaptureStillImageOutput     *stillImageOutput;

/**
 * 是否开启定位
 */
@property (nonatomic, assign) BOOL isLocation;

/**
 * 设置图片经纬度信息
 */
- (NSDictionary *)imageMetadata;

- (NSMutableData *)setGPSToImageByLat:(double)lat longi:(double)longi imgData:(NSData *)data;

/**
 * 显示水印（时间日期）
 */
- (NSString *)timeString;

- (NSString *)dateStr;

/**
 * 计算宽度
 */
- (CGSize)sizeOfString:(NSString *)str stringFont:(UIFont *)font;

/**
 * 关闭(开启)闪光灯
 */
- (void)setCaptureFlashMode:(AVCaptureFlashMode)mode;

@end
