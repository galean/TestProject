//
//  VideoOutputModel.swift
//  VideoSolution
//
//  Created by Galean Pallerman on 02.08.2019.
//  Copyright © 2019 GPco. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import Vision

//MARK: Protocol
protocol VideoOutputModelProtocol: NSObject {
    var delegate: VideoOutputModelDelegate? { get set }
    
    var currentTorchMode: AVCaptureDevice.TorchMode { get set }
    var isTorchSupported: Bool { get }
    
    var possibleAudioInputs: [AVCaptureDevice] { get }
    var possibleVideoInputs: [AVCaptureDevice] { get }
    
    func setup()
    func setup(audioDevice: AVCaptureDevice?, videoDevice: AVCaptureDevice,
               videoQuality: AVCaptureSession.Preset)
    
    func changeAudioInput(_ audioInput: AVCaptureDevice)
    func changeVideoInput(_ videoInput: AVCaptureDevice)
    
    func switchCamera()
}

//MARK:- Delegate
protocol VideoOutputModelDelegate: NSObject {
    func capturedMovieOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                             from connection: AVCaptureConnection)
    
    func capturedAudioOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                             from connection: AVCaptureConnection)
    func switchedCamera(to position: AVCaptureDevice.Position)
}

//MARK:-
class VideoOutputModel: NSObject {
    //MARK: Properties
    //Internal
    public weak var delegate: VideoOutputModelDelegate?
    
    fileprivate let captureSession = AVCaptureSession()
    fileprivate lazy var videoOutput = AVCaptureVideoDataOutput()
    fileprivate lazy var audioOutput = AVCaptureAudioDataOutput()
    fileprivate var activeInput: AVCaptureDeviceInput!
    fileprivate var activeAudioInput: AVCaptureDeviceInput?
        
    //MARK: Initialization
    private func setupSession(audioDevice: AVCaptureDevice?,
                              videoDevice: AVCaptureDevice,
                              videoQuality: AVCaptureSession.Preset) -> Bool {
        captureSession.sessionPreset = videoQuality
        
        // Video input
        var success = setupVideo(videoDevice)
        
        // Audio input
        success = setupAudio(audioDevice)
        
        // Video output
        setupVideoOutput()
        
        // Audio output
        setupAudioOutput()
        
        return success
    }
    
    private func setupVideo(_ videoDevice: AVCaptureDevice) -> Bool {
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
            return true
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }
    }
    
    private func setupAudio(_ audioDevice: AVCaptureDevice?) -> Bool {
        guard let microphone = audioDevice else {
            print("Audio mutted")
            return true
        }
        
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone)
            
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
                activeAudioInput = micInput
            }
            return true
        } catch {
            print("Error setting device audio input: \(error)")
            return false
        }
    }
    
    private func setupVideoOutput() {
        if captureSession.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue:
                DispatchQueue(label: "videoQueue"))
            captureSession.addOutput(videoOutput)
        }
    }
    
    fileprivate func setupAudioOutput() {
        //Define your audio output
        if captureSession.canAddOutput(audioOutput) {
            audioOutput.setSampleBufferDelegate(self, queue:
                DispatchQueue(label: "audioQueue"))
            captureSession.addOutput(audioOutput)
        }
    }
}

//MARK:- Camera Session
extension VideoOutputModel {
    private func startSession() {
        if !captureSession.isRunning {
            videoQueue().async {
                self.captureSession.startRunning()
            }
        }
    }
    
    private func stopSession() {
        if captureSession.isRunning {
            videoQueue().async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .landscapeRight:
            orientation = .landscapeLeft
        case .landscapeLeft:
            orientation = .landscapeRight
        case .portrait:
            orientation = .portrait
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        default:
            orientation = .portrait //Make `.portrait` as default (should check will `.faceUp` and `.faceDown`)
        }
        
        return orientation
    }
    
    private func cameraWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        for device in deviceDescoverySession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
}

//MARK:- AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
extension VideoOutputModel: AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if output == videoOutput {
            connection.videoOrientation = currentVideoOrientation()
        }
        
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        
        if output == videoOutput {
            delegate?.capturedMovieOutput(output, didOutput: sampleBuffer, from: connection)
        } else if output == audioOutput {
            delegate?.capturedAudioOutput(output, didOutput: sampleBuffer, from: connection)
        }
    }
}

//MARK:- Internal torch
extension VideoOutputModel {
    private func internalToggleTorch(to mode: AVCaptureDevice.TorchMode) {
        let device = activeInput.device
        
        guard device.isTorchAvailable else {
            return
        }
        
        guard device.torchMode != mode else {
            return
        }
        
        setTorchMode(mode)
    }
    
    private func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        let device = activeInput.device
        
        if device.isTorchModeSupported(torchMode) && device.torchMode != torchMode {
            do {
                try device.lockForConfiguration()
                device.torchMode = torchMode
                device.unlockForConfiguration()
            }
            catch {
                print("Error:-\(error)")
            }
        }
    }
}

//MARK:- VideoRecorderModelProtocol
extension VideoOutputModel: VideoOutputModelProtocol{
    var currentTorchMode: AVCaptureDevice.TorchMode {
        get {
            let device = activeInput.device
            return device.torchMode
        }
        set(newTorchMode) {
            setTorchMode(newTorchMode)
        }
    }
    
    var isTorchSupported: Bool {
        let device = activeInput.device
        return device.isTorchAvailable
    }
    
    func changeAudioInput(_ audioInput: AVCaptureDevice) {
        
    }
    
    func changeVideoInput(_ videoInput: AVCaptureDevice) {
        
    }
    
    var possibleAudioInputs: [AVCaptureDevice] {
        let deviceDiscovery = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified)
        return deviceDiscovery.devices
    }
    
    var possibleVideoInputs: [AVCaptureDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInDualCamera, .builtInTelephotoCamera, .builtInTrueDepthCamera, .builtInWideAngleCamera]
        let deviceDiscovery = AVCaptureDevice.DiscoverySession.init(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        return deviceDiscovery.devices
    }
    
    func setup() {
        setup(audioDevice: AVCaptureDevice.default(for: AVMediaType.audio)!,
              videoDevice: AVCaptureDevice.default(for: AVMediaType.video)!,
              videoQuality: .high)
    }
    
    func setup(audioDevice: AVCaptureDevice?,
               videoDevice: AVCaptureDevice,
               videoQuality: AVCaptureSession.Preset) {
        let setupSuccessful = setupSession(audioDevice: audioDevice,
                                           videoDevice: videoDevice, videoQuality: videoQuality)
        
        guard setupSuccessful else {
            print("Error setting up video capture")
            assert(false)
            return
        }
        
        startSession()
    }
    
    func switchCamera() {
        captureSession.removeInput(activeInput)
        
        var possibleNewCamera = self.cameraWithPosition(.back)
        if activeInput.device.position == .back || activeInput.device.position == .unspecified {
            possibleNewCamera = self.cameraWithPosition(.front)
        }
        
        guard let newCamera = possibleNewCamera else {
            print("Error: Could not switch camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: newCamera)
            self.captureSession.addInput(input)
            self.activeInput = input
            delegate?.switchedCamera(to: newCamera.position)
        } catch {
            print("Switching camera error: \(error)")
        }
    }
}
