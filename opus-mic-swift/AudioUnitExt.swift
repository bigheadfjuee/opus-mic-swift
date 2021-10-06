//
//  AudioUnitExt.swift
//  opus-mic-swift
//
//  Created by Tony on 2021/10/5.
//

import Foundation
import AVFoundation
import OpusKit
import os

public class Audio {
    public static let SAMPLE_RATE_16_KHZ: opus_int32 = 16_000
    public static let SAMPLE_RATE_8_KHZ: opus_int32 = 8_000
    public static let SAMPLE_RATE_DEFAULT = SAMPLE_RATE_16_KHZ
    public static let MONO:Int32 = 1
    public static let CHANNEL_COUNT_DEFAULT:Int32 = MONO
    public static let BIT_DEPTH_DEFAULT:Int32 = 16
    public static let FRAME_DURATION_DEFAULT = 20 // milliseconds
    // FRAME_SIZE = FRAME (duration in millisecond) * SAMPLE_RATE
    public static let FRAME_SIZE_DEFAULT:Int32 = (SAMPLE_RATE_DEFAULT / 1000) *  Int32(FRAME_DURATION_DEFAULT)
}

public class PCM: Audio {
    public static let SPLIT_CHUNK_SIZE_DEFAULT:Int = Int(FRAME_SIZE_DEFAULT * (BIT_DEPTH_DEFAULT / 8))
}

public class WAV: Audio {
    public static let HEADER_SIZE:Int32 = 44  // always 44 bytes
    public static let WAV_HEADER_FORMAT_PCM:Int16 = 1
    public static let WAV_HEADER_SUB_CHUNK_SIZE:Int32 = 16 // always 16
}

public class Opus: Audio {
    public static let ENCODED_OUTPUT_MEMORY_SIZE_LIMIT:Int32 = 255 // Size of the allocated memory for the output payload
    public static let OPUS_ENCODER_BUFFER_SIZE:Int32 = 1275 // ref: https://stackoverflow.com/a/55707654/4802664
}

public class PCMRecordingSetting {

    private static let SAMPLE_RATE_16_KHZ = 16_000
    private static let BIT_DEPTH_16 = 16
    private static let CHANNEL_MONO = 1
 
    public var sampleRate:Int = SAMPLE_RATE_16_KHZ {
        willSet {
            updateBitRate()
            updateLinearPCMRecordingSettings()
        }
    }

    public var channelCount:Int = CHANNEL_MONO {
        willSet {
            updateBitRate()
            updateLinearPCMRecordingSettings()
        }
    }

    public var bitDepth:Int = BIT_DEPTH_16 {
        willSet {
            updateBitRate()
            updateLinearPCMRecordingSettings()
        }
    }

    public private(set) var bitRate = SAMPLE_RATE_16_KHZ * BIT_DEPTH_16 * CHANNEL_MONO
    private func updateBitRate(){
        bitRate = sampleRate * bitDepth * channelCount
    }

    public static let LINEAR_PCM_DEFAULT = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: SAMPLE_RATE_16_KHZ,
        AVNumberOfChannelsKey: CHANNEL_MONO,
        AVLinearPCMBitDepthKey: BIT_DEPTH_16,
        AVLinearPCMIsFloatKey: false
        ] as [String : Any]
    
    public var recordingSettings = LINEAR_PCM_DEFAULT
    
    private func updateLinearPCMRecordingSettings(){
                
        recordingSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: false
            ] as [String : Any]
    }

    public init(sampleRate: Int, channelCount: Int, bitDepth: Int){
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        updateBitRate()
        updateLinearPCMRecordingSettings()
    }

    public static let `default` = PCMRecordingSetting(sampleRate: SAMPLE_RATE_16_KHZ, channelCount: CHANNEL_MONO, bitDepth: BIT_DEPTH_16)
}
