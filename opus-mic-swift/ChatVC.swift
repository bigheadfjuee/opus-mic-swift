//
//  ChatVC.swift
//  opus-mic-swift
//
//  Created by Tony on 2021/10/5.
//

import Foundation
import UIKit
import MapKit
import MessageKit
import AVFoundation
import OpusKit
import os

class BasicChatViewController: ChatViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Logger.logIt(#function)
        
        Logger.logIt("Initilizing opus lib kit")
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
        
        Logger.logIt(#function)
        
        toggleRecording()
    }
    
    private func toggleRecording(){
        
        Logger.logIt(#function)
        
        Logger.logIt("isRecording: \(isRecording)")
        
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
        
        Logger.logIt(#function)
        
        AudioUtil.checkRecordingPermission() { isPermissionGranted in
            
            Logger.logIt("isPermissionGranted: \(isPermissionGranted)")
            
            if isPermissionGranted {
                self.recordUsingAVAudioRecorder()
            } else {
                Logger.logIt("don't have permission to record")
            }
        }
    }
    
    private func setupRecorder() {
        
        Logger.logIt(#function)
        
        let tempAudioFileUrl = AudioUtil.TEMP_WAV_FILE
        Logger.logIt("tempAudioFileUrl: \(tempAudioFileUrl)")
        
        let linearPcmRecordingSettings = LinearPCMRecording.LINEAR_PCM_RECODING_SETTINGS_DEFAULT
        Logger.logIt("RecordingSettings: \(linearPcmRecordingSettings)")
        
        do {
            
            startRecordingSession()
            
            audioRecorder = try AVAudioRecorder(url: tempAudioFileUrl, settings: linearPcmRecordingSettings)
            audioRecorder.delegate = self
            //audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
        }
        catch {
            Logger.logIt("\(error.localizedDescription)")
        }
    }
    
    private func startRecording() {
        
        Logger.logIt(#function)
        
        if audioRecorder == nil {
            setupRecorder()
        }
        
        audioRecorder.record()
    }
    
    private func stopRecording() {
        
        Logger.logIt(#function)
        
        guard audioRecorder != nil else {
            return
        }
        
        audioRecorder.stop()
    }
    
    private func deleteTempAudioFile(){
        
        Logger.logIt(#function)
        
        guard audioRecorder != nil else {
            return
        }
        
        if audioRecorder.isRecording {
            return
        }
        
        // delete temporary audio file
        let recordingDeleted = audioRecorder.deleteRecording()
        if recordingDeleted {
            Logger.logIt("temp (recorded) audio file deleted")
        } else {
            Logger.logIt("failed to delete temp (recorded) audio file")
        }
    }
    
    private func startRecordingSession(){
        
        Logger.logIt(#function)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.logIt("Failed to deactivate recording session")
        }
    }
    
    private func stopRecordingSession(){
        
        Logger.logIt(#function)
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            Logger.logIt("Failed to deactivate recording session")
        }
    }
    
    private func recordUsingAVAudioRecorder(){
        
        Logger.logIt(#function)
        
        setupRecorder()
        
        startRecording()
    }
    
    private func encodeRecordedAudio(){
        
        Logger.logIt(#function)
        
        let pcmData = AudioUtil.extractPcmOnly(from: AudioUtil.TEMP_WAV_FILE)
        
        if pcmData.count > 1 {
            
            Logger.logIt("encoding pcm to self-delimited opus")
            
            let encodedOpusData = AudioUtil.encodeToSelfDelimitedOpus(pcmData: pcmData, splitSize: PCM.SPLIT_CHUNK_SIZE_DEFAULT)
            Logger.logIt("encoded opus: \(encodedOpusData)")
            
            
            Logger.logIt("save encoded opus")
            AudioUtil.saveAudio(to: AudioUtil.ENCODED_OPUS_FILE, audioData: encodedOpusData)
            
        } else {
            Logger.logIt("no data to encode")
        }

        deleteTempAudioFile()
        stopRecordingSession()
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        Logger.logIt(#function)
        
        let finishedSuccessFully = flag
        
        if finishedSuccessFully {
            
            Logger.logIt("finished recording successfully")
            
            encodeRecordedAudio()
            
        } else {
            Logger.logIt("recording failed - audio encoding error")
        }
    }
}
