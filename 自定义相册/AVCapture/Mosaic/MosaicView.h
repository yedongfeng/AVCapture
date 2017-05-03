//
//  MosaicView.h
//  自定义相册
//
//  Created by 肖欣然 on 17/4/11.
//  Copyright © 2017年 肖欣然. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * 手指涂抹马赛克
 */
@interface MosaicView : UIView

/**
 * 要刮的底图.
 */
@property (nonatomic, strong) UIImage *image;

/**
 * 涂层图片.
 */
@property (nonatomic, strong) UIImage *surfaceImage;


/*
 * 转换成马赛克,level代表一个点转为多少level*level的正方形
 */
- (UIImage *)transToMosaicImage:(UIImage*)orginImage blockLevel:(NSUInteger)level;

/*
 * 清理马赛克
 */
- (void)clearMosaic;

- (void)updateFrame:(CGRect)rect;

@end
