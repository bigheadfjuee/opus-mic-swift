//
//  AudioEngine.swift
//  opus-mic-swift
//
//  Created by Tony on 2021/10/9.
//

import Foundation
import AVFoundation
import Network

class AudioEngine {
  enum RecordingState {
    case recording, paused, stopped
  }
  
  private var audioEngine: AVAudioEngine!
  private var mixerNode: AVAudioMixerNode!
  private var state: RecordingState = .stopped
  
  
  private var connection: NWConnection?
  
  var host: NWEndpoint.Host = "127.0.0.1"
  var port: NWEndpoint.Port = 5566
  
  init() {
    udpConnect()
    setupSession()
    setupEngine()
  }
  
  func udpSend(_ payload: Data) {
    connection!.send(content: payload, completion: .contentProcessed({ sendError in
      if let error = sendError {
        NSLog("Unable to process and send the data: \(error)")
      }
    }))
  }
  
  func udpConnect() {
    debugPrint("udpConnect")
    connection = NWConnection(host: host, port: port, using: .udp)
    /*
    connection!.stateUpdateHandler = { (newState) in
      switch (newState) {
      case .preparing:
        NSLog("Entered state: preparing")
      case .ready:
        NSLog("Entered state: ready")
      case .setup:
        NSLog("Entered state: setup")
      case .cancelled:
        NSLog("Entered state: cancelled")
      case .waiting:
        NSLog("Entered state: waiting")
      case .failed:
        NSLog("Entered state: failed")
      default:
        NSLog("Entered an unknown state")
      }
    }
    
    connection!.viabilityUpdateHandler = { (isViable) in
      if (isViable) {
        NSLog("Connection is viable")
      } else {
        NSLog("Connection is not viable")
      }
    }
    
    connection!.betterPathUpdateHandler = { (betterPathAvailable) in
      if (betterPathAvailable) {
        NSLog("A better path is availble")
      } else {
        NSLog("No better path is available")
      }
    }
    */
    connection!.start(queue: .global())
  }
  
  fileprivate func setupSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.record)
    try? session.setActive(true, options: .notifyOthersOnDeactivation)
  }
  
  fileprivate func setupEngine() {
    audioEngine = AVAudioEngine()
    mixerNode = AVAudioMixerNode()
    
    // Set volume to 0 to avoid audio feedback while recording.
    mixerNode.volume = 0
    
    audioEngine.attach(mixerNode)
    
    makeConnections()
    
    // Prepare the engine in advance, in order for the system to allocate the necessary resources.
    audioEngine.prepare()
    debugPrint("setupEngine")
  }
  
  fileprivate func makeConnections() {
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
    
    let mainMixerNode = audioEngine.mainMixerNode
    let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 1, interleaved: false)
    audioEngine.connect(mixerNode, to: mainMixerNode, format: mixerFormat)
  }
  
  func startRecordToFile() throws {
    let tapNode: AVAudioNode = mixerNode
    let format = tapNode.outputFormat(forBus: 0)
    
    let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // AVAudioFile uses the Core Audio Format (CAF) to write to disk.
    // So we're using the caf file extension.
    let file = try AVAudioFile(forWriting: documentURL.appendingPathComponent("rec"), settings: format.settings)
    
    tapNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: {
      (buffer, time) in
      try? file.write(from: buffer)
      
    })
    
    try audioEngine.start()
    state = .recording
  }
  
  func resumeRecording() throws {
    try audioEngine.start()
    state = .recording
  }
  
  func pauseRecording() {
    audioEngine.pause()
    state = .paused
  }
  
  func stopRecordToFile() {
    // Remove existing taps on nodes
    mixerNode.removeTap(onBus: 0)
    
    audioEngine.stop()
    state = .stopped
  }
  
  
  func startRecording() throws {
    /*
     MT3_UDP_PORT = 8000;
     AUDIO_SAMPLE_RATE = 24 * 1000; // 24 KHz
     AUDIO_BIT_DEPTH = 16; // 16 bit
     AUDIO_CHANNEL = 1; // mono
     OPUS_DURATION = 10; // ms
     OPUS_BIT_RATE = 64 * 1000; //64 kbps
     
     frameSize = (config.AUDIO_SAMPLE_RATE / 1000) * config.OPUS_DURATION;
     
     */
    
    var converter: AVAudioConverter!
    var compressedBuffer: AVAudioCompressedBuffer?
    let tapNode: AVAudioNode = mixerNode
    let format = tapNode.outputFormat(forBus: 0)
    
    var outDesc = AudioStreamBasicDescription()
    
    outDesc.mSampleRate = 24000 // format.sampleRate
    outDesc.mChannelsPerFrame = 1
    outDesc.mFormatID = kAudioFormatFLAC //kAudioFormatFLAC
    
    let framesPerPacket: UInt32 = 1152 //1152
    outDesc.mFramesPerPacket = framesPerPacket
    outDesc.mBitsPerChannel = 16
    outDesc.mBytesPerPacket = 0
    
    let convertFormat = AVAudioFormat(streamDescription: &outDesc)!
    converter = AVAudioConverter(from: format, to: convertFormat)
    if(converter == nil) {
      debugPrint("converter is nil")
      return
    }
    
    let packetSize: UInt32 = 8
    let bufferSize = framesPerPacket * packetSize
    
    tapNode.installTap(onBus: 0, bufferSize: bufferSize, format: format, block: {
      [weak self] (buffer, time) in
      guard let weakself = self else {
        return
      }
      
      compressedBuffer = AVAudioCompressedBuffer(
        format: convertFormat,
        packetCapacity: packetSize,
        maximumPacketSize: converter.maximumOutputPacketSize
      )
      
      // input block is called when the converter needs input
      let inputBlock : AVAudioConverterInputBlock = { (inNumPackets, outStatus) -> AVAudioBuffer? in
        outStatus.pointee = AVAudioConverterInputStatus.haveData;
        return buffer; // fill and return input buffer
      }
      
      // Conversion loop
      var outError: NSError? = nil
      converter.convert(to: compressedBuffer!, error: &outError, withInputFrom: inputBlock)
      
      let audioBuffer = compressedBuffer!.audioBufferList.pointee.mBuffers
      if let mData = audioBuffer.mData {
        let length = Int(audioBuffer.mDataByteSize)
        let data: NSData = NSData(bytes: mData, length: length)
        // Do something with data
//        self!.udpSend(data as Data)
        print(data.length)
      }
      else {
        print("error")
      }
    })
    
    
    try audioEngine.start()
    state = .recording
  }

  func stopRecording() {
    mixerNode.removeTap(onBus: 0)
    audioEngine.stop()
    //    converter.reset()
    //    converter.
    state = .stopped
  }
  
  fileprivate var isInterrupted = false
  
  // Call this function at init
  fileprivate func registerForNotifications() {
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: nil
    )
    { [weak self] (notification) in
      guard let weakself = self else {
        return
      }
      
      let userInfo = notification.userInfo
      let interruptionTypeValue: UInt = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
      let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue)!
      
      switch interruptionType {
      case .began:
        weakself.isInterrupted = true
        
        if weakself.state == .recording {
          weakself.pauseRecording()
        }
      case .ended:
        weakself.isInterrupted = false
        
        // Activate session again
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        
        weakself.handleConfigurationChange()
        
        if weakself.state == .paused {
          try? weakself.resumeRecording()
        }
      @unknown default:
        break
      }
    }
  }
  
  fileprivate var configChangePending = false
  
  
  
  fileprivate func handleConfigurationChange() {
    if configChangePending {
      makeConnections()
    }
    
    configChangePending = false
  }
  
}

/*
 // Add this to registerForNotifications
 NotificationCenter.default.addObserver(
 forName: Notification.Name.AVAudioEngineConfigurationChange,
 object: nil,
 queue: nil
 ) { [weak self] (notification) in
 guard let weakself = self else {
 return
 }
 
 weakself.configChangePending = true
 
 if (!weakself.isInterrupted) {
 weakself.handleConfigurationChange()
 } else {
 print("deferring changes")
 }
 }
 */
