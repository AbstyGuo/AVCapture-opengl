//
//  CaptureViewController.m
//  AVCapture+opengl
//
//  Created by guoyf on 2018/3/13.
//  Copyright © 2018年 guoyf. All rights reserved.
//

#import "CaptureViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import "OpenGLView.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

@interface CaptureViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate,CLLocationManagerDelegate>

@property (nonatomic, strong) dispatch_queue_t videoQueue;                              //视频输出的代理队列
//
@property (strong, nonatomic) AVCaptureSession *captureSession;                         //负责输入和输出设备之间的数据传递的会话
//
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;                         //视频输入
//
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;                         //声音输入
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;                    //视频输出
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;                    //音频输出

@property (strong, nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;       //照片输出流

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;      //预览图层

@property (strong, nonatomic) CMMotionManager *motionManager;

@property (nonatomic,strong) CLLocationManager * locationManager;

@property (nonatomic,strong) OpenGLView * openglView;

@property (nonatomic,strong) CLLocation * location;



@end

@implementation CaptureViewController

#pragma mark - 懒加载
- (AVCaptureSession *)captureSession
{
    if (_captureSession == nil)
    {
        _captureSession = [[AVCaptureSession alloc] init];
        
        if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh])
        {
            _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        }
    }
    
    return _captureSession;
}

- (dispatch_queue_t)videoQueue
{
    if (!_videoQueue)
    {
        _videoQueue = dispatch_get_main_queue();
    }
    
    return _videoQueue;
}

- (CMMotionManager *)motionManager
{
    if (!_motionManager)
    {
        _motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

-(CLLocationManager *)locationManager{
    if (!_locationManager)
    {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}

#pragma mark - 控制器方法
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 隐藏状态栏
    //    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    [UIApplication sharedApplication].statusBarHidden = YES;
    
    _openglView = [[OpenGLView alloc] initWithFrame:self.view.bounds];
    _openglView.userInteractionEnabled = NO;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //检测相机权限
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        [self requestAuthorizationForVideo];
    }
    
    //检测麦克风权限
    authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        [self requestAuthorizationForVideo];
    }

    [self initAVCaptureSession];
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
    [self.captureVideoPreviewLayer addSublayer:_openglView.layer];
    //开启定位和motion
    [self startManager];
    
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    
    [self.locationManager startUpdatingHeading];
    [self.locationManager startUpdatingLocation];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self startSession];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self stopSession];
}

#pragma mark - 初始化相关
/**
 *  初始化AVCapture会话
 */
- (void)initAVCaptureSession
{
    //1、添加 "视频" 与 "音频" 输入流到session
    [self setupVideo];
    
    [self setupAudio];
    
    //2、添加图片，movie输出流到session
    [self setupCaptureStillImageOutput];
    
    //3、创建视频预览层，用于实时展示摄像头状态
    [self setupCaptureVideoPreviewLayer];
    
    //设置静音状态也可播放声音
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
}

/**
 *  设置视频输入
 */
- (void)setupVideo
{
    //获得指定位置的摄像头
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (!captureDevice)
    {
        NSLog(@"取得后置摄像头时出现问题.");
        
        return;
    }
    
    NSError *error = nil;
    //取得设备输入videoInput对象
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error)
    {
        NSLog(@"取得设备输入videoInput对象时出错，错误原因：%@", error);
        
        return;
    }
    
    //3、将设备输入对象添加到会话中
    if ([self.captureSession canAddInput:self.videoInput])
    {
        [self.captureSession addInput:self.videoInput];
    }
    
    //初始化视频输出
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES; //立即丢弃旧帧，节省内存，默认YES
    //设置视频输出的代理和代理队列
    [self.videoOutput setSampleBufferDelegate:self queue:self.videoQueue];
    
    //3、将设备输出对象添加到会话中
    if ([self.captureSession canAddOutput:self.videoOutput])
    {
        [self.captureSession addOutput:self.videoOutput];
    }
}

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras)
    {
        if ([camera position] == position)
        {
            return camera;
        }
    }
    return nil;
}

/**
 *  设置音频录入
 */
- (void)setupAudio
{
    NSError *error = nil;
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    if (error)
    {
        NSLog(@"取得设备输入audioInput对象时出错，错误原因：%@", error);
        
        return;
    }
    if ([self.captureSession canAddInput:self.audioInput])
    {
        [self.captureSession addInput:self.audioInput];
    }
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:self.videoQueue];
    if([self.captureSession canAddOutput:self.audioOutput])
    {
        [self.captureSession addOutput:self.audioOutput];
    }
}

/**
 *  设置图片输出
 */
- (void)setupCaptureStillImageOutput
{
    self.captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{
                                     AVVideoCodecKey:AVVideoCodecJPEG
                                     };
    [_captureStillImageOutput setOutputSettings:outputSettings];
    
    if ([self.captureSession canAddOutput:_captureStillImageOutput])
    {
        [self.captureSession addOutput:_captureStillImageOutput];
    }
}


/**
 *  设置预览layer
 */
- (void)setupCaptureVideoPreviewLayer
{
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    
    CALayer *layer = self.view.layer;
    
    _captureVideoPreviewLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;           //填充模式
    
    [layer addSublayer:_captureVideoPreviewLayer];
}

/**
 *  开启会话
 */
- (void)startSession
{
    if (![self.captureSession isRunning])
    {
        [self.captureSession startRunning];
    }
}

/**
 *  停止会话
 */
- (void)stopSession
{
    if ([self.captureSession isRunning])
    {
        [self.captureSession stopRunning];
    }
}

- (void)setCaptureVideoPreviewLayerTransformWithScale:(CGFloat)scale
{
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.25f];      //时长最好低于 START_VIDEO_ANIMATION_DURATION
    [self.captureVideoPreviewLayer setAffineTransform:CGAffineTransformMakeScale(scale, scale)];
    [CATransaction commit];
}

-(void)startManager{
    
    if (self.motionManager.isDeviceMotionAvailable == YES) {
        self.motionManager.deviceMotionUpdateInterval = 0.1;
        [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical toQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
            
            /*
             CMDeviceMotion 被分成两部分Gravity和UserAcceleration。还包含一个速率CMRotationRate
             1、Gravity代表重力1g在设备的分布情况
             2、UserAcceleration代表设备运动中的加速度分布情况。
             将前两者相加就等于实际加速度。Gravity的三个轴所受的重力加起来始终等于1g，而UserAcceleration取决于单位时间内动作的幅度大小
             3、CMRotationRate的X，Y,Z分别代表三个轴上的旋转速率，单位为弧度/秒
             4、CMAttitude的三个属性Yaw,Pitch和Roll分别代表左右摆动、俯仰以及滚动
             */
            
            if(motion){
                CMRotationRate rotationRate = motion.rotationRate;
                double rotationX = rotationRate.x;
                double rotationY = rotationRate.y;
                double rotationZ = rotationRate.z;
                
                double value = rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ;
                
                // 防抖处理，阀值以下的朝向改变将被忽略
                if (value > 0.001) {
                    CMAttitude *attitude = motion.attitude;
                    
                    [self.openglView updateWithX:attitude.quaternion.x Y:attitude.quaternion.y Z:attitude.quaternion.z W:attitude.quaternion.w];
                    
                }
            }
        }];
    }    
}

#pragma mark - 代理
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    @autoreleasepool
    {
        
    }
}


/**
 *  开始写入数据
 */
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType
{
    if (sampleBuffer == NULL)
    {
        NSLog(@"empty sampleBuffer");
        return;
    }
}

#pragma mark - 定位相关

// 当获取到用户方向时就会调用
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    NSLog(@"----------------%s", __func__);
    /*
     magneticHeading 设备与磁北的相对角度
     trueHeading 设置与真北的相对角度, 必须和定位一起使用, iOS需要设置的位置来计算真北
     真北始终指向地理北极点
     */
    NSLog(@"********************%f", newHeading.magneticHeading);
    
    
    // 1.将获取到的角度转为弧度 = (角度 * π) / 180;
    CGFloat angle = newHeading.magneticHeading * M_PI / 180;
    
    [self.locationManager stopUpdatingHeading];
    
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    NSLog(@"%lu",(unsigned long)locations.count);
    CLLocation * location = locations.lastObject;

    if (!self.location) {
        self.location = location;
        [_openglView updateLocationWithX:0 Y:0 Z:0];
    }else
    {
        CLLocation * locationX = [[CLLocation alloc] initWithLatitude:location.coordinate.latitude longitude:self.location.coordinate.longitude];
        CLLocation * locationY = [[CLLocation alloc] initWithLatitude:self.location.coordinate.latitude longitude:location.coordinate.longitude];
        
        CGFloat distanceX = [self.location distanceFromLocation:locationX];
        CGFloat distanceY = [self.location distanceFromLocation:locationY];
        CGFloat distanceZ = self.location.horizontalAccuracy-location.horizontalAccuracy;
        
        [_openglView updateLocationWithX:distanceZ Y:distanceZ Z:distanceX];
        
        NSLog(@"-------------------%.2f,%.2f,%.2f",distanceX,distanceY,distanceZ);
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    
    NSString *errorString;
    NSLog(@"定位失败原因: %@",[error localizedDescription]);
    switch([error code]) {
        case kCLErrorLocationUnknown:
            // do something...
            break;
        case kCLErrorDenied:
            // do something...
            break;
        default:
            break;
    }
}


#pragma mark - 请求权限
- (void)requestAuthorizationForVideo
{
    __weak typeof(self) weakSelf = self;
    
    // 请求相机权限
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        if (appName == nil)
        {
            appName = @"APP";
        }
        NSString *message = [NSString stringWithFormat:@"允许%@访问你的相机？", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    // 请求麦克风权限
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (audioAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        if (appName == nil)
        {
            appName = @"APP";
        }
        NSString *message = [NSString stringWithFormat:@"允许%@访问你的麦克风？", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    
}

@end
