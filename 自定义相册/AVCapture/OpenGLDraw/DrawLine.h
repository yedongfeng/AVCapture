//
//  DrawLine.h
//  JoyHome
//
//  Created by xiaoxinran on 2017/4/1.
//  Copyright © 2017年 beok. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface LYPoint : NSObject

@property (nonatomic , strong) NSNumber* mY;
@property (nonatomic , strong) NSNumber* mX;

@end


/**
 * OpenGL实现涂鸦功能
 */
@interface DrawLine : UIView

@property(nonatomic, readwrite) CGPoint location;
@property(nonatomic, readwrite) CGPoint previousLocation;

- (void)erase;
- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue;

//得到绘制的涂鸦图片
- (UIImage *)glImage;

@end
