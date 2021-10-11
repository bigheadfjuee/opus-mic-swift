
//  ContentView.swift
//  opus-mic-swift
//
//  Created by Tony Lee on 2021/9/15.
//

import SwiftUI
import Foundation
import AVFoundation

struct ContentView: View {
  //  @ObservedObject private var mic = OpusMicRec(numberOfSamples: numberOfSamples)
  @ObservedObject var audioRecorder: AudioRecorder
  @State private var isRecording = false
  @State private var isPlaying = false
  var audioEngine = AudioEngine()
  
  var body: some View {
    
    VStack (spacing: 50){
      Button(action: {
        // click event
        debugPrint("startRecording")
//        self.audioRecorder.startRecording()
        do {
//          try audioEngine.startRecordToFile()
          try audioEngine.startRecording()
        } catch {
          debugPrint(error)
        }
        
        isRecording = true
      }){
        HStack {
          Image(systemName: "record.circle").font(.title)
          Text("Record").fontWeight(.semibold).font(.title)
        }
        .padding()
        .frame(width: 200)
        .foregroundColor(.white)
        .background( isRecording ? Color.white : .red)
        .cornerRadius(40)
      }.disabled(isRecording)
    
      Button(action: {
       // click event
        debugPrint("stopRecording")
//        self.audioRecorder.stopRecording()
//        audioEngine.stopRecordToFile()
        audioEngine.stopRecording()
        isRecording = false
      }){
        HStack {
          Image(systemName: "stop.circle").font(.title)
          Text("Stop").fontWeight(.semibold).font(.title)
        }
        .padding()
        .frame(width: 200)
        .foregroundColor(.white)
        .background(isRecording ? Color.gray : .white)
        .cornerRadius(40)
        
      }.disabled(!isRecording)
      
      
      Button(action: {
       // click event
        debugPrint("play")
        audioRecorder.startPlaying()
        isPlaying = true
      }){
        HStack {
          Image(systemName: "play.circle").font(.title)
          Text("Play").fontWeight(.semibold).font(.title)
        }
        .padding()
        .frame(width: 200)
        .foregroundColor(.white)
        .background(isPlaying ? Color.white : .green)
        .cornerRadius(40)
        
      }.disabled(isPlaying)
      
      Button(action: {
       // click event
        debugPrint("stop play")
        audioRecorder.stopPlaying()
        isPlaying = false
      }){
        HStack {
          Image(systemName: "stop.circle").font(.title)
          Text("Stop Play").fontWeight(.semibold).font(.title)
        }
        .padding()
        .frame(width: 200)
        .foregroundColor(.white)
        .background(isPlaying ? Color.green : .white)
        .cornerRadius(40)
        
      }.disabled(!isPlaying)
      
    }// VSTack
    
    
  }// body
  
  
} // struct ContentView

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(audioRecorder: AudioRecorder())
  }
}
