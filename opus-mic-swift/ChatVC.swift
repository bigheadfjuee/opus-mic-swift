//
//  ChatVC.swift
//  opus-mic-swift
//
//  Created by Tony on 2021/10/5.
//

import Foundation
import UIKit
import MapKit
//import MessageKit
import AVFoundation
import OpusKit
import os

class BasicChatViewController: UIViewController { //ChatViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
                        
        debugPrint("Initilizing opus lib kit")
        OpusKit.shared.initialize(sampleRate: Opus.SAMPLE_RATE_DEFAULT,
                                  numberOfChannels: Opus.CHANNEL_COUNT_DEFAULT,
                                  packetSize: Opus.OPUS_ENCODER_BUFFER_SIZE,
                                  encodeBlockSize: Opus.FRAME_SIZE_DEFAULT)
                                  
        // configure record button here
    }
    
    //
    // MARK - recording
    //
    var isRecording = false
    var avAudioPlayer: AVAudioPlayer!
    var audioRecorder: AVAudioRecorder!
    
    @objc
    func onTapRecordButton(sender: UIButton){
        toggleRecording()
    }
    
    private func toggleRecording(){
              
        debugPrint("isRecording: \(isRecording)")
        
        if isRecording {
            
            isRecording = false
            
            stopRecording()
            
        } else {
            
            isRecording = true
            
            checkPermissionAndStartRecording()
        }
    }
    //
    // END - recording
    //
}
//
// Audio recording related extensions
//
extension BasicChatViewController: AVAudioRecorderDelegate {
    
    private func checkPermissionAndStartRecording() {
        
        debugPrint(#function)
        
        AudioUtil.checkRecordingPermission() { isPermissionGranted in
            
            debugPrint("isPermissionGranted: \(isPermissionGranted)")
            
            if isPermissionGranted {
                self.recordUsingAVAudioRecorder()
            } else {
                debugPrint("don't have permission to record")
            }
        }
    }
    
    private func setupRecorder() {
        
        debugPrint(#function)
        
        let tempAudioFileUrl = AudioUtil.TEMP_WAV_FILE
        debugPrint("tempAudioFileUrl: \(tempAudioFileUrl)")
        
//        let linearPcmRecordingSettings = LinearPCMRecording.LINEAR_PCM_RECODING_SETTINGS_DEFAULT
//        debugPrint("RecordingSettings: \(linearPcmRecordingSettings)")
        
        do {
            
            startRecordingSession()
            
          audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: tempAudioFileUrl), settings: [AVLinearPCMBitDepthKey:16])
                    
            audioRecorder.delegate = self
            //audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
        }
        catch {
            debugPrint("\(error.localizedDescription)")
        }
    }
    
    private func startRecording() {
        
        debugPrint(#function)
        
        if audioRecorder == nil {
            setupRecorder()
        }
        
        audioRecorder.record()
    }
    
    private func stopRecording() {
        
        debugPrint(#function)
        
        guard audioRecorder != nil else {
            return
        }
        
        audioRecorder.stop()
    }
    
    private func deleteTempAudioFile(){
        
        debugPrint(#function)
        
        guard audioRecorder != nil else {
            return
        }
        
        if audioRecorder.isRecording {
            return
        }
        
        // delete temporary audio file
        let recordingDeleted = audioRecorder.deleteRecording()
        if recordingDeleted {
            debugPrint("temp (recorded) audio file deleted")
        } else {
            debugPrint("failed to delete temp (recorded) audio file")
        }
    }
    
    private func startRecordingSession(){
        
        debugPrint(#function)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            debugPrint("Failed to deactivate recording session")
        }
    }
    
    private func stopRecordingSession(){
        
        debugPrint(#function)
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            debugPrint("Failed to deactivate recording session")
        }
    }
    
    private func recordUsingAVAudioRecorder(){
        
        debugPrint(#function)
        
        setupRecorder()
        
        startRecording()
    }
    
    private func encodeRecordedAudio(){
        
        debugPrint(#function)
        
      let pcmData = AudioUtil.extractPcmOnly(from: URL(fileURLWithPath: AudioUtil.TEMP_WAV_FILE))
        
        if pcmData.count > 1 {
            
            debugPrint("encoding pcm to self-delimited opus")
            
            let encodedOpusData = AudioUtil.encodeToSelfDelimitedOpus(pcmData: pcmData, splitSize: PCM.SPLIT_CHUNK_SIZE_DEFAULT)
            debugPrint("encoded opus: \(encodedOpusData)")
            
            
            debugPrint("save encoded opus")
            AudioUtil.saveAudio(to: URL(fileURLWithPath: AudioUtil.ENCODED_OPUS_FILE), audioData: encodedOpusData)
            
        } else {
            debugPrint("no data to encode")
        }

        deleteTempAudioFile()
        stopRecordingSession()
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        debugPrint(#function)
        
        let finishedSuccessFully = flag
        
        if finishedSuccessFully {
            
            debugPrint("finished recording successfully")
            
            encodeRecordedAudio()
            
        } else {
            debugPrint("recording failed - audio encoding error")
        }
    }
}
