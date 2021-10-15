//
//  AudioProcessor.m
//  MicInput
//
//  Created by Stefan Popp on 21.09.11.
//  Copyright 2011 http://www.stefanpopp.de/2011/capture-iphone-microphone/ . All rights reserved.
//

#import "pcm_udp.h"
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <arpa/inet.h>

#pragma mark Recording callback

Boolean isShowSize;
BOOL isLiveClosed = false;

static OSStatus recordingCallback(void *inRefCon, 
                                  AudioUnitRenderActionFlags *ioActionFlags, 
                                  const AudioTimeStamp *inTimeStamp, 
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames, 
                                  AudioBufferList *ioData) {
	
	// the data gets rendered here
    AudioBuffer buffer;
    
    // a variable where we check the status
    OSStatus status;
    
    /**
     This is the reference to the object who owns the callback.
     */
    audioprocessor *audioProcessor = (__bridge audioprocessor*) inRefCon;
    
    /**
     on this point we define the number of channels, which is mono
     for the iphone. the number of frames is usally 512 or 1024.
     */
    buffer.mDataByteSize = inNumberFrames * 2; // sample size
    buffer.mNumberChannels = 1; // one channel
	  buffer.mData = malloc( inNumberFrames * 2 ); // buffer size
  
  if (!isShowSize) {
    isShowSize = YES;
      NSLog(@"mDataByteSize: %u", (unsigned int)buffer.mDataByteSize);
  }

  
	
    // we put our buffer into a bufferlist array for rendering
	AudioBufferList bufferList;
	bufferList.mNumberBuffers = 1;
	bufferList.mBuffers[0] = buffer;
    
    // render input and check for error
    status = AudioUnitRender([audioProcessor audioUnit], ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
  [audioProcessor hasError:status andFile:__FILE__ andLine:__LINE__];
    
	// process the bufferlist in the audio processor
    [audioProcessor processBuffer:&bufferList];
    // clean up the buffer
	free(bufferList.mBuffers[0].mData);
	
    return noErr;
}


#pragma mark objective-c class

@implementation audioprocessor
@synthesize audioUnit, mAudioBuffer, gain;

-(void)initializeAudio
{    
  OSStatus status;
	
	// We define the audio component
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output; // we want to ouput
	desc.componentSubType = kAudioUnitSubType_RemoteIO; // we want in and ouput
	desc.componentFlags = 0; // must be zero
	desc.componentFlagsMask = 0; // must be zero
	desc.componentManufacturer = kAudioUnitManufacturer_Apple; // select provider
	
	// find the AU component by description
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// create audio unit by component
	status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    
	[self hasError:status andFile:__FILE__ andLine:__LINE__];
	
    // define that we want record io on the input bus
    UInt32 flag = 1;
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioOutputUnitProperty_EnableIO, // use io
								  kAudioUnitScope_Input, // scope to input
								  kInputBus, // select input bus (1)
								  &flag, // set flag
								  sizeof(flag));
	[self hasError:status andFile:__FILE__ andLine:__LINE__];
	
	// define that we want play on io on the output bus
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioOutputUnitProperty_EnableIO, // use io
								  kAudioUnitScope_Output, // scope to output
								  kOutputBus, // select output bus (0)
								  &flag, // set flag
								  sizeof(flag));
	[self hasError:status andFile:__FILE__ andLine:__LINE__];
	
	/* 
     We need to specifie our format on which we want to work.
     We use Linear PCM cause its uncompressed and we work on raw data.
     for more informations check.
   
     We want 16 bits, 2 bytes per packet/frames at 44khz 
     */
	AudioStreamBasicDescription audioFormat;
	audioFormat.mSampleRate			= SAMPLE_RATE;
	audioFormat.mFormatID			= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags		= kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
	audioFormat.mFramesPerPacket	= 1;
	audioFormat.mChannelsPerFrame	= 1; // mono
	audioFormat.mBitsPerChannel		= 16; // 8 * 2 ??
	audioFormat.mBytesPerPacket		= 2;
	audioFormat.mBytesPerFrame		= 2;
    
    
    
	// set the format on the output stream
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_StreamFormat, 
								  kAudioUnitScope_Output, 
								  kInputBus, 
								  &audioFormat, 
								  sizeof(audioFormat));
    
	[self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    // set the format on the input stream
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_StreamFormat, 
								  kAudioUnitScope_Input, 
								  kOutputBus, 
								  &audioFormat, 
								  sizeof(audioFormat));
	[self hasError:status andFile:__FILE__ andLine:__LINE__];
	
	
	
    /**
        We need to define a callback structure which holds
        a pointer to the recordingCallback and a reference to
        the audio processor object
     */
	AURenderCallbackStruct callbackStruct;
    
    // set recording callback
	callbackStruct.inputProc = recordingCallback; // recordingCallback pointer
	callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);

    // set input callback to recording callback on the input bus
	status = AudioUnitSetProperty(audioUnit, 
                                  kAudioOutputUnitProperty_SetInputCallback, 
								  kAudioUnitScope_Global, 
								  kInputBus, 
								  &callbackStruct, 
								  sizeof(callbackStruct));
    
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
	

  // reset flag to 0
	flag = 0;
    
    /*
     we need to tell the audio unit to allocate the render buffer,
     that we can directly write into it.
     */
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_ShouldAllocateBuffer,
								  kAudioUnitScope_Output, 
								  kInputBus,
								  &flag, 
								  sizeof(flag));
	

    /*
     we set the number of channels to mono and allocate our block size to
     1024 bytes.
    */
	mAudioBuffer.mNumberChannels = 1;
	mAudioBuffer.mDataByteSize = BUFF_SIZE ; //512*2
	mAudioBuffer.mData = malloc( BUFF_SIZE );
	
	// Initialize the Audio Unit and cross fingers =)
	status = AudioUnitInitialize(audioUnit);
	[self hasError:status andFile:__FILE__ andLine:__LINE__];
    
  
  NSLog(@"Started");
  isShowSize = NO;
  UDP_index = 0;
}

-(void)setHostIP:(NSString*)hostIP;
{
  strHostIP = [[NSString alloc] initWithString:hostIP];
}

-(void)setPort:(int)port;
{
  hostPort = port;
}

-(void)sendTest;
{
  
  if(UDP_index < UDP_COUNT)
  {
    memcpy(Buff_UDP+(BUFF_SIZE*UDP_index), mAudioBuffer.mData, mAudioBuffer.mDataByteSize);
    
    UDP_index++;
  }
  
  if(UDP_index != UDP_COUNT)
    return;
    
    
  UDP_index = 0;
 
  // Open a socket
  int sd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (sd<=0) {
    NSLog(@"Error: Could not open socket");
    return;
  }
  
  // Set socket options
  int broadcastEnable=0; //1 Enable broadcast
  int ret=setsockopt(sd, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, sizeof(broadcastEnable));
  if (ret) {
    NSLog(@"Error: Could not open set socket to broadcast mode");
    close(sd);
    return;
  }
  
  struct sockaddr_in broadcastAddr; // Make an endpoint
  memset(&broadcastAddr, 0, sizeof broadcastAddr);
  broadcastAddr.sin_family = AF_INET;
  inet_pton(AF_INET, strHostIP.UTF8String, &broadcastAddr.sin_addr); // Set the broadcast IP address
  broadcastAddr.sin_port = htons(hostPort); // Set port
  
  //ret = sendto(sd, mAudioBuffer.mData, mAudioBuffer.mDataByteSize, 0, (struct sockaddr*)&broadcastAddr, sizeof broadcastAddr);
  
  ret = sendto(sd, Buff_UDP, UDP_SIZE, 0, (struct sockaddr*)&broadcastAddr, sizeof broadcastAddr);
  
  
  if (ret<0) {
    NSLog(@"Error: Could not open send broadcast");
    close(sd);
    return;
  }

  // Get responses here using recvfrom if you want...
  close(sd);

}

#pragma mark controll stream

-(void)start;
{
    // start the audio unit. You should hear something, hopefully :)
    OSStatus status = AudioOutputUnitStart(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
}
-(void)stop;
{
    // stop the audio unit
    OSStatus status = AudioOutputUnitStop(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
}

-(void)startLive: (UIViewController*)vc;
{
  NSLog(@"startLive");
  ViewCtrlCamera *vcCamera  = [[ViewCtrlCamera alloc]init];
  [vc presentViewController:vcCamera animated:NO completion:^{}];
  [vcCamera startScan];
}

-(void)setGain:(float)gainValue 
{
    gain = gainValue;
}

-(float)getGain
{
    return gain;
}

#pragma mark processing

-(void)processBuffer: (AudioBufferList*) audioBufferList
{
    AudioBuffer sourceBuffer = audioBufferList->mBuffers[0];
    
    // we check here if the input data byte size has changed
	if (mAudioBuffer.mDataByteSize != sourceBuffer.mDataByteSize) {
        // clear old buffer
		free(mAudioBuffer.mData);
        // assing new byte size and allocate them on mData
		mAudioBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
		mAudioBuffer.mData = malloc(sourceBuffer.mDataByteSize);
	}
    
    /**
     Here we modify the raw data buffer now. 
     In my example this is a simple input volume gain.
     iOS 5 has this on board now, but as example quite good.
     */
    SInt16 *editBuffer = audioBufferList->mBuffers[0].mData;
    
    // loop over every packet
    for (int nb = 0; nb < (audioBufferList->mBuffers[0].mDataByteSize / 2); nb++) {

        // we check if the gain has been modified to save resoures
        if (gain != 0) {
            // we need more accuracy in our calculation so we calculate with doubles
            double gainSample = ((double)editBuffer[nb]) / 32767.0;  // Tony : 2^15 = 32768

            /*
            at this point we multiply with our gain factor
            we dont make a addition to prevent generation of sound where no sound is.
             
             no noise
             0*10=0
             
             noise if zero
             0+10=10 
            */
            gainSample *= gain;
            
            /**
             our signal range cant be higher or lesser -1.0/1.0
             we prevent that the signal got outside our range
             */
            gainSample = (gainSample < -1.0) ? -1.0 : (gainSample > 1.0) ? 1.0 : gainSample;
            
            /*
             This thing here is a little helper to shape our incoming wave.
             The sound gets pretty warm and better and the noise is reduced a lot.
             Feel free to outcomment this line and here again.
             
             You can see here what happens here http://silentmatt.com/javascript-function-plotter/
             Copy this to the command line and hit enter:
             */
             
            gainSample = (1.5 * gainSample) - 0.5 * gainSample * gainSample * gainSample;
            
            // multiply the new signal back to short 
            gainSample = gainSample * 32767.0;
            
            // write calculate sample back to the buffer
            editBuffer[nb] = (SInt16)gainSample;
        }
    }
    
	// copy incoming audio data to the audio buffer
	memcpy(mAudioBuffer.mData, audioBufferList->mBuffers[0].mData, audioBufferList->mBuffers[0].mDataByteSize);

  [self sendTest];
}

#pragma mark Error handling

-(void)hasError:(int)statusCode andFile:(char*)file andLine:(int)line
{
	if (statusCode) {
		printf("Error Code responded %d in file %s on line %d\n", statusCode, file, line);
        exit(-1);
	}
}


@end

//==============================================================


@interface ViewCtrlCamera () <AVCaptureMetadataOutputObjectsDelegate> {
  AVCaptureVideoPreviewLayer *_previewLayer;
}
@end

@implementation ViewCtrlCamera

//- (void)viewDidLoad
- (void)initView
{
  NSLog(@"ViewCtrlCamera - viewDidLoad");
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  app = (AppDelegate*) [[UIApplication sharedApplication] delegate];
  
  // Create a new AVCaptureSession
  session = [[AVCaptureSession alloc] init];
//  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionFront];

  NSError *error = nil;
  
  // Want the normal device
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  
  if(!error) {
    // Add the input to the session
    [session addInput:input];
  } else {
    NSLog(@"error: %@", error);
    return;
  }
  
  AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
  [session addOutput:output];
  NSLog(@"%@", [output availableMetadataObjectTypes]);
  
  
  // This VC is the delegate. Please call us on the main queue
  [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
  
  
  // Display on screen
  _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
  _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  
  [self handleRotate];
  
  [self.view.layer addSublayer:_previewLayer];
  
  if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
    [self prefersStatusBarHidden];
    [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
  }
  
  UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(myClose)];
//                                                  (swapFrontAndBackCameras)];
  
  
  [tapGestureRecognizer setNumberOfTouchesRequired:1];
  [tapGestureRecognizer setNumberOfTapsRequired:2];
  [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for ( AVCaptureDevice *device in devices )
    if ( device.position == position )
      return device;
  return nil;
}

- (void)swapFrontAndBackCameras
{
  NSArray *inputs = session.inputs;
  for ( AVCaptureDeviceInput *input in inputs )
  {
    AVCaptureDevice *device = input.device;
    if ( [device hasMediaType:AVMediaTypeVideo] )
    {
      AVCaptureDevicePosition position = device.position;
      AVCaptureDevice *newCamera = nil;
      AVCaptureDeviceInput *newInput = nil;
      
      if (position == AVCaptureDevicePositionFront)
        newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
      else
        newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
      newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
      
      // beginConfiguration ensures that pending changes are not applied immediately
      [session beginConfiguration];
      
      [session removeInput:input];
      [session addInput:newInput];
      
      // Changes take effect once the outermost commitConfiguration is invoked.
      [session commitConfiguration];
      break;
    }
  }
}

-(BOOL)prefersStatusBarHidden
{
  return YES;
}

-(BOOL)shouldAutorotate
{
  [self handleRotate];
  return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  //支援的方向
  //UIInterfaceOrientationMaskPortrait表示直向
  //UIInterfaceOrientationMaskPortraitUpsideDown表示上下顛倒直向
  //UIInterfaceOrientationMaskLandscapeLeft表示逆時針橫向
  //UIInterfaceOrientationMaskLandscapeRight表示逆時針橫向
  return  UIInterfaceOrientationMaskAllButUpsideDown;
}

-(void)handleRotate
{
  
  _previewLayer.bounds = self.view.bounds;
  _previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
  
  
  UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
  
  switch (orientation) {
    case UIInterfaceOrientationPortrait:
      [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
      break;
      
    case UIInterfaceOrientationLandscapeLeft:
      [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
      break;
      
    case UIInterfaceOrientationLandscapeRight:
      [_previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
      
    default:
      break;
  }
  //_previewLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
  
}

- (void)startScan
{
  UIApplication *myApp = [UIApplication sharedApplication];
  UIWindow *win = myApp.windows.firstObject;
  [win.rootViewController presentViewController:self animated:YES completion:nil];
  [session startRunning];
  [UIApplication sharedApplication].idleTimerDisabled = YES;

  if (liveAudio == nil)
    liveAudio = [[LiveAudio alloc] init];
  
//  [liveAudio setGain: [liveAudio getGain]+2.0f];
  [liveAudio start];
}

- (void)myClose // Tap 二次結束
{
  [session stopRunning];
  [liveAudio stop];
  [self dismissViewControllerAnimated:YES completion:nil];
  isLiveClosed = true;
}

//==============================================================
void fakeLoader()
{
  NSLog(@"AudioProcessor - fakeLoader");
}

void showLive()
{
  isLiveClosed = false;
  ViewCtrlCamera *vc = [ViewCtrlCamera alloc];
  [vc initView];
  [vc startScan];
}


BOOL isLiveClose()
{
  return isLiveClosed;
}

@end
