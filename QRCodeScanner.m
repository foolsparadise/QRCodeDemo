
//
//  QRCodeScanner
//  foolsparadise
//
//  Created by foolsparadise on 15/10/2017.
//  Copyright © 2017 github.com/foolsparadise All rights reserved.
//

// project forked https://github.com/zhengwenming/WMQRCode
// and i 加了一层蒙版

#import "QRCodeScanner.h"
#import "SVProgressHUD.h"

#define kDeviceVersion [[UIDevice currentDevice].systemVersion floatValue]

#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define kNavbarHeight ((kDeviceVersion>=7.0)? 64 :44 )

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

#define kSCREEN_MAX_LENGTH (MAX(kScreenWidth, kScreenHeight))
#define kSCREEN_MIN_LENGTH (MIN(kScreenWidth, kScreenHeight))

#define IS_IPHONE4 (IS_IPHONE && kSCREEN_MAX_LENGTH < 568.0)
#define IS_IPHONE5 (IS_IPHONE && kSCREEN_MAX_LENGTH == 568.0)
#define IS_IPHONE6 (IS_IPHONE && kSCREEN_MAX_LENGTH == 667.0)
#define IS_IPHONE6P (IS_IPHONE && kSCREEN_MAX_LENGTH == 736.0)

@import AVFoundation;

@interface QRCodeScanner ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,CALayerDelegate> {
    UILabel * introLab;
    BOOL isLightOn;
    UIButton *mineQRCode;
    UIButton *theLightBtn;
    BOOL hasTheVC;
    BOOL isFirst;
    BOOL upOrdown;
    int num;
    AVCaptureVideoPreviewLayer *preView;
    AVCaptureDevice *captureDevice;
    NSTimer * timer;
    UIImageView *codeFrame;
    NSInteger yMove; //所有的Ｙ标，做为将来上下移动使用
}

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,weak) AVCaptureMetadataOutput *output;
@property (nonatomic,retain) UIImageView *lineIV;
/** 非扫描区域的蒙版 */
@property (nonatomic,strong) CALayer *maskLayer;
@end

@implementation QRCodeScanner
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [self dismissViewControllerAnimated:YES completion:^{
        // [[UIApplication sharedApplication]setStatusBarStyle:UIStatusBarStyleDefault];
    }];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
    
    //[[UIApplication sharedApplication]setStatusBarStyle:UIStatusBarStyleDefault];
    viewController.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
    viewController.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
    NSDictionary *attributeDic = [NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], NSForegroundColorAttributeName, [UIFont systemFontOfSize:17.0], NSFontAttributeName, nil];
    navigationController.navigationBar.titleTextAttributes = attributeDic;
}
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!image) {
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    
    ;
    [self dismissViewControllerAnimated:NO completion:^{
        //[[UIApplication sharedApplication]setStatusBarStyle:UIStatusBarStyleDefault];
    }];
    NSString *stringValue = [self stringFromFileImage:image];
    [self checkQRcode:stringValue];
    
}

- (void)rightBarButtonItemPressed:(UIButton *)sender {
    //找系统相册中的一张相片来识别图中二维码
    // if (kDeviceVersion<=7.0) {
    // }
    // else {
    // self.detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    // }
    
    UIImagePickerController *pickCtr = [[UIImagePickerController alloc] init];
    pickCtr.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickCtr.delegate= self;
    pickCtr.allowsEditing = NO;
    pickCtr.navigationBar.titleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], NSForegroundColorAttributeName, nil];
    [self presentViewController:pickCtr animated:YES completion:^{
        
    }];
    NSArray *vcs = self.navigationController.viewControllers;
    NSLog(@"vcs = %@",vcs);
}

-(void)initUI{
    isFirst=YES;
    upOrdown = NO;
    num =0;
    // 自定义导航右按钮，图片
    //    NSString *name = [@"QRCodeScanner.bundle" stringByAppendingPathComponent:@"fromPhoto"];
    //    UIImage *fromPhoto = [UIImage imageNamed:name];
    //    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    //    rightButton.frame = CGRectMake(0, 0, fromPhoto.size.width, fromPhoto.size.height);
    //    [rightButton setImage:fromPhoto forState:UIControlStateNormal];
    //    [rightButton setImage:fromPhoto forState:UIControlStateSelected];
    //    [rightButton addTarget:self action:@selector(rightBarButtonItemPressed:) forControlEvents:UIControlEventTouchUpInside];
    //    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:rightButton];
    // 自定义导航右按钮，文字
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"系统相册" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont systemFontOfSize:15];
    button.frame = CGRectMake(0, 0, 60, 15);
    [button sizeToFit];
    [button addTarget:self action:@selector(rightBarButtonItemPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];

}
- (void)startSessionRightNow:(NSNotification*)notification {
    //[timer resumeTimer];
    [self creatTimer];
    [_session startRunning];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if(isFirst)
    {
        [self creatTimer];
        [_session startRunning];
    }
    isFirst=NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self deleteTimer];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:@"startSession" object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
#pragma mark - 删除timer
- (void)deleteTimer
{
    if (timer) {
        [timer invalidate];
        timer=nil;
    }
}
#pragma mark - 创建timer
- (void)creatTimer
{
    if (!timer) {
        timer=[NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(animation) userInfo:nil repeats:YES];
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(startSessionRightNow:) name:@"startSession" object:nil];
    if (!isFirst) {
        [self creatTimer];
        [_session startRunning];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"QR条码扫描";
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:19],NSForegroundColorAttributeName:[UIColor whiteColor]}];
    self.view.backgroundColor = [UIColor colorWithRed:(0)/255.0 green:(0)/255.0 blue:(0)/255.0 alpha:0.9];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageWithColor:[UIColor clearColor]] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor],
                                                                    NSFontAttributeName : [UIFont boldSystemFontOfSize:17]};
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    [self.navigationItem setLeftBarButtonItem:nil];
    NSString *name = [@"QRCodeScanner.bundle" stringByAppendingPathComponent:@"return_before"];
    UIImage *fromPhoto = [UIImage imageNamed:name];
    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rightButton.frame = CGRectMake(0, 0, 19, 19);
    [rightButton setImage:fromPhoto forState:UIControlStateNormal];
    [rightButton setImage:fromPhoto forState:UIControlStateSelected];
    [rightButton addTarget:self action:@selector(backBefore:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:rightButton];
    yMove = 0;
    [self initUI];
    [self setupDevice];
}
- (void)backBefore:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
-(void)setupDevice{
    __weak typeof(self) weakSelf = self;

    //1.初始化捕捉设备（AVCaptureDevice），类型为AVMediaTypeVideo
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error;
    //2.用captureDevice创建输入流input
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", error.description);
        return ;
    }
    
    //创建会话
    _session = [[AVCaptureSession alloc] init];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];

    if ([_session canAddInput:input]) {
        [_session addInput:input];
    }
    
    //预览视图
    preView = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    //设置预览图层填充方式
    [preView setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    //preView.frame = CGRectMake((self.view.frame.size.width-240)*0.5, 213-kNavbarHeight, 240, 240);
    preView.frame = CGRectMake(0,0,self.view.frame.size.width,self.view.frame.size.height);
    [self.view.layer insertSublayer:preView atIndex:0];
    
    self.maskLayer = [[CALayer alloc]init];
    self.maskLayer.frame = self.view.layer.bounds;
    self.maskLayer.delegate = self;
    [self.view.layer insertSublayer:self.maskLayer above:preView];
    [self.maskLayer setNeedsDisplay];

    
    //输出
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    if ([_session canAddOutput:output]) {
        [_session addOutput:output];
    }
    self.output = output;
    //设置扫描范围
    output.rectOfInterest = CGRectMake(0.2f, 0.2f, 0.8f, 0.8f);
    
        NSArray *arrTypes = output.availableMetadataObjectTypes;
        NSLog(@"%@",arrTypes);
    
    if ([_output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]
        || [_output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeEAN13Code]
        || [_output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeEAN8Code]
        || [_output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeCode128Code]
        ) {
        _output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,
                                        AVMetadataObjectTypeEAN13Code,
                                        AVMetadataObjectTypeEAN8Code,
                                        AVMetadataObjectTypeCode128Code];
        // [_session startRunning];
    } else {
        [_session stopRunning];
//        rightButton.enabled = NO;
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"抱歉!" message:@"相机权限被拒绝，请前往设置-隐私-相机启用此应用的相机权限。" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alert show];
        return;
    }
//    output.metadataObjectTypes = @[@"org.iso.QRCode"];

    //UIImageView *codeFrame = [[UIImageView alloc] initWithFrame:preView.frame];
    codeFrame = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.frame.size.width-240)*0.5, 213-kNavbarHeight+yMove, 240, 240)];
    codeFrame.contentMode = UIViewContentModeScaleAspectFit;
    NSString *name = [@"QRCodeScanner.bundle" stringByAppendingPathComponent:@"saomiaokuang"];

    [codeFrame setImage:[UIImage imageNamed:name]];
    [self.view addSubview:codeFrame];
    
    introLab = [[UILabel alloc] initWithFrame:CGRectMake(preView.frame.origin.x, preView.frame.origin.y + preView.frame.size.height+yMove, preView.frame.size.width, 40)];
    introLab.numberOfLines = 2;
    introLab.text = @"将QR条码放置到下面的框内\n自动识别";
    introLab.textAlignment = NSTextAlignmentCenter;
    introLab.textColor = [UIColor whiteColor];
    introLab.font = [UIFont systemFontOfSize:15];
    introLab.adjustsFontSizeToFitWidth = YES;
    [self.view addSubview:introLab];
    [introLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(weakSelf.view.mas_centerX).mas_offset(0);
        make.top.mas_equalTo(weakSelf.view.mas_top).mas_offset(129.5-kNavbarHeight+yMove);
        make.size.mas_equalTo(CGSizeMake(weakSelf.view.width, 40.5));
    }];
    
    //我的二维码按钮
    mineQRCode = [UIButton buttonWithType:UIButtonTypeCustom];
    mineQRCode.frame = CGRectMake(self.view.frame.size.width / 2 - 100 / 2, introLab.frame.origin.y+introLab.frame.size.height - 5+yMove, 100, introLab.frame.size.height);
    [mineQRCode setTitle:@"我的二维码" forState:UIControlStateNormal];
    [mineQRCode setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [mineQRCode addTarget:self action:@selector(showTheQRCodeOfMine:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:mineQRCode];
    mineQRCode.hidden = YES;
    
    //theLightBtn
    theLightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
 
    theLightBtn.frame = CGRectMake(self.view.frame.size.width / 2 - 100 / 2, mineQRCode.frame.origin.y + mineQRCode.frame.size.height + 20, 100, introLab.frame.size.height);
    NSString *lightName = [@"QRCodeScanner.bundle" stringByAppendingPathComponent:@"shoudian_meiliang"];
    NSString *lightonName = [@"QRCodeScanner.bundle" stringByAppendingPathComponent:@"shoudian_liang"];

    [theLightBtn setImage:[UIImage imageNamed:lightName] forState:UIControlStateNormal];
    [theLightBtn setImage:[UIImage imageNamed:lightonName] forState:UIControlStateSelected];
    [theLightBtn addTarget:self action:@selector(lightOnOrOff:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:theLightBtn];
    [theLightBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(weakSelf.view.mas_centerX).mas_offset(0);
        make.top.mas_equalTo(weakSelf.view.mas_top).mas_offset(mineQRCode.frame.origin.y + mineQRCode.frame.size.height + 20);
        make.size.mas_equalTo(CGSizeMake(36, 36));
    }];
    
    if (![captureDevice isTorchAvailable]) {
        theLightBtn.hidden = YES;
    }
    // Start
    //_lineIV = [[UIImageView alloc] initWithFrame:CGRectMake(preView.frame.origin.x, preView.frame.origin.y, preView.frame.size.width, 5)];
    _lineIV = [[UIImageView alloc] initWithFrame:CGRectMake((self.view.frame.size.width-240)*0.5, 213-kNavbarHeight+yMove, 240, 5)];
    NSString *lineName = [@"QRCodeScanner.bundle" stringByAppendingPathComponent:@"saomiaoline"];

    _lineIV.image = [UIImage imageNamed:lineName];
    [self.view addSubview:_lineIV];
    
    
    //开始扫描
    [_session startRunning];
}
//手电筒🔦的开和关
- (void)lightOnOrOff:(UIButton *)sender {
    sender.selected = !sender.selected;
    isLightOn = 1 - isLightOn;
    if (isLightOn) {
        [self turnOnLed:YES];
    }
    else {
        [self turnOffLed:YES];
    }
}

//打开手电筒
- (void) turnOnLed:(bool)update {
    [captureDevice lockForConfiguration:nil];
    [captureDevice setTorchMode:AVCaptureTorchModeOn];
    [captureDevice unlockForConfiguration];
}
//关闭手电筒
- (void) turnOffLed:(bool)update {
    [captureDevice lockForConfiguration:nil];
    [captureDevice setTorchMode: AVCaptureTorchModeOff];
    [captureDevice unlockForConfiguration];
}
- (void)showTheQRCodeOfMine:(UIButton *)sender {
    NSLog(@"showTheQRCodeOfMine");
}
- (void)animation {
    //NSLog(@"%d %d", upOrdown, num);
    if (upOrdown == NO) {
        num ++;
        _lineIV.frame = CGRectMake(codeFrame.frame.origin.x, codeFrame.frame.origin.y + 2 * num, codeFrame.frame.size.width, 5);
        if (IS_IPHONE5||IS_IPHONE4) {
            if (2 * num >= codeFrame.frame.size.height) {
                upOrdown = YES;
            }
        }
        else {
            if (2 * num >= codeFrame.frame.size.height - 3) {
                upOrdown = YES;
            }
        }
    }
    else {
        num --;
        _lineIV.frame = CGRectMake(codeFrame.frame.origin.x, codeFrame.frame.origin.y + 2 * num, codeFrame.frame.size.width, 5);
        
        if (num <= 0) {
            upOrdown = NO;
        }
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    //判断是否有数据
    if (metadataObjects != nil && [metadataObjects count] > 0) {

        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        //判断回传的数据类型
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]
            || [[metadataObj type] isEqualToString:AVMetadataObjectTypeEAN13Code]
            || [[metadataObj type] isEqualToString:AVMetadataObjectTypeEAN8Code]
            || [[metadataObj type] isEqualToString:AVMetadataObjectTypeCode128Code]
            ) {

            NSLog(@"stringValue = %@",metadataObj.stringValue);
            [self checkQRcode:metadataObj.stringValue];
        }
    }
    [_session stopRunning];
    [self performSelector:@selector(startReading) withObject:nil afterDelay:0.5];
}

-(void)startReading{
    [_session startRunning];
}
-(void)stopReading{
    [_session stopRunning];
}
/**
 * 判断二维码
 */
- (void)checkQRcode:(NSString *)str{
    
    if (str.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"找不到二维码" message:@"导入的图片里并没有找到二维码" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
//    if ([str hasPrefix:@"http"]) {
//        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:str]];
//    }else
    {
        //弹出一个view显示二维码内容
        [SVProgressHUD showInfoWithStatus:str];
    }
    [SVProgressHUD dismissWithDelay:1.0];

}

/**
 * 将二维码图片转化为字符
 */
- (NSString *)stringFromFileImage:(UIImage *)img{
    int exifOrientation;
    switch (img.imageOrientation) {
        case UIImageOrientationUp:
            exifOrientation = 1;
            break;
        case UIImageOrientationDown:
            exifOrientation = 3;
            break;
        case UIImageOrientationLeft:
            exifOrientation = 8;
            break;
        case UIImageOrientationRight:
            exifOrientation = 6;
            break;
        case UIImageOrientationUpMirrored:
            exifOrientation = 2;
            break;
        case UIImageOrientationDownMirrored:
            exifOrientation = 4;
            break;
        case UIImageOrientationLeftMirrored:
            exifOrientation = 5;
            break;
        case UIImageOrientationRightMirrored:
            exifOrientation = 7;
            break;
        default:
            break;
    }
    //CIContext *context = [[CIContext alloc] initWithOptions:nil];
    NSDictionary *detectorOptions = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh }; // TODO: read doc for more tuneups
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:detectorOptions];
    
    NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:img.CGImage]];
    
    CIQRCodeFeature * qrStr  = (CIQRCodeFeature *)features.firstObject;
    //只返回第一个扫描到的二维码
    return qrStr.messageString;
}
-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx{
    if (layer == self.maskLayer) {
        UIGraphicsBeginImageContextWithOptions(self.maskLayer.frame.size, NO, 1.0);
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6].CGColor);
        CGContextFillRect(ctx, self.maskLayer.frame);
        CGRect scanFrame = [self.view convertRect:codeFrame.frame fromView:codeFrame.superview];
        CGContextClearRect(ctx, scanFrame);
    }
}
-(void)dealloc{
    NSLog(@"%@ dealloc",NSStringFromClass(self.class));
    if (preView) {
        [preView removeFromSuperlayer];
    }
    if (self.maskLayer) {
        self.maskLayer.delegate = nil;
    }
    if (self.maskLayer) {
        self.maskLayer.delegate = nil;
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end
