//
//  AVAudioRec.swift
//  opus-mic-swift
//
//  Created by Tony Lee on 2021/9/16.
//
// ref
// https://mdcode2021.medium.com/audio-recording-in-swiftui-mvvm-with-avfoundation-an-ios-app-6e6c8ddb00cc

import Foundation
import SwiftUI
import Combine
import AVFoundation


extension Date
{
  func toString( dateFormat format  : String ) -> String
  {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter.string(from: self)
  }
  
}


class AudioRecorder: ObservableObject {
  let objectWillChange = PassthroughSubject<AudioRecorder, Never>()
  var audioRecorder: AVAudioRecorder!
  var audioPlayer : AVAudioPlayer!
  
  var recording: Bool = false
  var playing: Bool = false
  
  init() {
    let audioSession = AVAudioSession.sharedInstance()
    if audioSession.recordPermission != .granted {
      audioSession.requestRecordPermission { (isGranted) in
        if !isGranted {
          fatalError("You must allow audio recording for this demo to work")
        }
      }
    }
  }
  
  func startRecording() {
    let recordingSession = AVAudioSession.sharedInstance()
    do {
      try recordingSession.setCategory(.playAndRecord, mode: .default)
      try recordingSession.setActive(true)
    } catch {
      print("Failed to set up recording session")
    }
    
    let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let audioFilename = documentPath.appendingPathComponent("rec")
    
    let settings = [
      AVFormatIDKey: Int(kAudioFormatOpus),
      AVSampleRateKey: 48000,
      AVNumberOfChannelsKey: 2,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    
    do {
      audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
      audioRecorder.record()
      recording = true
    } catch {
      print("Could not start recording")
    }
  }// startRecording

  func stopRecording() {
      audioRecorder.stop()
      recording = false
  }
  
  
  func startPlaying() {
    
      let playSession = AVAudioSession.sharedInstance()
          
      do {
          try playSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
      } catch {
          print("Playing failed in Device")
      }
          
      do {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("rec")
        
          audioPlayer = try AVAudioPlayer(contentsOf : audioFilename)
          audioPlayer.prepareToPlay()
          audioPlayer.play()
          
              
      } catch {
          print("Playing Failed")
      }
              
  }

  func stopPlaying(){
      audioPlayer.stop()    
  }
  
  
}// class

