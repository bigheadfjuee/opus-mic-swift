//
//  AudioUnit.swift
//  opus-mic-swift
//
//  Created by Tony on 2021/10/5.
//

import Foundation
import AVFoundation
import OpusKit

// Opus audio info.
//
public class OpusAudioInfo {
    
    public static let `default` = OpusAudioInfo()
    
    var channels: opus_int32
    var headerSize: Int // bytes
    var packetSize: opus_int32
    var sampleRate: opus_int32 {
        didSet {
            packetSize = Int32(Opus.FRAME_DURATION_DEFAULT) * (sampleRate / 1000)
        }
    }
    
    public init(sampleRate: opus_int32 = Opus.SAMPLE_RATE_16_KHZ,
                channels: opus_int32 = Opus.CHANNEL_COUNT_DEFAULT,
                headerSize: Int = 1) {
        self.sampleRate = sampleRate
        self.packetSize =  Int32(Opus.FRAME_DURATION_DEFAULT) * (sampleRate / 1000)
        self.channels = channels
        self.headerSize = headerSize
    }
}

//
// RAW PCM info.
//
public class PCMInfo {
    
    public static let `default` = PCMInfo()
    
    var sampleRate:Int32
    var channels:Int16
    var bitDepth:Int16
    
    public init(sampleRate:Int32 = PCM.SAMPLE_RATE_16_KHZ,
                channels:Int16 = Int16(PCM.MONO),
                bitDepth:Int16 = Int16(PCM.BIT_DEPTH_DEFAULT)) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
    }
}

//
// Utility class for audio related operations
//
public class AudioUtil {
    
    private init(){}

    
    
    //
    // Default audio files url in document directory
    //
  public static let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
  
    public static let RAW_PCM_FILE = documentsPath + "/pcm.raw"
    public static let TEMP_WAV_FILE =   documentsPath + "/wav.wav"
    public static let ENCODED_OPUS_FILE = documentsPath + "/encoded_opus_ios.opus"
    public static let DECODED_WAV_WITH_HEADER_FILE = documentsPath + "/decoded_wav_with_header.wav"
  

/**
 Creates fake wav header to play Linear PCM
 
 AVAudioPlayer by default can not play Linear PCM, therefore we need to create a fake wav header
 
 - parameter sampleRate: samples per second
 - parameter channelCount: number of channels
 - parameter bitDepth: bits per sample
 - parameter pcmDataSizeInBytes: PCM data size in bytes
 
 - returns : Data - wav header data
 */
public static func createWavHeader(sampleRate: Int32, channelCount: Int16, bitDepth: Int16, pcmDataSizeInBytes dataSize: Int32) -> Data {
    
    /*
     
     WAV header details: http://www.topherlee.com/software/pcm-tut-wavformat.html
     
     Positions    Sample Value    Description
     1 - 4    "RIFF"    Marks the file as a riff file. Characters are each 1 byte long.
     5 - 8    File size (integer)    Size of the overall file - 8 bytes, in bytes (32-bit integer). Typically, you'd fill this in after creation.
     9 -12    "WAVE"    File Type Header. For our purposes, it always equals "WAVE".
     13-16    "fmt "    Format chunk marker. Includes trailing null
     17-20    16    Length of format data as listed above
     21-22    1    Type of format (1 is PCM) - 2 byte integer
     23-24    2    Number of Channels - 2 byte integer
     25-28    44100    Sample Rate - 32 byte integer. Common values are 44100 (CD), 48000 (DAT). Sample Rate = Number of Samples per second, or Hertz.
     29-32    176400    (Sample Rate * BitsPerSample * Channels) / 8.
     33-34    4    (BitsPerSample * Channels) / 8.1 - 8 bit mono2 - 8 bit stereo/16 bit mono4 - 16 bit stereo
     35-36    16    Bits per sample
     37-40    "data"    "data" chunk header. Marks the beginning of the data section.
     41-44    File size (data)    Size of the data section.
     Sample values are given above for a 16-bit stereo source.
     
     
     
     An example in swift :
     
     let WAV_HEADER: [Any] = [
     "R","I","F","F",
     0xFF,0xFF,0xFF,0x7F,  // file size
     "W","A","V","E",
     "f","m","t"," ",      // Chunk ID
     0x10,0x00,0x00,0x00,  // Chunk Size - length of format above
     0x01,0x00,            // Format Code: 1 is PCM, 3 is IEEE float
     0x01,0x00,            // Number of Channels (e.g. 2)
     0x80,0xBB,0x00,0x00,  // Samples per Second, Sample Rate (e.g. 48000)
     0x00,0xDC,0x05,0x00,  // Bytes per second, byte rate = sample rate * bits per sample * channels / 8
     0x08,0x00,            // Bytes per Sample Frame, block align = bits per sample * channels / 8
     0x20,0x00,            // bits per sample (16 for PCM, 32 for float)
     "d","a","t","a",
     0xFF,0xFF,0xFF,0x7F   // size of data section
     ]
     */
    
    let WAV_HEADER_SIZE:Int32 = 44
    let FORMAT_CODE_PCM:Int16 = 1
    
    let fileSize:Int32 = dataSize + WAV_HEADER_SIZE

    let sampleRate:Int32 = sampleRate
    let subChunkSize:Int32 = 16
    let format:Int16 = FORMAT_CODE_PCM
    let channels:Int16 = channelCount
    let bitsPerSample:Int16 = bitDepth
    let byteRate:Int32 = sampleRate * Int32(channels * bitsPerSample / 8)
    let blockAlign: Int16 = (bitsPerSample * channels) / 8
    
    let header = NSMutableData()
    
    header.append([UInt8]("RIFF".utf8), length: 4)
    
    header.append(byteArray(from: fileSize), length: 4)
    
    //WAVE
    header.append([UInt8]("WAVE".utf8), length: 4)
    
    //FMT
    header.append([UInt8]("fmt ".utf8), length: 4)
    header.append(byteArray(from: subChunkSize), length: 4)
    
    header.append(byteArray(from: format), length: 2)
    header.append(byteArray(from: channels), length: 2)
    header.append(byteArray(from: sampleRate), length: 4)
    header.append(byteArray(from: byteRate), length: 4)
    header.append(byteArray(from: blockAlign), length: 2)
    header.append(byteArray(from: bitsPerSample), length: 2)
    
    
    header.append([UInt8]("data".utf8), length: 4)
    header.append(byteArray(from: dataSize), length: 4)
    
    return header as Data
}

/**
 Creates default wav header based on default PCM constants
 
 - parameter dataSize: size of PCM data in bytes
 
 - returns : Data - wav header data
 */
public static func createDefaultWavHeader(dataSize: Int32) -> Data {
    
    return createWavHeader(sampleRate: PCM.SAMPLE_RATE_DEFAULT,
                           channelCount: Int16(PCM.CHANNEL_COUNT_DEFAULT),
                           bitDepth: Int16(PCM.BIT_DEPTH_DEFAULT),
                           pcmDataSizeInBytes: dataSize)
}

    /**
     Converts given value to byte array
     
     - parameter value:FixedWidthInteger type
     
     - returns: array of bytes
     */
    public static func byteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        // https://stackoverflow.com/a/56964191/4802664
        // .littleEndian is required
        return withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }
    
    /**
     Generates wav audio data buffer from given header and raw PCM
     
     - parameter wavHeader: a fake RIFF WAV header (appended to PCM)
     - parameter pcmData: Linear PCM data
     
     - returns: Data
     */
    public static func generateWav(header wavHeader: Data, pcmData: Data) -> Data {
        
        var wavData = Data()
        
        wavData.append(wavHeader)
        wavData.append(pcmData)
        
        return wavData
    }
    
    /**
     Checks permission for recording and invokes callback with flag
     
     - parameter callback: clouser to invoked after checking permission
     */
    public static func checkRecordingPermission(onPermissionChecked callback: @escaping(_ isPermissionGranted: Bool) -> Void) {
               
        var isPermissionGranted = false
        
        switch AVAudioSession.sharedInstance().recordPermission {
            
        case .granted:
            isPermissionGranted = true
            break
            
        case .denied:
            isPermissionGranted = false
            break
            
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (allowed) in
                if allowed {
                    isPermissionGranted = true
                } else {
                    isPermissionGranted = false
                }
            })
            break
            
        default:
            isPermissionGranted = false
            break
        }
        
        callback(isPermissionGranted)
    }

    /**
     Saves given audio data to specified url
     
     - parameter fileUri: file url where audio data will be saved
     */
    public static func saveAudio(to fileUri: URL, audioData: Data) {
        
        debugPrint(#function)
        debugPrint("save to: \(fileUri)")
        
        do {
            try audioData.write(to: fileUri)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    /**
     Encodes given PCM data into self delimited opus (`|header|data|header|data|...|`) using libopus
     
     - parameter pcmData: Linear PCM data buffer (loaded from file or coming from AudioEngine tapping)
     - parameter splitSize: size of chunk to split the given pcmData
     - returns : encoded data (encoded as: `|header|data|header|data|...|`)
     */
    public static func encodeToSelfDelimitedOpus(pcmData: Data, splitSize: Int) -> Data {
        
        debugPrint(#function)
        
        var encodedData = Data()
        
        var readIndex = 0
        var readStart = 0
        var readEnd = 0
        
        var pcmChunk: Data
        
        var readCount = 1
        let splitCount = (pcmData.count / splitSize)
        debugPrint("split count: \(splitCount)")
        
        var header: Data
        
        while readCount <=  splitCount {
            
            readStart = readIndex
            readEnd = readStart + splitSize
            
            //
            // to prevent index out of bound exception
            // check readEnd index
            //
            if(readEnd >= pcmData.count){
                readEnd = readStart + (pcmData.count - readIndex)
            }
            
            pcmChunk = pcmData[readStart..<readEnd]
            //print("chunk: \(pcmChunk)")
            
            if let encodedChunk = OpusKit.shared.encodeData(pcmChunk) {
                
                //
                // header is exactly one byte
                // header indicates size of the encoded opus data
                //
              do {
                try header = Data(from: encodedChunk.count as! Decoder)[0..<1]
                encodedData.append(header)
                encodedData.append(encodedChunk)
              }
              catch _ {
                
              }
                //debugPrint("header: \([UInt8](header))")
                
                
            } else {
                print("failed to encode at index: \(readStart)")
            }
            
            readIndex += splitSize
            readCount += 1
        }
        
        //
        // remaining data
        //
        //debugPrint("append remaining data")
        pcmChunk = pcmData[readIndex..<pcmData.count]
        
        if let encodedChunk = OpusKit.shared.encodeData(pcmChunk) {
          do {
            try header = Data(from: encodedChunk.count as! Decoder)[0..<1]
            encodedData.append(header)
            encodedData.append(encodedChunk)
          }catch _ {
            
          }
            //debugPrint("header: \([UInt8](header))")
        } else {
            print("failed to encode at index: \(readIndex)")
        }
        
        return encodedData
    }
    
    /**
     Decodes given self delimited opus data to PCM
     
     Custom opus is encoded as `|header|data|header|data|...|`
     Loops over the data, reads data size from header and takes slice/chunk of given opus data based on data size from header. Then each chunk is decode using libopus
     
     - parameter opusData: Encoded opus data buffer
     - parameter headerSizeInBytes: size of header in bytes (default is 1)
     - returns : decoded pcm data
     */
    public static  func decodeSelfDelimitedOpusToPcm(opusData: Data, headerSizeInBytes headerSize: Int = 1) -> Data {
        
        var decodedData: Data = Data()
        
        var headerData: Data
        var opusChunkSizeFromHeader = 0
        var readIndex = 0
        var readStart = 0
        var readEnd = 0
        var extractedOpusChunk: Data
        
        
        while readIndex < opusData.count {
            
            headerData = opusData[readIndex..<(readIndex + headerSize)]
            //debugPrint("headerData: \([UInt8](headerData))")
            
            opusChunkSizeFromHeader = Int([UInt8](headerData)[0])
            
            readStart = readIndex + headerSize
            readEnd = readStart + opusChunkSizeFromHeader
            
            extractedOpusChunk = opusData[readStart..<readEnd]
            //debugPrint("extracted: \(extractedOpusChunk)")
            
            if let decodedDataChunk = OpusKit.shared.decodeData(extractedOpusChunk) {
                //debugPrint("decodedDataChunk: \(decodedDataChunk)")
                decodedData.append(decodedDataChunk)
            } else {
                print("failed to decode at index: \(readStart)")
            }
            
            readIndex += (headerSize + opusChunkSizeFromHeader)
        }
        
        return decodedData
    }
    
    /**
     Extracts PCM only from a audio file using AVAssetReader
     
     Normally system will append some meta data while saving audio file with extension, and therefore we need to use AVAssetReader to get PCM only
     
     - parameter fileUrl : audio file url
     
     - returns: PCM  Data
     */
    public static func extractPcmOnly(from fileUrl: URL) -> Data {
        
        let pcmOnly = NSMutableData()

        do {
            
            let asset = AVAsset(url: fileUrl)
            let assetReader = try AVAssetReader(asset: asset)
            let track = asset.tracks(withMediaType: AVMediaType.audio).first
          
            
          let trackOutput = AVAssetReaderTrackOutput(track: track!, outputSettings: [:])
            
            assetReader.add(trackOutput)
            assetReader.startReading()
            
            debugPrint("reading data with AVAssetReader")
            while assetReader.status == AVAssetReader.Status.reading {
                
                if let sampleBufferRef = trackOutput.copyNextSampleBuffer() {
                    
                    if let blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef) {
                        
                        let bufferLength = CMBlockBufferGetDataLength(blockBufferRef)
                        let data = NSMutableData(length: bufferLength)
                        
                        // func CMBlockBufferCopyDataBytes(_ theSourceBuffer: CMBlockBuffer, atOffset offsetToData: Int, dataLength: Int, destination: UnsafeMutableRawPointer) -> OSStatus
                        CMBlockBufferCopyDataBytes(blockBufferRef, atOffset: 0, dataLength: bufferLength, destination: data!.mutableBytes)
                        
                        let samples = data!.mutableBytes.assumingMemoryBound(to: UInt16.self)
                        pcmOnly.append(samples, length: bufferLength)
                        CMSampleBufferInvalidate(sampleBufferRef)
                    }
                    
                } else {
                    debugPrint("failed to copy next")
                }
            }
        } catch {
            debugPrint(error.localizedDescription)
        }
        
        return pcmOnly as Data
    }
}
