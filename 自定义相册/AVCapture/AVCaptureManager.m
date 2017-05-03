//
//  AVCaptureManager.m
//  自定义相册
//
//  Created by 肖欣然 on 17/4/24.
//  Copyright © 2017年 肖欣然. All rights reserved.
//

#import "AVCaptureManager.h"

@interface AVCaptureManager ()<CLLocationManagerDelegate>

/**
 *  判断屏幕方向
 */
@property (nonatomic, strong) CMMotionManager               *cmmotionManager;

/**
 *  定位功能，保存图片信息
 */
@property (nonatomic, strong) CLLocationManager             *locationManager;
@property (nonatomic, strong) CLLocation                    *cllLocation;


@end

@implementation AVCaptureManager

#pragma mark -单例初始化
+ (id)sharedInstance
{
    static AVCaptureManager *manager = nil;
    
    static dispatch_once_t dispatch;
    dispatch_once(&dispatch, ^{
        manager = [[AVCaptureManager alloc] init];
    });
    
    return manager;
}

//重写init，初始化数据
- (id)init
{
    if(self = [super init])
    {
        [self initData];
    }
    
    return self;
}

//一些初始化工作
- (void)initData
{
    //判断屏幕方向
    self.cmmotionManager = [[CMMotionManager alloc] init];
    //self.cmmotionManager.accelerometerUpdateInterval = 1.0 / 30.0;
    //启动cmmotion
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
                _avcaptureOrientation = AVCaptureVideoOrientationPortrait;
            }
        }];
    }
    
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
    
    //初始化一些相机对象
    self.session = [[AVCaptureSession alloc] init];
    
    if(self.device == nil)
    {
        self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    //更改闪光灯设置时需要将设备锁定，然后再解锁
    [self setCaptureFlashMode:AVCaptureFlashModeOff];
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

#pragma mark -定位delegate
//定位成功
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [manager stopUpdatingLocation];
    
    self.cllLocation = locations[0];
}

//定位失败
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [manager stopUpdatingHeading];
}

#pragma mark -获取设备方向delegate
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation
{
    return AVCaptureVideoOrientationPortrait;
}

#pragma mark -关闭(开启)闪光灯
- (void)setCaptureFlashMode:(AVCaptureFlashMode)mode
{
    //更改闪光灯设置时需要将设备锁定，然后再解锁
    [self.device lockForConfiguration:nil];
    if ([self.device hasFlash])
    {
        [self.device setFlashMode:mode];
    }
    [self.device unlockForConfiguration];
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
    NSMutableDictionary *exifDic = [[metaDataDic objectForKey:(NSString*)kCGImagePropertyExifDictionary] mutableCopy];
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

#pragma mark -计算宽度
- (CGSize)sizeOfString:(NSString *)str stringFont:(UIFont *)font
{
    NSDictionary *attrs = @{NSFontAttributeName:font};
    CGSize size = [str sizeWithAttributes:attrs];
    
    return size;
}

@end
