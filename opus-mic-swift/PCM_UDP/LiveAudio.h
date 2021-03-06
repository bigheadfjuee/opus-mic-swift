//
//  AudioProcessor.h
//  MicInput
//
//  Created by Stefan Popp on 21.09.11.
//  Copyright 2011 http://http://www.stefanpopp.de/2011/capture-iphone-microphone//2011/capture-iphone-microphone/ . All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

// return max value for given values
#define max(a, b) (((a) > (b)) ? (a) : (b))
// return min value for given values
#define min(a, b) (((a) < (b)) ? (a) : (b))

#define kOutputBus 0
#define kInputBus 1

// our default sample rate
#define LIVE_SAMPLE_RATE 44100.00

@interface LiveAudio : NSObject
{
    // Audio unit
    AudioComponentInstance audioUnit;
    
    // Audio buffers
	AudioBuffer mAudioBuffer;
    
    // gain
    float gain;
}

@property (readonly) AudioBuffer mAudioBuffer;
@property (readonly) AudioComponentInstance audioUnit;
@property (nonatomic) float gain;

-(LiveAudio*)init;

-(void)initializeAudio;
-(void)processBuffer: (AudioBufferList*) audioBufferList;
-(void)sendBuffer: (AudioBufferList*) audioBufferList;

// control object
-(void)start;
-(void)stop;

// gain
-(void)setGain:(float)gainValue;
-(float)getGain;

// error managment
-(void)hasError:(int)statusCode andFile:(char*)file andLine:(int)line;

@end
