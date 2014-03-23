//
//  GVViewController.m
//  GPUVideo
//
//  Created by Sean Wertheim on 3/7/14.
//  Copyright (c) 2014 Sean Wertheim. All rights reserved.
//

#import "GVViewController.h"
#import "GPUImage.h"

@interface GVViewController ()
@property (strong, nonatomic) IBOutlet UIButton *deleteVideoButton;
@property (strong, nonatomic) IBOutlet UIButton *mediaControlButton;
@property (strong, nonatomic) IBOutlet UIButton *saveVideoButton;
@property (strong, nonatomic) IBOutlet GPUImageView *GPUImageView;
@property (strong, nonatomic) GPUImageFilter *filter;
@property (strong, nonatomic) GPUImageMovieWriter *movieWriter;
@property (strong, nonatomic) UISwipeGestureRecognizer *leftSwipe;
@property (strong, nonatomic) UISwipeGestureRecognizer *rightSwipe;
@property (strong, nonatomic) NSArray *filterNameArray;
@property (strong, nonatomic) NSArray *filterArray;
@property (nonatomic, assign) int filterArrayPosition;
@property (nonatomic, assign) int mediaControlButtonState;
@property (nonatomic, strong) NSURL *fileURL;
@property (strong, nonatomic) IBOutlet UILabel *filterNameLabel;
@property (strong, nonatomic) AVURLAsset *avAsset;
@property (strong, nonatomic) AVPlayer *avPlayer;
@property (strong, nonatomic) AVPlayerLayer *avPlayerLayer;
@property (strong, nonatomic) AVPlayerItem *avPlayerItem;
@property (assign, nonatomic) CGSize writerSize;

@end

@implementation GVViewController{
    GPUImageVideoCamera *videoCamera;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //initialize array of filters
    GPUImageStretchDistortionFilter *stretchDistortionFilter = [[GPUImageStretchDistortionFilter alloc] init];
    GPUImageSwirlFilter *swirlFilter = [[GPUImageSwirlFilter alloc] init];
    GPUImagePinchDistortionFilter *pinchDistortionFilter = [[GPUImagePinchDistortionFilter alloc] init];
    GPUImageSketchFilter *sketchFilter = [[GPUImageSketchFilter alloc] init];
    GPUImageLowPassFilter *lowPassFilter = [[GPUImageLowPassFilter alloc] init];
    GPUImageEmbossFilter *embossFilter = [[GPUImageEmbossFilter alloc] init];
    self.filterArray = [NSArray arrayWithObjects:stretchDistortionFilter, swirlFilter, pinchDistortionFilter, sketchFilter, lowPassFilter, embossFilter, nil];
    
    //hide save and delete buttons while nothing has been recorded
    [self.deleteVideoButton setHidden:YES];
    [self.saveVideoButton setHidden:YES];
    
    //filter name label to fade in
    self.filterNameLabel.alpha = 0;
    
    //initialize array of filter names
    self.filterNameArray = [NSArray arrayWithObjects:@"Stretch", @"Swirl", @"Pinch", @"Sketch", @"Drunk", @"Emboss", nil];
    
    self.filterArrayPosition = 0;
    self.mediaControlButtonState = 0;
    
    //get device specs
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice;
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionBack) {//get the back facing camera
            captureDevice = device;
        }
    }
    
    //detect which session preset and writer size we can use
    NSString *sessionPreset;
    if ([captureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset1920x1080]) {
        sessionPreset = AVCaptureSessionPreset1920x1080;
        self.writerSize = CGSizeMake(1080, 1920);
        NSLog(@"Set preview port to 1920x1080");
    } else if ([captureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset640x480]) {
        NSLog(@"Set preview port to 640X480");
        sessionPreset = AVCaptureSessionPreset640x480;
        self.writerSize = CGSizeMake(480, 640);
    }
    
    //setup preview for filtered video
    videoCamera = [[GPUImageVideoCamera alloc]
                   initWithSessionPreset:sessionPreset
                   cameraPosition:AVCaptureDevicePositionBack];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    [videoCamera addTarget:self.filterArray[0]];
    
    //add gesture recognizers to filteredVideoView
    self.leftSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(changeFilter:)];
    self.leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft ;
    [self.GPUImageView addGestureRecognizer:self.leftSwipe];
    self.rightSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(changeFilter:)];
    self.rightSwipe.direction = UISwipeGestureRecognizerDirectionRight ;
    [self.view addGestureRecognizer:self.rightSwipe];
    
    // Assemble the file URL [copied/pasted, can be made cleaner]
    NSString *fileName = @"temp.mp4";
    NSError* error = nil;
    self.fileURL = [[[[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:fileName];
    
    // Remove file from the path of the file URL, if one already exists there
    if([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]){
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:&error];
    }
    
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.fileURL size:self.writerSize];
    
    [self.filterArray[self.filterArrayPosition] addTarget:self.GPUImageView];
    [self.filterArray[self.filterArrayPosition] addTarget:self.movieWriter];
    [self.GPUImageView setClipsToBounds:YES];
    [self.view insertSubview:self.GPUImageView belowSubview:self.filterNameLabel];
    
    
    [videoCamera startCameraCapture];
}

-(void)changeFilter:(UISwipeGestureRecognizer *)sender {
    if(sender.direction == UISwipeGestureRecognizerDirectionRight) {
        NSLog(@"RIGHT GESTURE");
        
        [videoCamera removeAllTargets];
        [self.filterArray[self.filterArrayPosition] removeAllTargets];
        
        self.filterArrayPosition = --self.filterArrayPosition % 6;
        
        if (self.filterArrayPosition < 0) self.filterArrayPosition += 6;
        
        [videoCamera addTarget:self.filterArray[self.filterArrayPosition]];
        [self.filterArray[self.filterArrayPosition] addTarget:self.GPUImageView];
        [self.filterArray[self.filterArrayPosition] addTarget:self.movieWriter]; //
        [self.filterArray[self.filterArrayPosition] prepareForImageCapture];
        [self.GPUImageView setClipsToBounds:YES];
        
        self.filterNameLabel.text = self.filterNameArray[self.filterArrayPosition];
        
        [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseIn
                         animations:^{ self.filterNameLabel.alpha = 1;}
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseIn
                                              animations:^{ self.filterNameLabel.alpha = 0;}
                                              completion:nil];
                         }];
    }
    
    if(sender.direction == UISwipeGestureRecognizerDirectionLeft) {
        NSLog(@"LEFT GESTURE");
        
        [videoCamera removeAllTargets];
        [self.filterArray[self.filterArrayPosition] removeAllTargets];
        
        self.filterArrayPosition = ++self.filterArrayPosition % 6;
        
        if (self.filterArrayPosition < 0) self.filterArrayPosition += 6;
        
        [videoCamera addTarget:self.filterArray[self.filterArrayPosition]];
        [self.filterArray[self.filterArrayPosition] addTarget:self.GPUImageView];
        [self.filterArray[self.filterArrayPosition] addTarget:self.movieWriter]; //
        [self.filterArray[self.filterArrayPosition] prepareForImageCapture];
        [self.GPUImageView setClipsToBounds:YES];
        
        self.filterNameLabel.text = self.filterNameArray[self.filterArrayPosition];
        
        [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseIn
                         animations:^{ self.filterNameLabel.alpha = 1;}
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseIn
                                              animations:^{ self.filterNameLabel.alpha = 0;}
                                              completion:nil];
                         }];
    }
}

- (IBAction)mediaControlButtonPressed:(id)sender {
    self.mediaControlButtonState = ++self.mediaControlButtonState % 2;
    
    if (self.mediaControlButtonState == 0) {
        ////// You are previewing here
        [self.mediaControlButton setImage:[UIImage imageNamed:@"video_rec_64.png"] forState:UIControlStateNormal];
        [self.mediaControlButton setHidden:YES];
        [self.filterNameLabel setHidden:YES];
        
        [self.filterArray[self.filterArrayPosition] removeTarget:self.movieWriter];
        videoCamera.audioEncodingTarget = nil;
        [self.movieWriter finishRecording];
        NSLog(@"Movie completed");
        
        //create AVPlayer to playback looping preview of video
        self.avAsset = [[AVURLAsset alloc] initWithURL:self.fileURL options:nil];
        if ([self.avAsset isPlayable]) {
            self.avPlayerItem =[[AVPlayerItem alloc]initWithAsset:self.avAsset];
        }
        self.avPlayer = [[AVPlayer alloc]initWithPlayerItem:self.avPlayerItem];
        
        
        self.avPlayerLayer =[AVPlayerLayer playerLayerWithPlayer:self.avPlayer];
        [self.avPlayerLayer setFrame:self.GPUImageView.frame];
        
        
        [self.GPUImageView.layer insertSublayer:self.avPlayerLayer below:self.mediaControlButton.layer];
        
        self.avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:[self.avPlayer currentItem]];
        
        //add activity indicator to show preview is loading then remove after 2 seconds
        UIActivityIndicatorView *activityView=[[UIActivityIndicatorView alloc]     initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        activityView.center=self.view.center;
        [activityView startAnimating];
        [self.view addSubview:activityView];
        [activityView performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:2.0];
        
        //allow preview to buffer for two seconds before playing
        [self.avPlayer performSelector:@selector(play) withObject:nil afterDelay:2];
        
        [self.deleteVideoButton setHidden:NO];
        [self.saveVideoButton setHidden:NO];
    } else {
        ///// You are recording here
        [self.mediaControlButton setImage:[UIImage imageNamed:@"video_stop_64.png"] forState:UIControlStateNormal];
        [self.filterNameLabel setHidden:NO];
        
        
        // Remove file from the path of the file URL, if one already exists there
        if([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]){
            [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
        }
        
        self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.fileURL size:self.writerSize];
        [self.filterArray[self.filterArrayPosition] addTarget:self.movieWriter];
        
        videoCamera.audioEncodingTarget = self.movieWriter;
        [self.movieWriter startRecording];
        
        //unhide save and delete
        [self.deleteVideoButton setHidden:YES];
        [self.saveVideoButton setHidden:YES];
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

- (IBAction)deleteVideoButtonPressed:(id)sender {
    NSError* error = nil;
    
    // Remove file from the path of the file URL, if one already exists there
    if([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]){
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:&error];
    }
    
    //hide avplayer layer
    [self.avPlayerLayer removeFromSuperlayer];
    [self.avPlayer pause];
    self.avPlayer = nil;
    self.avAsset = nil;
    self.avPlayerItem = nil;
    
    [self.deleteVideoButton setHidden:YES];
    [self.saveVideoButton setHidden:YES];
    [self.mediaControlButton setHidden:NO];
    [self.filterNameLabel setHidden:NO];
}

- (IBAction)saveVideoButtonPressed:(id)sender {
    NSString *filePath = [self.fileURL path];
    
    UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    
    //hide avplayer layer
    [self.avPlayerLayer removeFromSuperlayer];
    [self.avPlayer pause];
    self.avPlayer = nil;
    self.avAsset = nil;
    self.avPlayerItem = nil;
    
    [self.deleteVideoButton setHidden:YES];
    [self.saveVideoButton setHidden:YES];
    [self.mediaControlButton setHidden:NO];
    [self.filterNameLabel setHidden:NO];
}

- (void)               video: (NSString *) videoPath
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo{
    NSLog(@"the video was saved");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"] && [object class] == [AVPlayer class]) {
        if (self.avPlayer.status == AVPlayerStatusReadyToPlay) {
            [self.avPlayer play];
        } else {
            NSLog(@"AVPlayer is not ready to play.");
        }
    }
    
    if (false && [keyPath isEqualToString:@"status"] && [object class] == [AVPlayerItem class]) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item.status == AVPlayerItemStatusReadyToPlay) {
            self.avPlayer = [[AVPlayer alloc]initWithPlayerItem:self.avPlayerItem];
        } else {
            NSLog(@"avplayeritem not ready");
        }
    }
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    NSLog(@"Memory warning received.");
}

@end
