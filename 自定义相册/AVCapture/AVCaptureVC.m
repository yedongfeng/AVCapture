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

#import "AVCaptureManager.h"
#import "CaptureView.h"

@interface AVCaptureVC ()<CaptureViewDelegate>
{
    AVCaptureManager *_manager;
    takePhotoBlock _takePhotoBlock;
}

@end

@implementation AVCaptureVC

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //隐藏=YES,显示=NO; Animation:动画效果
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    if(_manager.session)
    {
        [_manager.session startRunning];
    }
    
    /*
    //监听对焦
    if(_manager.device == nil)
    {
        _manager.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    int flags = NSKeyValueObservingOptionNew;
    [_manager.device addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
     */
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //[self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if(_manager.session)
    {
        [_manager.session stopRunning];
    }
    
    //隐藏=YES,显示=NO; Animation:动画效果
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    
    /*
    //监听对焦
    if(_manager.device == nil)
    {
        _manager.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    [_manager.device removeObserver:self forKeyPath:@"adjustingFocus"];
     */
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //一些初始化工作
    [self initData];
    
    //布局
    [self initUI];
}

- (void)takePhoto:(takePhotoBlock)block
{
    _takePhotoBlock = block;
}

- (void)initData
{
    _manager = [AVCaptureManager sharedInstance];
    _manager.isLocation = self.isLocation;
    [_manager setCaptureFlashMode:AVCaptureFlashModeOff];
}

- (void)initUI
{
    CaptureView *captureView = [[CaptureView alloc] init];
    [self.view addSubview:captureView];
    captureView.delegate = self;
    
    captureView.isLogo = self.isLogo;
    captureView.logoImage = self.logoImage;
    captureView.logoString = self.logoString;
    
    [captureView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(self.view);
    }];
}

#pragma mark -CaptureViewDelegate
//取消拍照
- (void)cancelTakePhoto
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

//使用照片
- (void)confirmImage:(UIImage *)image andImageMetadata:(NSDictionary *)imageMetadata
{
    [self dismissViewControllerAnimated:YES completion:^{
        if(_takePhotoBlock)
        {
            _takePhotoBlock(image,imageMetadata);
        }
    }];
}

#pragma mark -显示拍照成功的图片
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
