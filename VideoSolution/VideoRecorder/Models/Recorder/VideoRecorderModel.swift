//
//  VideoRecorderModel.swift
//  VideoSolution
//
//  Created by Galean Pallerman on 30.07.2019.
//  Copyright © 2019 GPco. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import Vision

fileprivate func tempURL() -> URL {
    let directory = NSTemporaryDirectory() as NSString
    
    let path = directory.appendingPathComponent(NSUUID().uuidString + ".mov")
    return URL(fileURLWithPath: path)
}

//MARK: Protocol
protocol VideoRecorderModelProtocol {
    var delegate: VideoRecorderModelDelegate? { get set }
    
    var audioMuted: Bool { get set }
    
    func startRecording()
    func pauseRecording()
    func stopRecording()
    
    func videoOutputToRecord(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                             assosiatedPixelBuffer pxBuffer: CVPixelBuffer,
                             from connection: AVCaptureConnection)
    func audioOutputToRecord(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                             from connection: AVCaptureConnection)
}

//MARK:- Delegate
protocol VideoRecorderModelDelegate: NSObject {
    func videoSavedToTheCameraRoll()
}

//MARK:-
class VideoRecorderModel: NSObject {
    //MARK: Properties
    //Internal
    public weak var delegate: VideoRecorderModelDelegate?
    
    fileprivate var isAudioMuted: Bool = false
    fileprivate(set) lazy var isRecordingVideo = false
    fileprivate var videoWriter: AVAssetWriter!
    fileprivate var videoWriterInput: AVAssetWriterInput!
    fileprivate var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor?
    fileprivate var audioWriterInput: AVAssetWriterInput!
    fileprivate var sessionAtSourceTime: CMTime?
    
    var currentSampleTime: CMTime?
    var currentVideoDimensions: CMVideoDimensions?
}

//MARK:- Internal recording
extension VideoRecorderModel {
    private func internalStartRecording() {
        guard !isRecordingVideo else { return }
        setupWriter()
        isRecordingVideo = true
        sessionAtSourceTime = nil
    }
    
    private func internalStopRecording() {
        guard isRecordingVideo else { return }
        isRecordingVideo = false
        videoWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
            guard let url = self?.videoWriter.outputURL else { return }
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, #selector(self?.video(videoPath:didFinishSavingWith:contextInfo:)), nil)
        }
    }
    
    fileprivate func setupWriter() {
        do {
            videoWriter = try AVAssetWriter(url: tempURL(), fileType: AVFileType.mov)
            
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(currentVideoDimensions!.width),
                AVVideoHeightKey: Int(currentVideoDimensions!.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2300000,
                ],
                ])
            videoWriterInput.expectsMediaDataInRealTime = true
            
            let sourcePixelBufferAttributesDictionary = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32BGRA),
                String(kCVPixelBufferWidthKey) : Int(currentVideoDimensions!.width),
                String(kCVPixelBufferHeightKey) : Int(currentVideoDimensions!.height),
                String(kCVPixelFormatOpenGLESCompatibility) : kCFBooleanTrue as Any
                ] as [String : Any]
            
            assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
            
            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
            }
            
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 64000,
                ])
            audioWriterInput.expectsMediaDataInRealTime = true
            
            if videoWriter.canAdd(audioWriterInput) {
                videoWriter.add(audioWriterInput)
            }
            
            videoWriter.startWriting() 
        }
        catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    fileprivate func canWrite() -> Bool {
        return isRecordingVideo
            && videoWriter != nil
            && videoWriter.status == .writing
    }

    
    // Called at the very end of the video recording, after saving the video to the camera roll
    @objc func video(videoPath: String, didFinishSavingWith error: NSError?, contextInfo: Any ) {
        if error == nil {
            self.delegate?.videoSavedToTheCameraRoll()
        }
    }
}

extension VideoRecorderModel: AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate {
    private func beginWritingSessionIfNeededWith(output sampleBuffer: CMSampleBuffer) {
        let writable = canWrite()
        
        if writable,
            sessionAtSourceTime == nil {
            //Start writing
            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoWriter.startSession(atSourceTime: sessionAtSourceTime!)
        }
    }
    
    private func writeVideo(buffer pixelBuffer: CVPixelBuffer) {
        let writable = canWrite()

        if writable,
            videoWriterInput.isReadyForMoreMediaData {
            assetWriterPixelBufferInput!.append(pixelBuffer,
                                                withPresentationTime: currentSampleTime!)
        }
    }
    
    private func writeAudio(buffer sampleBuffer: CMSampleBuffer) {
        let writable = canWrite()

        if writable,
            audioWriterInput.isReadyForMoreMediaData {
            //Write audio buffer
            if audioMuted {
                let buffRef = CMSampleBufferGetDataBuffer(sampleBuffer)
                CMBlockBufferFillDataBytes(with: 0, blockBuffer: buffRef!, offsetIntoDestination: 0, dataLength: CMBlockBufferGetDataLength(buffRef!))
            }
            audioWriterInput.append(sampleBuffer)
        }
    }
}

//MARK:- VideoRecorderModelProtocol
extension VideoRecorderModel: VideoRecorderModelProtocol{
    func videoOutputToRecord(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                             assosiatedPixelBuffer pxBuffer: CVPixelBuffer,
                             from connection: AVCaptureConnection) {
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
        self.currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        self.currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
        
        beginWritingSessionIfNeededWith(output: sampleBuffer)
        
        writeVideo(buffer: pxBuffer)
    }
    
    func audioOutputToRecord(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        beginWritingSessionIfNeededWith(output: sampleBuffer)

        writeAudio(buffer: sampleBuffer)
    }
    
    public var audioMuted: Bool {
        get {
            return isAudioMuted
        }
        set (muted) {
            isAudioMuted = muted
        }
    }
    
    func startRecording() {
        internalStartRecording()
    }
    
    func pauseRecording() {
        isRecordingVideo = false
    }
    
    func resumeRecording() {
        isRecordingVideo = true
    }
    
    func stopRecording() {
        internalStopRecording()
    }
}

