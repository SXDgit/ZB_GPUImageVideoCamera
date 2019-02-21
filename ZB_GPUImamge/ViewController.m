//
//  ViewController.m
//  ZB_GPUImamge
//
//  Created by Sangxiedong on 2019/2/19.
//  Copyright © 2019 ZB. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"
#import "GPUImageBeautifyFilter.h"

@interface ViewController () {
    BOOL _containFilter;
    BOOL _containBeautify;
}

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageView *filterView;
@property (nonatomic, strong) UIButton *button;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, strong) GPUImageBeautifyFilter *beautifyFilter;
@property (nonatomic, strong) GPUImageSketchFilter *sketchFilter;
@property (nonatomic, strong) GPUImageSepiaFilter *sepiaFilter;
@property (nonatomic, strong) GPUImageMonochromeFilter *monochromeFilter;
@property (nonatomic, strong) NSURL *moviewURL;
@property (nonatomic, strong) NSString *pathToMovie;

@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *switchButton;

@property (nonatomic, strong) GPUImageFilterGroup *filterGroup;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configFilter];
    [self createVideoCamera];
    [self addButton];
}

- (void)configFilter {
    self.beautifyFilter = [[GPUImageBeautifyFilter alloc]init];
    self.sketchFilter = [[GPUImageSketchFilter alloc]init];
    self.sepiaFilter = [[GPUImageSepiaFilter alloc]init];
    self.monochromeFilter = [[GPUImageMonochromeFilter alloc]init];
    
    self.filterGroup = [[GPUImageFilterGroup alloc]init];
    
    _containFilter = NO;
    _containBeautify = NO;
}

- (void)createVideoCamera {
    self.videoCamera = [[GPUImageVideoCamera alloc]initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    self.videoCamera.horizontallyMirrorRearFacingCamera = NO;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    self.videoCamera.runBenchmark = YES;
    
    [self.videoCamera addAudioInputsAndOutputs];
    
    [self addGPUImageFilter:self.sepiaFilter];
    [self addGPUImageFilter:self.monochromeFilter];
    
    self.filterView = [[GPUImageView alloc]initWithFrame:self.view.frame];
    self.filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    self.view = self.filterView;
    
    [self.videoCamera addTarget:self.filterView];
    
    [self.videoCamera startCameraCapture];
    [self configMovie];
}

- (void)configMovie {
    self.pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/ZBMovied%u.mp4", arc4random() % 1000]];
    self.moviewURL = [NSURL fileURLWithPath:_pathToMovie];
    self.movieWriter = [[GPUImageMovieWriter alloc]initWithMovieURL:_moviewURL size:CGSizeMake(480.0, 640.0)];
    _movieWriter.encodingLiveVideo = YES;
    _videoCamera.audioEncodingTarget = _movieWriter;
}

- (void)addGPUImageFilter:(GPUImageFilter *)filter {
    [self.filterGroup addFilter:filter];
    
    GPUImageOutput<GPUImageInput> *newTerminalFilter = filter;
    NSInteger count = self.filterGroup.filterCount;
    if (count == 1) {
        self.filterGroup.initialFilters = @[newTerminalFilter];
        self.filterGroup.terminalFilter = newTerminalFilter;
    }else {
        GPUImageOutput<GPUImageInput> *terminalFilter = self.filterGroup.terminalFilter;
        NSArray *initialFilters = self.filterGroup.initialFilters;
        [terminalFilter addTarget:newTerminalFilter];
        self.filterGroup.initialFilters = @[initialFilters[0]];
        self.filterGroup.terminalFilter = newTerminalFilter;
    }
}

- (void)starWrite {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.movieWriter startRecording];
    });
}

- (void)stopWrite {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.beautifyFilter removeTarget:self.movieWriter];
        self.videoCamera.audioEncodingTarget = nil;
        [self.movieWriter finishRecording];
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.pathToMovie)) {
            UISaveVideoAtPathToSavedPhotosAlbum(self.pathToMovie , self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    });
}

// 防止拍摄完再次点击拍摄会crash的问题
- (void)videoCameraReset {
    [_videoCamera removeTarget:_movieWriter];
    [[NSFileManager defaultManager] removeItemAtURL:_moviewURL error:nil];
    [self initMovieWriter];
    [_videoCamera addTarget:_movieWriter];
}

- (void)initMovieWriter {
    _movieWriter = [[GPUImageMovieWriter alloc]initWithMovieURL:_moviewURL size:CGSizeMake(480.0, 640.0)];
    _movieWriter.encodingLiveVideo = YES;
}

// 视频保存回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self videoCameraReset];
    if (error == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)addButton {
    CGFloat gap = ([UIScreen mainScreen].bounds.size.width - 100 * 3) / 4;
    self.button = [self createButtonWithNormalTitle:@"开启美颜" AndSelectedTitle:@"关闭美颜"];
    [self.button addTarget:self action:@selector(beautify) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.button];
    self.button.frame = CGRectMake(gap, [UIScreen mainScreen].bounds.size.height - 50, 100, 50);
    
    self.filterButton = [self createButtonWithNormalTitle:@"开启滤镜" AndSelectedTitle:@"关闭滤镜"];
    [self.filterButton addTarget:self action:@selector(filterSwitch) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.filterButton];
    self.filterButton.frame = CGRectMake(CGRectGetMaxX(self.button.frame) + gap, [UIScreen mainScreen].bounds.size.height - 50, 100, 50);
    
    self.captureButton = [self createButtonWithNormalTitle:@"开始录制" AndSelectedTitle:@"结束录制"];
    [self.captureButton addTarget:self action:@selector(captureButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.captureButton];
    self.captureButton.frame = CGRectMake(CGRectGetMaxX(self.filterButton.frame) + gap, [UIScreen mainScreen].bounds.size.height - 50, 100, 50);
    
    self.switchButton = [self createButtonWithNormalTitle:@"切换摄像" AndSelectedTitle:@"切换摄像"];
    [self.switchButton addTarget:self action:@selector(switchButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.switchButton];
    self.switchButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 64, 100, 50);
}

#pragma mark - Action
- (void)switchButtonAction {
    // 切换摄像头前后旋转
    [self.videoCamera rotateCamera];
    self.switchButton.selected = !self.switchButton.selected;
}

- (void)captureButtonAction {
    if (self.captureButton.selected) {
        [self stopWrite];
    }else {
        [self starWrite];
    }
    self.captureButton.selected = !self.captureButton.selected;
}

- (void)beautify {
    if (self.button.selected) {
        [self.videoCamera removeAllTargets];
        if (self.filterButton.selected) {
            if (_containBeautify) {
                _containBeautify = NO;
                [self.filterGroup removeTarget:self.beautifyFilter];
            }
            [self.videoCamera addTarget:self.filterGroup];
            [self.filterGroup addTarget:self.filterView];
            [self.filterGroup addTarget:self.movieWriter];
        }else {
            [self.videoCamera addTarget:self.filterView];
            [self.videoCamera addTarget:self.movieWriter];
        }
        
    }else {
        [self.videoCamera removeAllTargets];
        if (_containFilter) {
            _containFilter = NO;
            [self.beautifyFilter removeTarget:self.filterGroup];
        }
        if (self.filterButton.selected) {
            [self.videoCamera addTarget:self.filterGroup];
            [self.filterGroup addTarget:self.beautifyFilter];
            [self.beautifyFilter addTarget:self.filterView];
            [self.beautifyFilter addTarget:self.movieWriter];
            _containBeautify = YES;
        }else {
            [self.videoCamera addTarget:self.beautifyFilter];
            [self.beautifyFilter addTarget:self.filterView];
            [self.beautifyFilter addTarget:self.movieWriter];
        }
    }
    self.button.selected = !self.button.selected;
}

- (void)filterSwitch {
    if (self.filterButton.selected) {
        [self.videoCamera removeAllTargets];
        
        if (self.button.selected) {
            if (_containFilter) {
                _containFilter = NO;
                [self.beautifyFilter removeTarget:self.filterGroup];
            }
            
            [self.videoCamera addTarget:self.beautifyFilter];
            [self.filterGroup addTarget:self.filterView];
            [self.filterGroup addTarget:self.movieWriter];
        }else {
            [self.videoCamera addTarget:self.filterView];
            [self.videoCamera addTarget:self.movieWriter];
        }
        
    }else {
        [self.videoCamera removeAllTargets];
        if (_containBeautify) {
            _containBeautify = NO;
            [self.filterGroup removeTarget:self.beautifyFilter];
        }
        
        if (self.button.selected) {
            [self.videoCamera addTarget:self.beautifyFilter];
            [self.beautifyFilter addTarget:self.filterGroup];
            [self.filterGroup addTarget:self.filterView];
            [self.filterGroup addTarget:self.movieWriter];
            
            _containFilter = YES;
        }else {
            [self.videoCamera addTarget:self.filterGroup];
            [self.filterGroup addTarget:self.filterView];
            [self.filterGroup addTarget:self.movieWriter];
        }
    }
    self.filterButton.selected = !self.filterButton.selected;
}

- (UIButton *)createButtonWithNormalTitle:(NSString *)normalTitle AndSelectedTitle:(NSString *)selectedTitle {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor whiteColor];
    [button setTitle:normalTitle forState:UIControlStateNormal];
    [button setTitle:selectedTitle forState:UIControlStateSelected];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    return button;
}

@end
