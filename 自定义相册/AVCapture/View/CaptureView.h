//
//  CaptureView.h
//  自定义相册
//
//  Created by beok on 17/4/24.
//  Copyright © 2017年 beok. All rights reserved.
//


#import <UIKit/UIKit.h>

@protocol CaptureViewDelegate <NSObject>
@optional
//取消拍照
- (void)cancelTakePhoto;

//使用照片
- (void)confirmImage:(UIImage *)image andImageMetadata:(NSDictionary *)imageMetadata;

@end

/**
 * 显示拍照
 */
@interface CaptureView : UIView

- (instancetype)init;

@property (nonatomic, weak) id<CaptureViewDelegate>delegate;


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
