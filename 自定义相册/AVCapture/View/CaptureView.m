//
//  CaptureView.m
//  自定义相册
//
//  Created by 肖欣然 on 17/4/24.
//  Copyright © 2017年 肖欣然. All rights reserved.
//

//屏幕大小
#define W [[UIScreen mainScreen] bounds].size.width

#define H [[UIScreen mainScreen] bounds].size.height

#import "CaptureView.h"
//AVFoundation
#import <AVFoundation/AVFoundation.h>
//马赛克
#import "MosaicView.h"
//画线
#import "DrawLine.h"
//UI约束
#import "Masonry.h"

#import "AVCaptureManager.h"


@interface CaptureView ()
{
    AVCaptureManager *_manager;
    
    CGFloat _topViewH;
    CGFloat _w;
    CGFloat _h;
    
    NSData *_jpegData;//保存图片数据
}

/**
 *  预览View
 */
@property (nonatomic, strong) UIView                        *preview;

/**
 *  预览图层
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer    *previewLayer;

/**
 *  对焦view
 */
@property (nonatomic, strong) UIView                        *focusView;

/**
 *  显示拍照的图片
 */
@property (nonatomic, strong) UIImageView                   *imageView;

/**
 *  logo水印view
 */
@property (nonatomic, strong) UIView                        *logoView;

/**
 *  马赛克view
 */
@property (nonatomic, strong) MosaicView                    *mosaicView;

/**
 *  涂鸦画板
 */
@property (nonatomic, strong) DrawLine                      *drawLine;

/**
 * 当前页面的图片
 */
@property (nonatomic, strong) UIImage                       *currentImage;

/**
 * openGL绘制的图片（涂鸦的线）
 */
@property (nonatomic, strong) UIImage                       *glImage;

/**
 *  一些按钮，如拍照、闪光灯、涂鸦等
 */
@property (nonatomic, strong) UIButton *takePhotoBtn;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIButton *lightBtn;
@property (nonatomic, strong) UIButton *switchBtn;
@property (nonatomic, strong) UIButton *againPhotoBtn;
@property (nonatomic, strong) UIButton *confirmBtn;
@property (nonatomic, strong) UIButton *drawLineBtn;
@property (nonatomic, strong) UIButton *mosaicBtn;

@end

@implementation CaptureView

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _manager = [AVCaptureManager sharedInstance];
        
        [self initUI];
        
        //监听对焦
        int flags = NSKeyValueObservingOptionNew;
        [_manager.device addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];

        
    }
    return self;
}

- (void)dealloc
{
    [_manager.device removeObserver:self forKeyPath:@"adjustingFocus"];
}

#pragma mark -显示拍照成功的图片
- (void)showImage
{
    UIImage *img = [[UIImage alloc] initWithData:_jpegData];
    self.currentImage = img;
    
    [self initLogoView];
    
}

//处理水印view
- (void)initLogoView
{
    CGFloat imageW = self.currentImage.size.width;
    CGFloat imageH = self.currentImage.size.height;
    
    CGFloat imgViewW = _w;
    CGFloat imgViewH = _h - _topViewH * 2;
    
    CGFloat logoH = 45;
    CGFloat logoW = 0;
    
    if(!self.imageView)
    {
        self.imageView = [[UIImageView alloc] init];
        [self addSubview:self.imageView];
        self.imageView.hidden = YES;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    if(imageW > imageH)
    {
        imgViewH = imgViewW * imgViewW / imgViewH;//w * imageH / imageW
    }
    /*
     bug处理：高度原本是小数，加了约束之后，view的高度会四舍五入取整，比如h=228.55,view实际高度成了229。如果view约束高度比h大，保存图片时会造成四周有留白。暂未找到解决约束的办法，只能先处理高度。
     */
    CGFloat f = imgViewH - (NSInteger)imgViewH;
    imgViewH = imgViewH - f;
    
    CGFloat s = 0;
    if(imageW / imgViewW < imageH / imgViewH)
    {
        s = imageW / imgViewW;
    }
    else
    {
        s = imageH / imgViewH;
    }
    
    //方向处理
    UIImageOrientation or = self.currentImage.imageOrientation;
    CGRect rect;
    if(or == UIImageOrientationUp)
    {
        rect = CGRectMake((imageW - imgViewW * s) / 2.0, (imageH - imgViewH * s) / 2.0, imgViewW * s, imgViewH * s);
    }
    else if(or == UIImageOrientationRight)
    {
        rect = CGRectMake((imageH - imgViewH * s) / 2.0, (imageW - imgViewW * s) / 2.0, imgViewH * s, imgViewW * s);
    }
    else if(or == UIImageOrientationLeft)
    {
        rect = CGRectMake((imageH - imgViewH * s) / 2.0, (imageW - imgViewW * s) / 2.0, imgViewH * s, imgViewW * s);
    }
    else if(or == UIImageOrientationDown)
    {
        rect = CGRectMake((imageH - imgViewH * s) / 2.0, (imageW - imgViewW * s) / 2.0, imgViewW * s, imgViewH * s);
    }
    
    CGImageRef subImageRef = CGImageCreateWithImageInRect([self.currentImage CGImage], rect);
    UIImage *smallImage = [UIImage imageWithCGImage:subImageRef scale:self.currentImage.scale orientation:or];
    CGImageRelease(subImageRef);
    
    if(smallImage)
    {
        self.imageView.backgroundColor = [UIColor clearColor];
        self.imageView.image = smallImage;
    }
    
    [self.imageView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(imgViewH));
        make.center.equalTo(self);
        make.left.right.equalTo(self);
    }];
    
    //水印
    if(self.isLogo)
    {
        NSString *dateString = [_manager dateStr];
        UIFont *dateFont = [UIFont systemFontOfSize:12];
        UIFont *logoFont = [UIFont systemFontOfSize:14];
        CGSize dateSize = [_manager sizeOfString:dateString stringFont:dateFont];
        CGSize logoSize = [_manager sizeOfString:self.logoString stringFont:logoFont];
        logoW = dateSize.width + 60 ? logoSize.width + 60 : dateSize.width > logoSize.width;
        
        if(!self.logoView)
        {
            self.logoView = [[UIView alloc] init];
            self.logoView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
            [self.imageView addSubview:self.logoView];
            
            UILabel *timeLab = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, logoW, 20)];
            timeLab.tag = 1;
            timeLab.font = dateFont;
            timeLab.textColor = [UIColor whiteColor];
            timeLab.textAlignment = NSTextAlignmentCenter;
            [self.logoView addSubview:timeLab];

            UILabel *logoLab = [[UILabel alloc] initWithFrame:CGRectMake(38, 25, logoSize.width, 20)];
            logoLab.tag = 2;
            logoLab.font = logoFont;
            logoLab.textColor = [UIColor whiteColor];
            logoLab.textAlignment = NSTextAlignmentRight;
            [self.logoView addSubview:logoLab];
            logoLab.text = self.logoString;

            UIImageView *logoImg = [[UIImageView alloc] initWithFrame:CGRectMake(10, 23, 18, 18)];
            [self.logoView addSubview:logoImg];
            logoImg.layer.cornerRadius = 3.0;
            logoImg.layer.masksToBounds = YES;
            logoImg.image = self.logoImage;
        }
        
        UILabel *timeLab = [self.imageView viewWithTag:1];
        timeLab.text = dateString;
        
        [self.logoView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(@(logoW));
            make.height.equalTo(@(logoH));
            make.centerX.equalTo(self.imageView);
            make.bottom.equalTo(self.imageView).offset(-10);
        }];
    }
    
    //马赛克
    if(!self.mosaicView)
    {
        self.mosaicView = [[MosaicView alloc] init];
        [self addSubview:self.mosaicView];
    }
    [self.mosaicView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(imgViewH));
        make.center.equalTo(self);
        make.left.right.equalTo(self);
    }];
    
    [self.mosaicView updateFrame:CGRectMake(0, 0, imgViewW, imgViewH)];
    
    //涂鸦
    if(!self.drawLine)
    {
        self.drawLine = [[DrawLine alloc] init];
        [self addSubview:self.drawLine];
        self.drawLine.backgroundColor = [UIColor clearColor];
        [self.drawLine setBrushColorWithRed:1.0 green:0.0 blue:0.0];
    }
    [self.drawLine mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(imgViewH));
        make.center.equalTo(self);
        make.left.right.equalTo(self);
    }];
    
    self.imageView.hidden = NO;
    self.confirmBtn.hidden = NO;
    self.againPhotoBtn.hidden = NO;
    self.drawLineBtn.hidden = NO;
    self.mosaicBtn.hidden = NO;
    
    self.previewLayer.hidden = YES;
    self.takePhotoBtn.hidden = YES;
    self.cancelBtn.hidden = YES;
    self.lightBtn.hidden = YES;
    self.switchBtn.hidden = YES;
    
    self.mosaicView.hidden = YES;
    self.drawLine.hidden = YES;
    
    self.mosaicBtn.userInteractionEnabled = YES;
    self.drawLine.userInteractionEnabled = YES;
    
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0/*延迟执行时间*/ * NSEC_PER_SEC));
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        weakSelf.currentImage = [weakSelf imageWithlogoImageView];
    });
    
}

- (NSString *)dateStr
{
    NSString *str = @"";
    
    NSDateComponents *dateComponent = [self dateComponent];
    NSInteger year = [dateComponent year];
    NSInteger month = [dateComponent month];
    NSInteger day = [dateComponent day];
    NSInteger hour = [dateComponent hour];
    NSInteger minute = [dateComponent minute];
    NSInteger second = [dateComponent second];
    
    str = [NSString stringWithFormat:@"%ld-%02ld-%02ld %02ld:%02ld:%02ld",year,month,day,hour,minute,second];
    
    return str;
}

- (NSDateComponents *)dateComponent
{
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    
    NSDateComponents *dateComponent = [calendar components:unitFlags fromDate:now];
    
    return dateComponent;
}

#pragma mark -返回马赛克图片
- (UIImage *)mosaicImage
{
    UIGraphicsBeginImageContextWithOptions(self.mosaicView.bounds.size, NO, [UIScreen mainScreen].scale);
    [self.mosaicView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

#pragma mark -两张图片合成一张图（涂鸦）
- (UIImage *)imageWithGlImage:(UIImage *)glImage andImageTwo:(UIImage *)image2
{
    CGFloat s = 0;
    if(image2.size.width > glImage.size.width)
    {
        s = image2.size.width / glImage.size.width;
        UIGraphicsBeginImageContext(image2.size);
        [image2 drawInRect:CGRectMake(0, 0, image2.size.width,image2.size.height)];
        [glImage drawInRect:CGRectMake(0, 0, glImage.size.width * s,glImage.size.height * s)];
    }
    else
    {
        s = glImage.size.width / image2.size.width;
        UIGraphicsBeginImageContext(glImage.size);
        [image2 drawInRect:CGRectMake(0, 0, image2.size.width  * s,image2.size.height  * s)];
        [glImage drawInRect:CGRectMake(0, 0, glImage.size.width,glImage.size.height)];
    }
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

#pragma mark -返回水印图片
- (UIImage *)imageWithlogoImageView
{
    UIGraphicsBeginImageContextWithOptions(self.imageView.bounds.size, NO, [UIScreen mainScreen].scale);
    [self.imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

#pragma mark -对焦事件
//监听对焦
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if(_manager.device.adjustingFocus)
    {
        //开始对焦
        self.focusView.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            self.focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 animations:^{
                self.focusView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                
            }];
        }];
    }
    else
    {
        //对焦成功
        [UIView animateWithDuration:0.2 animations:^{
            self.focusView.transform = CGAffineTransformMakeScale(0.75, 0.75);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                self.focusView.hidden = YES;
            } completion:^(BOOL finished) {
                
            }];
        }];
    }
}

//设置对焦点
- (void)focusAtPoint:(CGPoint)point
{
    CGSize size = self.preview.bounds.size;
    CGPoint focusPoint = CGPointMake(point.y / size.height ,1 - point.x / size.width);
    NSError *error;
    
    if ([_manager.device lockForConfiguration:&error])
    {
        //对焦模式和对焦点
        if ([_manager.device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
        {
            [_manager.device setFocusPointOfInterest:focusPoint];
            [_manager.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        else
        {
            self.focusView.hidden = NO;
            
            [UIView animateWithDuration:0.2 animations:^{
                self.focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
            }completion:^(BOOL finished) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.focusView.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished) {
                    self.focusView.hidden = YES;
                }];
            }];
        }
        
        //曝光模式和曝光点
        if ([_manager.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ])
        {
            [_manager.device setExposurePointOfInterest:focusPoint];
            [_manager.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        self.focusView.center = point;
        [_manager.device unlockForConfiguration];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(self.previewLayer.hidden)
    {
        return;
    }
    
    for(UITouch *touch in event.allTouches)
    {
        CGPoint point = [touch locationInView:self.preview];
        [self focusAtPoint:point];
    }
}

#pragma mark -点击事件
//开启或关闭闪光灯
-(void)onOrOffLight:(UIButton *)sender
{
    //修改前必须先锁定
    [_manager.device lockForConfiguration:nil];
    //必须判定是否有闪光灯，否则如果没有闪光灯会崩溃
    if ([_manager.device hasFlash])
    {
        if (_manager.device.flashMode == AVCaptureFlashModeOff)
        {
            _manager.device.flashMode = AVCaptureFlashModeOn;
            [self.lightBtn setImage:[UIImage imageNamed:@"icon-flash-open"] forState:UIControlStateNormal];
        }
        else
        {
            _manager.device.flashMode = AVCaptureFlashModeOff;
            [self.lightBtn setImage:[UIImage imageNamed:@"icon-flash-close"] forState:UIControlStateNormal];
        }
    }
    else
    {
        NSLog(@"设备不支持闪光灯");
    }
    
    [_manager.device unlockForConfiguration];
}

//拍照
- (void)takePhotoButtonClick:(UIButton *)sender
{
    AVCaptureConnection *stillImageConnection = [_manager.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [stillImageConnection setVideoOrientation:_manager.avcaptureOrientation];
    [stillImageConnection setVideoScaleAndCropFactor:1];
    
    [_manager.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if(error)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:[NSString stringWithFormat:@"保存图片出错：%@",error] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            [alert show];
            
            return ;
        }
        
        //获取图片数据，并且写入经纬度等照片信息
        /*
         NSData *imgData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
         _jpegData = [self setGPSToImageByLat:self.cllLocation.coordinate.latitude longi:self.cllLocation.coordinate.longitude imgData:imgData];
         
         
         */
        
        _jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        
        //显示拍照成功的图片
        [self showImage];
    }];
}

//取消拍照
- (void)cancelButtonClick:(UIButton *)sender
{
    if(self.delegate && [self.delegate respondsToSelector:@selector(cancelTakePhoto)])
    {
        [self.delegate cancelTakePhoto];
    }
}

//切换摄像头
- (void)switchButtonClick:(UIButton *)sender
{
    NSInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    
    if(cameraCount > 1)
    {
        NSError *error;
        CATransition *animation = [CATransition animation];
        animation.duration = 0.5;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        animation.type = @"oglFlip";
        
        AVCaptureDevice *newCamera = nil;
        AVCaptureDeviceInput *newInput = nil;
        AVCaptureDevicePosition possion = [[_manager.input device] position];
        if(possion == AVCaptureDevicePositionFront)
        {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            animation.subtype = kCATransitionFromLeft;//动画翻转方向
        }
        else
        {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            animation.subtype = kCATransitionFromRight;//动画翻转方向
        }
        newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:&error];
        [self.previewLayer addAnimation:animation forKey:nil];
        
        if(newInput != nil)
        {
            [_manager.session beginConfiguration];
            [_manager.session removeInput:_manager.input];
            if([_manager.session canAddInput:newInput])
            {
                [_manager.session addInput:newInput];
                _manager.input = newInput;
            }
            else
            {
                [_manager.session addInput:_manager.input];
            }
            
            [_manager.session commitConfiguration];
            
            [_manager.device removeObserver:self forKeyPath:@"adjustingFocus"];
            _manager.device = newCamera;
            int flags = NSKeyValueObservingOptionNew;
            [_manager.device addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
        }
        else
        {
            NSLog(@"toggle carema failed, error = %@", error);
        }
    }
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for(AVCaptureDevice *device in devices)
    {
        if(device.position == position)
        {
            return device;
        }
    }
    
    return nil;
}

//添加马赛克
-(void)addMosaic:(UIButton *)sender
{
    //状态清理
    [self.mosaicView clearMosaic];
    self.mosaicBtn.userInteractionEnabled = NO;
    [self.mosaicBtn setImage:[UIImage imageNamed:@"icon-mosaic-selected"] forState:UIControlStateNormal];
    [self.drawLineBtn setImage:[UIImage imageNamed:@"icon-ty-normal"] forState:UIControlStateNormal];
    self.mosaicView.hidden = NO;
    
    if (self.drawLine.hidden == NO)
    {
        self.glImage = [self.drawLine glImage];
        //获取当前涂鸦的图片
        self.currentImage = [self imageWithGlImage:self.glImage andImageTwo:self.currentImage];
        
        self.drawLine.hidden = YES;
        self.glImage = nil;
    }
    else
    {
        self.currentImage = [self imageWithlogoImageView];
        self.imageView.hidden = YES;
    }
    
    self.mosaicView.surfaceImage = self.currentImage;
    self.mosaicView.image = [self.mosaicView transToMosaicImage:self.currentImage blockLevel:15];
}

//涂鸦
- (void)drawLine:(UIButton *)sender
{
    [self.drawLine erase];
    
    self.mosaicBtn.userInteractionEnabled = YES;
    [self.mosaicBtn setImage:[UIImage imageNamed:@"icon-mosaic-normal"] forState:UIControlStateNormal];
    [self.drawLineBtn setImage:[UIImage imageNamed:@"icon-ty-selected"] forState:UIControlStateNormal];
    
    self.imageView.hidden = NO;
    self.drawLine.hidden = NO;
    
    if (self.mosaicView.hidden == NO)
    {
        self.currentImage = [self mosaicImage];
        self.mosaicView.hidden = YES;
    }
    
    if(!self.currentImage)
    {
        self.currentImage = [self imageWithlogoImageView];
    }
    self.imageView.image = self.currentImage;
}

//重 拍
- (void)takePhotoAgain:(UIButton *)sender
{
    _jpegData = nil;
    self.currentImage = nil;
    self.glImage = nil;
    [self.drawLine erase];
    [self.mosaicView clearMosaic];
    
    self.imageView.hidden = YES;
    self.previewLayer.hidden = NO;
    self.confirmBtn.hidden = YES;
    self.againPhotoBtn.hidden = YES;
    self.takePhotoBtn.hidden = NO;
    self.cancelBtn.hidden = NO;
    self.lightBtn.hidden = NO;
    self.switchBtn.hidden = NO;
    
    self.mosaicView.hidden = YES;
    self.mosaicBtn.hidden = YES;
    self.drawLineBtn.hidden = YES;
    self.drawLine.hidden = YES;
    
    [self.mosaicBtn setImage:[UIImage imageNamed:@"icon-mosaic-normal"] forState:UIControlStateNormal];
    [self.drawLineBtn setImage:[UIImage imageNamed:@"icon-ty-normal"] forState:UIControlStateNormal];
}

//使用照片
- (void)confirmBtnClick:(UIButton *)sender
{
    if(self.delegate && [self.delegate respondsToSelector:@selector(confirmImage:andImageMetadata:)])
    {
        UIImage *image = nil;
        self.glImage = [self.drawLine glImage];
        
        if(self.mosaicView.hidden == YES)
        {
            if(self.currentImage == nil)
            {
                self.currentImage = [self imageWithlogoImageView];
            }
            image = [self imageWithGlImage:self.glImage andImageTwo:self.currentImage];
        }
        else
        {
            if(self.currentImage == nil)
            {
                self.currentImage = [self imageWithlogoImageView];
            }
            image = [self imageWithGlImage:self.glImage andImageTwo:[self mosaicImage]];
        }
        
        [self.delegate confirmImage:image andImageMetadata:[_manager imageMetadata]];
    }
}

#pragma mark -页面ui
- (void)initUI
{
    self.backgroundColor = [UIColor blackColor];
    
    _w = W;
    _h = H;
    
    //页面有作禁止横屏处理，但如果前面页面是横屏，这时候w和h仍然是横屏时候的值
    if(_w > _h)
    {
        _w = H;
        _h = W;
    }
    
    //1.最上面的view:取消，闪光灯，切换
    _topViewH = 60;
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _w, _topViewH)];
    topView.backgroundColor = [UIColor clearColor];
    [self addSubview:topView];
    
    [topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self);
        make.height.equalTo(@(_topViewH));
    }];
    
    //取消按钮
    self.cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [topView addSubview:self.cancelBtn];
    self.cancelBtn.backgroundColor = [UIColor clearColor];
    [self.cancelBtn setTitle:@"取 消" forState:UIControlStateNormal];
    [self.cancelBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.cancelBtn addTarget:self action:@selector(cancelButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.cancelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(80));
        make.height.equalTo(@(30));
        make.left.equalTo(topView).offset(20);
        make.top.equalTo(topView).offset(15);
    }];
    
    //闪光灯
    if(!_manager.device)
    {
        _manager.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    if ([_manager.device hasFlash])
    {
        self.lightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.lightBtn setImage:[UIImage imageNamed:@"icon-flash-close"] forState:UIControlStateNormal];
        [self.lightBtn addTarget:self action:@selector(onOrOffLight:) forControlEvents:UIControlEventTouchDown];
        [topView addSubview:self.lightBtn];
        
        [self.lightBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(topView);
            make.width.equalTo(@(80));
            make.height.equalTo(@(30));
            make.top.equalTo(topView).offset(15);
        }];
    }
    
    //切换前后摄像头
    self.switchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [topView addSubview:self.switchBtn];
    self.switchBtn.backgroundColor = [UIColor clearColor];
    [self.switchBtn setTitle:@"切 换" forState:UIControlStateNormal];
    [self.switchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.switchBtn addTarget:self action:@selector(switchButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.switchBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(80));
        make.height.equalTo(@(30));
        make.right.equalTo(topView).offset(-20);
        make.top.equalTo(topView).offset(15);
    }];
    
    //2.初始化中间的拍照预览图层
    self.preview = [[UIView alloc] init];
    [self addSubview:self.preview];
    self.preview.backgroundColor = [UIColor clearColor];
    [self.preview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.top.bottom.equalTo(self).offset(_topViewH);
    }];
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_manager.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    self.previewLayer.frame = CGRectMake(0, 0, _w, _h - _topViewH * 2);
    self.preview.layer.masksToBounds = YES;
    [self.preview.layer addSublayer:self.previewLayer];
    
    //对焦动画
    CGFloat focusViewW = 120;
    self.focusView = [[UIView alloc] initWithFrame:CGRectMake((_w - focusViewW) / 2.0, (_h - _topViewH * 2 - focusViewW) / 2.0, 80, 80)];
    [_preview addSubview:self.focusView];
    self.focusView.hidden = YES;
    self.focusView.backgroundColor = [UIColor clearColor];
    self.focusView.layer.borderColor = [UIColor yellowColor].CGColor;
    self.focusView.layer.borderWidth = 0.5;
    
    //3.页面下方的view，拍照，重拍，使用照片，涂鸦，马赛克
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _w, _topViewH)];
    bottomView.backgroundColor = [UIColor clearColor];
    [self addSubview:bottomView];
    
    [bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self);
        make.height.equalTo(@(_topViewH));
    }];
    
    //拍照按钮
    self.takePhotoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [bottomView addSubview:self.takePhotoBtn];
    self.takePhotoBtn.backgroundColor = [UIColor clearColor];
    [self.takePhotoBtn setTitle:@"拍 照" forState:UIControlStateNormal];
    [self.takePhotoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.takePhotoBtn addTarget:self action:@selector(takePhotoButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.takePhotoBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(80));
        make.height.equalTo(@(30));
        //make.left.equalTo(self.view).offset(20);
        make.centerX.equalTo(bottomView);
        make.bottom.equalTo(bottomView).offset(-10);
    }];
    
    //确定使用照片
    self.confirmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [bottomView addSubview:self.confirmBtn];
    self.confirmBtn.backgroundColor = [UIColor clearColor];
    [self.confirmBtn setTitle:@"使用照片" forState:UIControlStateNormal];
    [self.confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.confirmBtn addTarget:self action:@selector(confirmBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.confirmBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(_w / 4.0));
        make.height.equalTo(@(30));
        make.right.equalTo(bottomView);//.offset(-20)
        make.bottom.equalTo(bottomView).offset(-10);
    }];
    
    //重新拍照
    self.againPhotoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [bottomView addSubview:self.againPhotoBtn];
    self.againPhotoBtn.backgroundColor = [UIColor clearColor];
    [self.againPhotoBtn setTitle:@"重 拍" forState:UIControlStateNormal];
    [self.againPhotoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.againPhotoBtn addTarget:self action:@selector(takePhotoAgain:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.againPhotoBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(_w / 4.0));
        make.height.equalTo(@(30));
        make.left.equalTo(bottomView);//.offset(20);
        make.bottom.equalTo(bottomView).offset(-10);
    }];
    
    //涂鸦
    self.drawLineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [bottomView addSubview:self.drawLineBtn];
    self.drawLineBtn.backgroundColor = [UIColor clearColor];
    //[self.drawLineBtn setTitle:@"涂 鸦" forState:UIControlStateNormal];
    [self.drawLineBtn setImage:[UIImage imageNamed:@"icon-ty-normal"] forState:UIControlStateNormal];
    [self.drawLineBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.drawLineBtn addTarget:self action:@selector(drawLine:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.drawLineBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(_w / 4.0));
        make.height.equalTo(@(30));
        make.left.equalTo(self.againPhotoBtn.mas_right);//.offset(0);
        make.bottom.equalTo(bottomView).offset(-10);
    }];
    
    //马赛克
    self.mosaicBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [bottomView addSubview:self.mosaicBtn];
    self.mosaicBtn.backgroundColor = [UIColor clearColor];
    //[self.mosaicBtn setTitle:@"马赛克" forState:UIControlStateNormal];
    [self.mosaicBtn setImage:[UIImage imageNamed:@"icon-mosaic-normal"] forState:UIControlStateNormal];
    [self.mosaicBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.mosaicBtn addTarget:self action:@selector(addMosaic:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.mosaicBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(_w / 4.0));//60
        make.height.equalTo(@(30));
        make.right.equalTo(self.confirmBtn.mas_left);//.offset(-80);
        make.bottom.equalTo(bottomView).offset(-10);
    }];
    
    self.confirmBtn.hidden = YES;
    self.againPhotoBtn.hidden = YES;
    self.drawLineBtn.hidden = YES;
    self.mosaicBtn.hidden = YES;
}

@end
