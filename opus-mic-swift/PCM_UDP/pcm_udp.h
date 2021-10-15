//
//  AudioProcessor.h
//  MicInput
//
//  Created by Stefan Popp on 21.09.11.
//  Copyright 2011 http://http://www.stefanpopp.de/2011/capture-iphone-microphone//2011/capture-iphone-microphone/ . All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "LiveAudio.h"

// return max value for given values
#define max(a, b) (((a) > (b)) ? (a) : (b))
// return min value for given values
#define min(a, b) (((a) < (b)) ? (a) : (b))

#define kOutputBus 0
#define kInputBus 1

// our default sample rate
#define SAMPLE_RATE 44100.00/2
#define BUFF_SIZE 1024
#define UDP_COUNT 5
#define UDP_SIZE BUFF_SIZE*UDP_COUNT

@interface audioprocessor : NSObject
{
  AudioComponentInstance audioUnit;
	AudioBuffer mAudioBuffer;
  float gain;
  unsigned int UDP_index;
  
  Byte Buff_UDP[UDP_SIZE];
  NSString* strHostIP;
  int hostPort;
}

@property (readonly) AudioBuffer mAudioBuffer;
@property (readonly) AudioComponentInstance audioUnit;
@property (nonatomic) float gain;


-(void)initializeAudio;
-(void)processBuffer: (AudioBufferList*) audioBufferList;
-(void)sendTest;
-(void)setHostIP:(NSString*)hostIP;
-(void)setPort:(int)port;


// control object
-(void)start;
-(void)stop;
-(void)startLive: (UIViewController*)vc;

// gain
-(void)setGain:(float)gainValue;
-(float)getGain;

// error managment
-(void)hasError:(int)statusCode andFile:(char*)file andLine:(int)line;

@end

@class AppDelegate;
//==============================================================
@interface ViewCtrlCamera : UIViewController
{
  AppDelegate *app;
  AVCaptureSession *session;
  LiveAudio *liveAudio;
}
- (void)initView;
- (void)startScan;
@end
//==============================================================

// 供外部呼叫的函式
void fakeLoader();
void showLive();
BOOL isLiveClose();