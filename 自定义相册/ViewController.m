//
//  ViewController.m
//  自定义相册
//
//  Created by beok on 17/4/7.
//  Copyright © 2017年 beok. All rights reserved.
//

#import "ViewController.h"

#import "AVCaptureVC.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate>



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"测试相机";
    self.view.backgroundColor = [UIColor whiteColor];

    //ui
    [self initUI];
    

}

#pragma mark -初始化ui
- (void)initUI
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(100, 120,80, 40);
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor blueColor].CGColor;
    [btn setTitle:@"拍照" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btn];

}


#pragma mark -点击事件，打开自定义的相机
- (void)click:(UIButton *)sender
{
    /*
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:^(void){
        NSLog(@"Picker View Controller is presented");
    }];
    */


    
    AVCaptureVC *vc = [[AVCaptureVC alloc] init];
    vc.logoString = @"我在深圳...";
    vc.logoImage = [UIImage imageNamed:@"29x29"];
    vc.isLogo = YES;
    vc.isLocation = YES;
    [vc takePhoto:^(UIImage *image,NSDictionary *imageMetadata) {
        if(image)
        {
            //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            
            __block ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
            [lib writeImageToSavedPhotosAlbum:image.CGImage metadata:imageMetadata completionBlock:^(NSURL *assetURL, NSError *error) {
                NSLog(@"assetURL = %@, error = %@", assetURL, error);
                lib = nil;
                
            }];
        }
    }];

    [self presentViewController:vc animated:YES completion:^{
        
    }];
     
    
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSURL *assetURL = [info objectForKey:UIImagePickerControllerReferenceURL];
    //2. 创建一个ALAssetsLibrary
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    //3. 使用回调方法,得到字典类型的metadata
    [library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        NSDictionary *imageMetadata = [[NSMutableDictionary alloc] initWithDictionary:asset.defaultRepresentation.metadata];
        
        NSLog(@"metadata:--%@",imageMetadata);
        
        NSDictionary *gpsDic = [imageMetadata objectForKey:@"{GPS}"];
        NSDictionary *exifDic = [imageMetadata objectForKey:@"{Exif}"];
        NSDictionary *tiffDic = [imageMetadata objectForKey:@"{TIFF}"];
        
        //可交换图像文件
        NSLog(@"Exif info:--%@",exifDic);
        //地理位置信息
        NSLog(@"GPS info:--%@",gpsDic);
        
        /*
         {
         ApertureValue = "2.275007124536905";
         BrightnessValue = "-0.8228139381985535";
         ColorSpace = 1;
         ComponentsConfiguration =     (
         1,
         2,
         3,
         0
         );
         DateTimeDigitized = "2017:04:16 22:11:12";
         DateTimeOriginal = "2017:04:16 22:11:12";
         ExifVersion =     (
         2,
         2,
         1
         );
         ExposureBiasValue = 0;
         ExposureMode = 0;
         ExposureProgram = 2;
         ExposureTime = "0.05882352941176471";
         FNumber = "2.2";
         Flash = 16;
         FlashPixVersion =     (
         1,
         0
         );
         FocalLenIn35mmFilm = 29;
         FocalLength = "4.15";
         ISOSpeedRatings =     (
         400
         );
         LensMake = Apple;
         LensModel = "iPhone SE back camera 4.15mm f/2.2";
         LensSpecification =     (
         "4.15",
         "4.15",
         "2.2",
         "2.2"
         );
         MeteringMode = 3;
         PixelXDimension = 4032;
         PixelYDimension = 3024;
         SceneCaptureType = 0;
         SceneType = 1;
         SensingMethod = 2;
         ShutterSpeedValue = "4.059158134243458";
         SubjectArea =     (
         2041,
         2298,
         753,
         756
         );
         SubsecTimeDigitized = 045;
         SubsecTimeOriginal = 045;
         WhiteBalance = 0;
         }
         */
        
        /*
         {
         Altitude = "23.83380281690141";
         AltitudeRef = 0;
         DateStamp = "2017:04:16";
         DestBearing = "272.3079470198675";
         DestBearingRef = T;
         HPositioningError = 10;
         ImgDirection = "272.3079470198675";
         ImgDirectionRef = T;
         Latitude = "22.58097833333333";
         LatitudeRef = N;
         Longitude = "113.8685133333333";
         LongitudeRef = E;
         Speed = 0;
         SpeedRef = K;
         TimeStamp = "14:11:10";
         }
         */
        //图像文件格式
        NSLog(@"tiff info:--%@",tiffDic);
        
    } failureBlock:^(NSError *error) {
        
    }];
    
    [picker dismissViewControllerAnimated:YES completion:^()
     {

     }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
