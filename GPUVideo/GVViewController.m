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
@property (strong, nonatomic) IBOutlet UIImageView *GPUImageView;
@property (strong, nonatomic) GPUImageView *filteredVideoView;
@property (strong, nonatomic) GPUImageFilter *filter;
@property (strong, nonatomic) GPUImageMovieWriter *movieWriter;
@property (strong, nonatomic) UISwipeGestureRecognizer *leftSwipe;
@property (strong, nonatomic) UISwipeGestureRecognizer *rightSwipe;
@property (strong, nonatomic) NSArray *filterNameArray;
@property (strong, nonatomic) NSArray *filterArray;
@property (nonatomic, assign) int filterArrayPosition;
@property (nonatomic, assign) int mediaControlButtonState;
@property (nonatomic, strong) NSURL *fileURL;

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
    GPUImageMosaicFilter *mosaicFilter = [[GPUImageMosaicFilter alloc] init];
    GPUImageLowPassFilter *lowPassFilter = [[GPUImageLowPassFilter alloc] init];
    GPUImageGaussianBlurFilter *gaussianBlurFilter = [[GPUImageGaussianBlurFilter alloc] init];
    self.filterArray = [NSArray arrayWithObjects:stretchDistortionFilter, swirlFilter, pinchDistortionFilter, mosaicFilter, lowPassFilter, gaussianBlurFilter, nil];
    
    //hide save and delete buttons while nothing has been recorded
    [self.deleteVideoButton setHidden:YES];
    [self.saveVideoButton setHidden:YES];
    
    //initialize array of filter names
    self.filterNameArray = [NSArray arrayWithObjects:@"Stretch", @"Swirl", @"Pinch", @"Mosaic", @"Drunk", @"Blurry", nil];
    
    self.filterArrayPosition = 0;
    self.mediaControlButtonState = 0;
    
    //setup preview for filtered video
    videoCamera = [[GPUImageVideoCamera alloc]
                   initWithSessionPreset:AVCaptureSessionPreset640x480
                   cameraPosition:AVCaptureDevicePositionBack];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    [videoCamera addTarget:self.filterArray[0]];
    
    self.filteredVideoView = [[GPUImageView alloc] initWithFrame:self.GPUImageView.frame];
    
    //add gesture recognizers to filteredVideoView
    self.leftSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(changeFilter:)];
    self.leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft ;
    [self.filteredVideoView addGestureRecognizer:self.leftSwipe];
    
    self.rightSwipe = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(changeFilter:)];
    self.rightSwipe.direction = UISwipeGestureRecognizerDirectionRight ;
    [self.view addGestureRecognizer:self.rightSwipe];
    
    [self.filterArray[0] addTarget:self.filteredVideoView];
    [self.filteredVideoView setClipsToBounds:YES];
    [self.view addSubview:self.filteredVideoView];
    
    // Assemble the file URL [copied/pasted, can be made cleaner]
    NSString *fileName = @"temp.mp4";
    NSError* error = nil;
    self.fileURL = [[[[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:fileName];
    
    // Remove file from the path of the file URL, if one already exists there
    if([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]){
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:&error];
    }
    
    self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.fileURL size:CGSizeMake(480.0, 640.0)];
    
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
        [self.filterArray[self.filterArrayPosition] addTarget:self.filteredVideoView];
        [self.filterArray[self.filterArrayPosition] prepareForImageCapture];
        [self.filteredVideoView setClipsToBounds:YES];
    }
    
    if(sender.direction == UISwipeGestureRecognizerDirectionLeft) {
        NSLog(@"LEFT GESTURE");
        
        [videoCamera removeAllTargets];
        [self.filterArray[self.filterArrayPosition] removeAllTargets];
        
        self.filterArrayPosition = ++self.filterArrayPosition % 6;
        
        if (self.filterArrayPosition < 0) self.filterArrayPosition += 6;
        
        [videoCamera addTarget:self.filterArray[self.filterArrayPosition]];
        [self.filterArray[self.filterArrayPosition] addTarget:self.filteredVideoView];
        [self.filterArray[self.filterArrayPosition] prepareForImageCapture];
        [self.filteredVideoView setClipsToBounds:YES];
    }
}

- (IBAction)mediaControlButtonPressed:(id)sender {
    self.mediaControlButtonState = ++self.mediaControlButtonState % 2;
    
    if (self.mediaControlButtonState == 0) {
        [self.mediaControlButton setImage:[UIImage imageNamed:@"Media-Controls-Record-icon.png"] forState:UIControlStateNormal];
        
        [self.filterArray[self.filterArrayPosition] removeTarget:self.movieWriter];
        videoCamera.audioEncodingTarget = nil;
        [self.movieWriter finishRecording];
        NSLog(@"Movie completed");
        
        [self.deleteVideoButton setHidden:NO];
        [self.saveVideoButton setHidden:NO];
    } else {
        [self.mediaControlButton setImage:[UIImage imageNamed:@"stop-100.png"] forState:UIControlStateNormal];
        
        NSError* error = nil;
        
        // Remove file from the path of the file URL, if one already exists there
        if([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]){
            [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:&error];
        }
        
        [self.filterArray[self.filterArrayPosition] addTarget:self.movieWriter];

        videoCamera.audioEncodingTarget = self.movieWriter;
        [self.movieWriter startRecording];
        
        //unhide save and delete
        [self.deleteVideoButton setHidden:YES];
        [self.saveVideoButton setHidden:YES];
    }
}

- (IBAction)deleteVideoButtonPressed:(id)sender {
    NSError* error = nil;
    
    // Remove file from the path of the file URL, if one already exists there
    if([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]){
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:&error];
    }
    
    [self.deleteVideoButton setHidden:YES];
    [self.saveVideoButton setHidden:YES];
}

- (IBAction)saveVideoButtonPressed:(id)sender {
    NSString *filePath = [self.fileURL path];
    
    UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    
    [self.deleteVideoButton setHidden:YES];
    [self.saveVideoButton setHidden:YES];
}

- (void)               video: (NSString *) videoPath
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo{
    NSLog(@"the video was saved");
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
