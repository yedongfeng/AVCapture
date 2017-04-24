//
//  AVCaptureVC.m
//  自定义相机拍照
//
//  Created by 肖欣然 on 17/4/7.
//  Copyright © 2017年 肖欣然. All rights reserved.
//

#import "AVCaptureVC.h"
//AVFoundation
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
//屏幕方向判断
#import <CoreMotion/CoreMotion.h>
//图片信息写入，经纬度等
#import <ImageIO/ImageIO.h>
//定位功能
#import <CoreLocation/CoreLocation.h>
//马赛克
#import "MosaicView.h"
//画线
#import "DrawLine.h"
//UI约束
#import "Masonry.h"

@interface AVCaptureVC ()<CLLocationManagerDelegate>
{
    NSData *_jpegData;//保存图片数据
    
    CMSampleBufferRef _imageDataSampleBuffer;
    
    AVCaptureVideoOrientation _avcaptureOrientation;
    
    takePhotoBlock _takePhotoBlock;
}

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
 *  预览图层
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer    *previewLayer;

/**
 *  对焦view
 */
@property (nonatomic, strong) UIView                        *focusView;

/**
 *  判断屏幕方向
 */
@property (nonatomic, strong) CMMotionManager               *cmmotionManager;

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
 *  定位功能，保存图片信息
 */
@property (nonatomic, strong) CLLocationManager             *locationManager;
@property (nonatomic, strong) CLLocation                    *cllLocation;

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

@implementation AVCaptureVC

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //隐藏=YES,显示=NO; Animation:动画效果
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    if(self.session)
    {
        [self.session startRunning];
    }
    
    //监听对焦
    if(self.device == nil)
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    int flags = NSKeyValueObservingOptionNew;
    [self.device addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if(self.session)
    {
        [self.session stopRunning];
    }
    
    //隐藏=YES,显示=NO; Animation:动画效果
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    
    //监听对焦
    if(self.device == nil)
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    [self.device removeObserver:self forKeyPath:@"adjustingFocus"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //一些初始化工作
    [self initData];
    
    //布局
    [self initUI];
}

#pragma mark -初始化数据
- (void)initData
{
    //判断屏幕方向
    self.cmmotionManager = [[CMMotionManager alloc] init];
    //self.cmmotionManager.accelerometerUpdateInterval = 1.0 / 30.0;
    
    //定位
    if(self.isLocation)
    {
        if([CLLocationManager locationServicesEnabled])
        {
            self.locationManager = [[CLLocationManager alloc] init];
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            self.locationManager.distanceFilter = 1.0f;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            self.locationManager.delegate = self;
            
            [self.locationManager startUpdatingLocation];
            if([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
            {
                //[self.locationManager requestAlwaysAuthorization]; // 永久授权
                [self.locationManager requestWhenInUseAuthorization]; //使用中授权
            }
        }
    }
    
    //自定义相机，AVCapture初始化
    [self initAVCaptureSession];
    
    [self startAccelerometerUpdates];
    
}

//初始化一些相机对象
- (void)initAVCaptureSession
{
    self.session = [[AVCaptureSession alloc] init];
    
    if(self.device == nil)
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    //更改闪光灯设置时需要将设备锁定，然后再解锁
    [self.device lockForConfiguration:nil];
    if ([self.device hasFlash])
    {
        [self.device setFlashMode:AVCaptureFlashModeOff];
    }
    [self.device unlockForConfiguration];
    
    NSError *error;
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:&error];
    if(error)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:[NSString stringWithFormat:@"初始数据出错：%@",error] delegate:nil cancelButtonTitle:@"" otherButtonTitles:nil, nil];
        [alert show];
    }
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    if([self.session canAddInput:self.input])
    {
        [self.session addInput:self.input];
    }
    
    if([self.session canAddOutput:self.stillImageOutput])
    {
        [self.session addOutput:self.stillImageOutput];
    }
}

//启动cmmotion
- (void)startAccelerometerUpdates
{
    if([self.cmmotionManager isDeviceMotionAvailable])
    {
        [self.cmmotionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
            CMAcceleration acceleration = accelerometerData.acceleration;
            if (acceleration.x >= 0.75)
            {
                //home button left
                _avcaptureOrientation = (AVCaptureVideoOrientation)UIDeviceOrientationLandscapeRight;
            }
            
            else if (acceleration.x <= -0.75)
            {
                //home button right
                _avcaptureOrientation = (AVCaptureVideoOrientation)UIDeviceOrientationLandscapeLeft;
            }
            else if (acceleration.y <= -0.75)
            {
                _avcaptureOrientation = (AVCaptureVideoOrientation)UIDeviceOrientationPortrait;
            }
            
            else if (acceleration.y >= 0.75)
            {
                _avcaptureOrientation = (AVCaptureVideoOrientation)UIDeviceOrientationPortraitUpsideDown;
            }
            else
            {
                // Consider same as last time
                _avcaptureOrientation = AVCaptureVideoOrientationPortrait;
            }
        }];
    }
}

#pragma mark -返回拍照得到的图片
- (void)takePhoto:(takePhotoBlock)block
{
    _takePhotoBlock = block;
}

#pragma mark -按钮事件
//开启或关闭闪光灯
-(void)onOrOffLight:(UIButton *)sender
{
    //修改前必须先锁定
    [self.device lockForConfiguration:nil];
    //必须判定是否有闪光灯，否则如果没有闪光灯会崩溃
    if ([self.device hasFlash])
    {
        if (self.device.flashMode == AVCaptureFlashModeOff)
        {
            self.device.flashMode = AVCaptureFlashModeOn;
            [self.lightBtn setImage:[UIImage imageNamed:@"icon-flash-open"] forState:UIControlStateNormal];
        }
        else
        {
            self.device.flashMode = AVCaptureFlashModeOff;
            [self.lightBtn setImage:[UIImage imageNamed:@"icon-flash-close"] forState:UIControlStateNormal];
        }
    }
    else
    {
        NSLog(@"设备不支持闪光灯");
    }
    
    [self.device unlockForConfiguration];
}

//拍照
- (void)takePhotoButtonClick:(UIButton *)sender
{
    AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [stillImageConnection setVideoOrientation:_avcaptureOrientation];
    [stillImageConnection setVideoScaleAndCropFactor:1];
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
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
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
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
        AVCaptureDevicePosition possion = [[self.input device] position];
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
            [self.session beginConfiguration];
            [self.session removeInput:self.input];
            if([self.session canAddInput:newInput])
            {
                [self.session addInput:newInput];
                self.input = newInput;
            }
            else
            {
                [self.session addInput:self.input];
            }
            
            [self.session commitConfiguration];
            
            [self.device removeObserver:self forKeyPath:@"adjustingFocus"];
            self.device = newCamera;
            int flags = NSKeyValueObservingOptionNew;
            [self.device addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
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
    [self dismissViewControllerAnimated:YES completion:^{
        if(_takePhotoBlock)
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
            
            _takePhotoBlock(image,[self imageMetadata]);
        }
    }];
}

#pragma mark -对焦事件
//监听对焦
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if(self.device.adjustingFocus)
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
    if(self.device == nil)
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }

    CGSize size = self.view.bounds.size;
    CGPoint focusPoint = CGPointMake(point.y / size.height ,1 - point.x / size.width);
    NSError *error;
    
    if ([self.device lockForConfiguration:&error])
    {
        //对焦模式和对焦点
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
        {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
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
        if ([self.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ])
        {
            [self.device setExposurePointOfInterest:focusPoint];
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        self.focusView.center = point;
        [self.device unlockForConfiguration];
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
        CGPoint point = [touch locationInView:self.view];
        [self focusAtPoint:point];
    }
}

#pragma mark -显示拍照成功的图片
- (void)showImage
{
    UIImage *img = [[UIImage alloc] initWithData:_jpegData];
    self.currentImage = img;
    
    CGFloat imageW = img.size.width;
    CGFloat imageH = img.size.height;
    
    CGFloat w = self.view.frame.size.width;
    CGFloat h = self.view.frame.size.height - 120.0;
    
    CGFloat logoH = 45;
    CGFloat logoW = 0;
    
    if(!self.imageView)
    {
        self.imageView = [[UIImageView alloc] init];
        [self.view addSubview:self.imageView];
        self.imageView.hidden = YES;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        //水印 
        if(self.isLogo)
        {
            self.logoView = [[UIView alloc] init];
            self.logoView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2];
            [self.imageView addSubview:self.logoView];
            
            NSString *dateString = [self dateString];
            UIFont *dateFont = [UIFont systemFontOfSize:12];
            UIFont *logoFont = [UIFont systemFontOfSize:14];
            CGSize dateSize = [self sizeOfString:dateString stringFont:dateFont];
            CGSize logoSize = [self sizeOfString:self.logoString stringFont:logoFont];
            logoW = dateSize.width + 60 ? logoSize.width + 60 : dateSize.width > logoSize.width;
            
            UILabel *timeLab = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, logoW, 20)];
            timeLab.text = dateString;
            timeLab.font = dateFont;
            timeLab.textColor = [UIColor whiteColor];
            timeLab.textAlignment = NSTextAlignmentCenter;
            [self.logoView addSubview:timeLab];
            
            UILabel *logoLab = [[UILabel alloc] initWithFrame:CGRectMake(38, 25, logoSize.width, 20)];
            logoLab.text = self.logoString;
            logoLab.font = logoFont;
            logoLab.textColor = [UIColor whiteColor];
            logoLab.textAlignment = NSTextAlignmentRight;
            [self.logoView addSubview:logoLab];
            
            UIImageView *logoImg = [[UIImageView alloc] initWithFrame:CGRectMake(10, 23, 18, 18)];
            [self.logoView addSubview:logoImg];
            logoImg.layer.cornerRadius = 3.0;
            logoImg.layer.masksToBounds = YES;
            logoImg.image = self.logoImage;
        }
    }
    
    if(imageW > imageH)
    {
        h = w * w / h;//w * imageH / imageW
    }
    /*
     bug处理：高度原本是小数，加了约束之后，view的高度会四舍五入取整，比如h=228.55,view实际高度成了229。如果view约束高度比h大，保存图片时会造成四周有留白。暂未找到解决约束的办法，只能先处理高度。
     */
    CGFloat f = h - (NSInteger)h;
    h = h - f;
    
    CGFloat s = 0;
    if(imageW / w < imageH / h)
    {
        s = imageW / w;
    }
    else
    {
        s = imageH / h;
    }
    
    UIImageOrientation or = img.imageOrientation;
    
    CGRect rect;
    if(or == UIImageOrientationUp)
    {
        rect = CGRectMake((imageW - w * s) / 2.0, (imageH - h * s) / 2.0, w * s, h * s);
    }
    else if(or == UIImageOrientationRight)
    {
        rect = CGRectMake((imageH - h * s) / 2.0, (imageW - w * s) / 2.0, h * s, w * s);
    }
    else if(or == UIImageOrientationLeft)
    {
        rect = CGRectMake((imageH - h * s) / 2.0, (imageW - w * s) / 2.0, h * s, w * s);
    }
    else if(or == UIImageOrientationDown)
    {
        rect = CGRectMake((imageH - h * s) / 2.0, (imageW - w * s) / 2.0, w * s, h * s);
    }
    
    CGImageRef subImageRef = CGImageCreateWithImageInRect([img CGImage], rect);
    UIImage *smallImage = [UIImage imageWithCGImage:subImageRef scale:img.scale orientation:or];
    CGImageRelease(subImageRef);
    
    if(smallImage)
    {
        self.imageView.backgroundColor = [UIColor clearColor];
        self.imageView.image = smallImage;
    }
    
    [self.imageView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(h));
        make.center.equalTo(self.view);
        make.left.right.equalTo(self.view);
    }];
    
    [self.logoView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(logoW));
        make.height.equalTo(@(logoH));
        make.centerX.equalTo(self.imageView);
        make.bottom.equalTo(self.imageView).offset(-10);
    }];
    
    //马赛克
    if(!self.mosaicView)
    {
        self.mosaicView = [[MosaicView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
        [self.view addSubview:self.mosaicView];
    }
    
    [self.mosaicView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(h));
        make.center.equalTo(self.view);
        make.left.right.equalTo(self.view);
    }];
    
    //涂鸦
    if(!self.drawLine)
    {
        self.drawLine = [[DrawLine alloc] init];
        [self.view addSubview:self.drawLine];
        self.drawLine.backgroundColor = [UIColor clearColor];
        [self.drawLine setBrushColorWithRed:1.0 green:0.0 blue:0.0];
    }
    
    [self.drawLine mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(h));
        make.center.equalTo(self.view);
        make.left.right.equalTo(self.view);
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
    
    self.currentImage = [self imageWithlogoImageView];
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

#pragma mark -保存图片
- (void)saveImage
{
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                _imageDataSampleBuffer,
                                                                kCMAttachmentMode_ShouldPropagate);
    
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied)
    {
        //无权限
        return ;
    }
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    [library writeImageDataToSavedPhotosAlbum:_jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
        if(error)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:[NSString stringWithFormat:@"保存图片出错：%@",error] delegate:nil cancelButtonTitle:@"" otherButtonTitles:nil, nil];
            [alert show];
        }
        else
        {
            [self dismissViewControllerAnimated:YES completion:^{
                //返回图片
            }];
            
        }
    }];
}

#pragma mark -计算宽度
- (CGSize)sizeOfString:(NSString *)str stringFont:(UIFont *)font
{
    NSDictionary *attrs = @{NSFontAttributeName:font};
    CGSize size = [str sizeWithAttributes:attrs];
    
    return size;
}

#pragma mark -返回当前的时间
- (NSString *)timeString
{
    NSString *str = @"";
    
    NSDateComponents *dateComponent = [self dateComponent];
    NSInteger hour = [dateComponent hour];
    NSInteger minute = [dateComponent minute];
    
    str = [NSString stringWithFormat:@"%02ld:%02ld",hour,minute];
    
    return str;
}

- (NSString *)dateString
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

#pragma mark -设置图片经纬度信息
- (NSDictionary *)imageMetadata
{
    NSMutableDictionary *metaDataDic = [NSMutableDictionary dictionary];
    

    //GPS
    NSMutableDictionary *gpsDic = [NSMutableDictionary dictionary];
    [gpsDic setObject:[NSNumber numberWithDouble:self.cllLocation.coordinate.latitude] forKey:(NSString *)kCGImagePropertyGPSLatitude];
    [gpsDic setObject:[NSNumber numberWithDouble:self.cllLocation.coordinate.longitude] forKey:(NSString *)kCGImagePropertyGPSLongitude];
    [metaDataDic setObject:gpsDic forKey:(NSString *)kCGImagePropertyGPSDictionary];
    
    //其他exif信息
    NSMutableDictionary *exifDic =[[metaDataDic objectForKey:(NSString*)kCGImagePropertyExifDictionary] mutableCopy];
    if(!exifDic)
    {
        exifDic = [NSMutableDictionary dictionary];
    }
    NSDateFormatter *dateFormatter =[[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSString *createdDate =[dateFormatter stringFromDate:[NSDate date]];
    [exifDic setObject:createdDate forKey:(NSString*)kCGImagePropertyExifDateTimeDigitized];
    [metaDataDic setObject:exifDic forKey:(NSString*)kCGImagePropertyExifDictionary];
     
    /*
    NSMutableDictionary *exifDic = [[metaDataDic objectForKey:(NSString*)kCGImagePropertyExifDictionary] mutableCopy];
    if(!exifDic)
    {
        exifDic = [NSMutableDictionary dictionary];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY:MM:dd hh:mm:ss"];
    NSString *now = [formatter stringFromDate:[NSDate date]];
    [exifDic setValue:now forKey:(NSString*)kCGImagePropertyExifDateTimeOriginal];
    [exifDic setValue:now forKey:@"DateTimeDigitized"];
    [exifDic setValue:now forKey:@"DateTimeOriginal"];
    [metaDataDic setValue:exifDic forKey:@"{Exif}"];

    NSMutableDictionary *gpsDic = [NSMutableDictionary dictionary];
    [gpsDic setObject:[NSNumber numberWithDouble:self.cllLocation.coordinate.latitude] forKey:(NSString *)kCGImagePropertyGPSLatitude];
    [gpsDic setObject:[NSNumber numberWithDouble:self.cllLocation.coordinate.longitude] forKey:(NSString *)kCGImagePropertyGPSLongitude];
    
    
    
    [metaDataDic setObject:gpsDic forKey:@"{GPS}"];
    */


    
    
    
    
    
    
    return metaDataDic;
}

- (NSMutableData *)setGPSToImageByLat:(double)lat longi:(double)longi imgData:(NSData *)data
{
    if(!data || data.length == 0)
    {
        return nil;
    }
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    NSDictionary *dict = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    
    NSMutableDictionary *metaDataDic = [dict mutableCopy];
    
    //GPS
    NSMutableDictionary *gpsDic = [NSMutableDictionary dictionary];
    [gpsDic setObject:[NSNumber numberWithDouble:lat] forKey:(NSString *)kCGImagePropertyGPSLatitude];
    [gpsDic setObject:[NSNumber numberWithDouble:longi] forKey:(NSString *)kCGImagePropertyGPSLongitude];
    [metaDataDic setObject:gpsDic forKey:(NSString *)kCGImagePropertyGPSDictionary];
    
    //其他exif信息
    NSMutableDictionary *exifDic =[[metaDataDic objectForKey:(NSString*)kCGImagePropertyExifDictionary] mutableCopy];
    if(!exifDic)
    {
        exifDic = [NSMutableDictionary dictionary];
    }
    NSDateFormatter *dateFormatter =[[NSDateFormatter alloc]init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSString *createdDate =[dateFormatter stringFromDate:[NSDate date]];
    [exifDic setObject:createdDate forKey:(NSString*)kCGImagePropertyExifDateTimeDigitized];
    [metaDataDic setObject:exifDic forKey:(NSString*)kCGImagePropertyExifDictionary];
    
    //写进图片
    CFStringRef UTI = CGImageSourceGetType(source);
    NSMutableData *data2 = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data2, UTI, 1,NULL);
    if(!destination)
    {
        return nil;
    }
    
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)metaDataDic);
    if(!CGImageDestinationFinalize(destination))
    {
        return nil;
    }
    
    return data2;
}

#pragma mark -定位delegate
/** 获取到新的位置信息时调用*/
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [manager stopUpdatingLocation];
    
    self.cllLocation = locations[0];
    NSLog(@"定位到了");
}
/** 不能获取位置信息时调用*/
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [manager stopUpdatingHeading];
    
    NSLog(@"获取定位失败");
}

#pragma mark -获取设备方向delegate
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation
{
    return AVCaptureVideoOrientationPortrait;
    
}

#pragma mark -初始化ui
- (void)initUI
{
    self.view.backgroundColor = [UIColor blackColor];
    
    //初始化预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    CGFloat w = self.view.frame.size.width;
    CGFloat h = self.view.frame.size.height;
    
    //页面有作禁止横屏处理，但如果前面页面是横屏，这时候w和h仍然是横屏时候的值
    if(w > h)
    {
        w = self.view.frame.size.height;
        h = self.view.frame.size.width;
    }
    
    self.previewLayer.frame = CGRectMake(0, 60, w, h - 120);
    self.view.layer.masksToBounds = YES;
    [self.view.layer addSublayer:self.previewLayer];
    
    //对焦动画
    CGFloat viewW = self.view.frame.size.width;
    CGFloat viewH = self.view.frame.size.height;
    CGFloat focusViewW = 120;
    self.focusView = [[UIView alloc] initWithFrame:CGRectMake((viewW - focusViewW) / 2.0, (viewH - focusViewW) / 2.0, 80, 80)];
    [self.view addSubview:self.focusView];
    self.focusView.hidden = YES;
    self.focusView.backgroundColor = [UIColor clearColor];
    self.focusView.layer.borderColor = [UIColor yellowColor].CGColor;
    self.focusView.layer.borderWidth = 0.5;
    
    //拍照按钮
    self.takePhotoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.takePhotoBtn];
    self.takePhotoBtn.backgroundColor = [UIColor clearColor];
    [self.takePhotoBtn setTitle:@"拍 照" forState:UIControlStateNormal];
    [self.takePhotoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.takePhotoBtn addTarget:self action:@selector(takePhotoButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.takePhotoBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(80));
        make.height.equalTo(@(30));
        //make.left.equalTo(self.view).offset(20);
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view).offset(-10);
    }];
    
    //取消按钮
    self.cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.cancelBtn];
    self.cancelBtn.backgroundColor = [UIColor clearColor];
    [self.cancelBtn setTitle:@"取 消" forState:UIControlStateNormal];
    [self.cancelBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.cancelBtn addTarget:self action:@selector(cancelButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.cancelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(80));
        make.height.equalTo(@(30));
        make.left.equalTo(self.view).offset(20);
        make.top.equalTo(self.view).offset(15);
    }];
    
    //闪光灯
    if(!self.device)
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    if ([self.device hasFlash])
    {
        self.lightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.lightBtn setImage:[UIImage imageNamed:@"icon-flash-close"] forState:UIControlStateNormal];
        [self.lightBtn addTarget:self action:@selector(onOrOffLight:) forControlEvents:UIControlEventTouchDown];
        [self.view addSubview:self.lightBtn];
        
        [self.lightBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view);
            make.width.equalTo(@(80));
            make.height.equalTo(@(30));
            make.top.equalTo(self.view).offset(15);
        }];
    }
    
    //切换前后摄像头
    self.switchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.switchBtn];
    self.switchBtn.backgroundColor = [UIColor clearColor];
    [self.switchBtn setTitle:@"切 换" forState:UIControlStateNormal];
    [self.switchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.switchBtn addTarget:self action:@selector(switchButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.switchBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(80));
        make.height.equalTo(@(30));
        make.right.equalTo(self.view).offset(-20);
        make.top.equalTo(self.view).offset(15);
    }];

    
    //确定使用照片
    self.confirmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.confirmBtn];
    self.confirmBtn.backgroundColor = [UIColor clearColor];
    [self.confirmBtn setTitle:@"使用照片" forState:UIControlStateNormal];
    [self.confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.confirmBtn addTarget:self action:@selector(confirmBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.confirmBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(w / 4.0));
        make.height.equalTo(@(30));
        make.right.equalTo(self.view);//.offset(-20)
        make.bottom.equalTo(self.view).offset(-10);
    }];
    
    //重新拍照
    self.againPhotoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.againPhotoBtn];
    self.againPhotoBtn.backgroundColor = [UIColor clearColor];
    [self.againPhotoBtn setTitle:@"重 拍" forState:UIControlStateNormal];
    [self.againPhotoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.againPhotoBtn addTarget:self action:@selector(takePhotoAgain:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.againPhotoBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(w / 4.0));
        make.height.equalTo(@(30));
        make.left.equalTo(self.view);//.offset(20);
        make.bottom.equalTo(self.view).offset(-10);
    }];
    
    //涂鸦
    self.drawLineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.drawLineBtn];
    self.drawLineBtn.backgroundColor = [UIColor clearColor];
    //[self.drawLineBtn setTitle:@"涂 鸦" forState:UIControlStateNormal];
    [self.drawLineBtn setImage:[UIImage imageNamed:@"icon-ty-normal"] forState:UIControlStateNormal];
    [self.drawLineBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.drawLineBtn addTarget:self action:@selector(drawLine:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.drawLineBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(w / 4.0));
        make.height.equalTo(@(30));
        make.left.equalTo(self.againPhotoBtn.mas_right);//.offset(0);
        make.bottom.equalTo(self.view).offset(-10);
    }];
    
    //马赛克
    self.mosaicBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:self.mosaicBtn];
    self.mosaicBtn.backgroundColor = [UIColor clearColor];
    //[self.mosaicBtn setTitle:@"马赛克" forState:UIControlStateNormal];
    [self.mosaicBtn setImage:[UIImage imageNamed:@"icon-mosaic-normal"] forState:UIControlStateNormal];
    [self.mosaicBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.mosaicBtn addTarget:self action:@selector(addMosaic:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.mosaicBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(w / 4.0));//60
        make.height.equalTo(@(30));
        make.right.equalTo(self.confirmBtn.mas_left);//.offset(-80);
        make.bottom.equalTo(self.view).offset(-10);
    }];
    
    self.confirmBtn.hidden = YES;
    self.againPhotoBtn.hidden = YES;
    self.drawLineBtn.hidden = YES;
    self.mosaicBtn.hidden = YES;
}

- (void)setLogoImage:(UIImage *)logoImage
{
    if(logoImage)
    {
        _logoImage = logoImage;
        _isLogo = YES;
    }
}

- (void)setLogoString:(NSString *)logoString
{
    if(logoString.length > 0)
    {
        _logoString = logoString;
        _isLogo = YES;
    }
}

#pragma mark -隐藏和显示状态栏
- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
    
    //UIStatusBarStyleDefault = 0 黑色文字，浅色背景时使用
    //UIStatusBarStyleLightContent = 1 白色文字，深色背景时使用
}

#pragma mark -禁止横屏
- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
