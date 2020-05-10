//
//  AssetWriterController.swift
//  CaptureVideo
//
//  Created by melisa öztürk on 10.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import AVFoundation
import UIKit
import Photos

class AssetWriterController: NSObject {
    
    // error types to manage the various errors we might encounter while creating a capture session
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
    
    
    private var session: AVCaptureSession = AVCaptureSession()
    private var deviceInput: AVCaptureInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    private var audioOutput: AVCaptureAudioDataOutput = AVCaptureAudioDataOutput()
    
    private var audioConnection: AVCaptureConnection?
    private var videoConnection: AVCaptureConnection?
    
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var videoInput: AVAssetWriterInput?
    
    private var fileManager: FileManager = FileManager()
    private var recordingURL: URL?
    
    private var isCameraRecording: Bool = false
    private var isRecordingSessionStarted: Bool = false
    
    private var recordingQueue = DispatchQueue(label: "recording.queue")
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var frontCamera: AVCaptureDevice? //to represent the actual iOS device’s cameras
    var rearCamera: AVCaptureDevice?
}



extension AssetWriterController {
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        
        func createCaptureSession() {
            self.session = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            guard case let cameras = (session.devices.compactMap { $0 }), !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        func configureDeviceInputs() throws {
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if session.canAddInput(self.rearCameraInput!) { session.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
                
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if session.canAddInput(self.frontCameraInput!) { session.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.noCamerasAvailable }
        }
        
        func configureVideoOutput() throws {
            self.session.sessionPreset = AVCaptureSession.Preset.high
            
            self.recordingURL = URL(fileURLWithPath: "\(NSTemporaryDirectory() as String)/file.mp4")
            if self.fileManager.isDeletableFile(atPath: self.recordingURL!.path) {
                _ = try? self.fileManager.removeItem(atPath: self.recordingURL!.path)
            }
            
            self.assetWriter = try? AVAssetWriter(outputURL: self.recordingURL!,
                                                  fileType: AVFileType.mp4)
            self.assetWriter!.movieFragmentInterval = CMTime.invalid
            self.assetWriter!.shouldOptimizeForNetworkUse = true
            
            let audioSettings = [
                AVFormatIDKey : kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey : 2,
                AVSampleRateKey : 44100.0,
                AVEncoderBitRateKey: 192000
                ] as [String : Any]
            
            let videoSettings = [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 1920,
                AVVideoHeightKey : 1080
                /*AVVideoCompressionPropertiesKey: [
                 AVVideoAverageBitRateKey:  NSNumber(value: 5000000)
                 ]*/
                ] as [String : Any]
            
            self.videoInput = AVAssetWriterInput(mediaType: AVMediaType.video,
                                                 outputSettings: videoSettings)
            self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio,
                                                 outputSettings: audioSettings)
            
            self.videoInput?.expectsMediaDataInRealTime = true
            self.audioInput?.expectsMediaDataInRealTime = true
            
            if self.assetWriter!.canAdd(self.videoInput!) {
                self.assetWriter?.add(self.videoInput!)
            }
            
            if self.assetWriter!.canAdd(self.audioInput!) {
                self.assetWriter?.add(self.audioInput!)
            }
            
            self.session.startRunning()
            
            self.session.beginConfiguration()
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            self.videoConnection = self.videoOutput.connection(with: AVMediaType.video)
            /*if self.videoConnection?.isVideoStabilizationSupported == true {
             self.videoConnection?.preferredVideoStabilizationMode = .auto
             }*/
            self.session.commitConfiguration()
            
            let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
            let audioIn = try? AVCaptureDeviceInput(device: audioDevice!)
            
            if self.session.canAddInput(audioIn!) {
                self.session.addInput(audioIn!)
            }
            
            if self.session.canAddOutput(self.audioOutput) {
                self.session.addOutput(self.audioOutput)
            }
            
            self.audioConnection = self.audioOutput.connection(with: AVMediaType.audio)
        }
        DispatchQueue.main.async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configureVideoOutput()
            }
                
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    func displayPreview(on view: UIView) {
        
        if !session.isRunning {print(CameraControllerError.captureSessionIsMissing) }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer!.connection?.videoOrientation = .portrait
        
        let rootLayer = view.layer
        rootLayer.masksToBounds = true
        rootLayer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)

    }
    
    
    func startRecording(view: UIView) {
        
        if self.assetWriter?.startWriting() != true {
            print("error: \(self.assetWriter?.error.debugDescription ?? "")")
        }
        
        self.videoOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        self.audioOutput.setSampleBufferDelegate(self, queue: self.recordingQueue)
        displayPreview(on: view)
    }
    
    func stopRecording() {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
        
        self.assetWriter?.finishWriting {
            print("Saved in folder \(self.recordingURL!)")
            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.recordingURL!)
            }
            //            exit(0)
        }
    }
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput
        sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if !self.isRecordingSessionStarted {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.assetWriter?.startSession(atSourceTime: presentationTime)
            self.isRecordingSessionStarted = true
        }
        
        let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
        
        if CMFormatDescriptionGetMediaType(description) == kCMMediaType_Audio {
            if self.audioInput!.isReadyForMoreMediaData {
                //print("appendSampleBuffer audio");
                self.audioInput?.append(sampleBuffer)
            }
        } else {
            if self.videoInput!.isReadyForMoreMediaData {
                //print("appendSampleBuffer video");
                if !self.videoInput!.append(sampleBuffer) {
                    print("Error writing video buffer")
                }
            }
        }
    }
    
    func switchCameras() throws {
        //5
        guard let currentCameraPosition = currentCameraPosition, session.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        //6
        session.beginConfiguration()
        
        func switchToFrontCamera() throws {
            guard case let inputs = session.inputs, let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            session.removeInput(rearCameraInput)
            
            if session.canAddInput(self.frontCameraInput!) {
                session.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.invalidOperation }
        }
        func switchToRearCamera() throws {
            
            guard case let inputs = session.inputs, let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            session.removeInput(frontCameraInput)
            
            if session.canAddInput(self.rearCameraInput!) {
                session.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            }
                
            else { throw CameraControllerError.invalidOperation }
        }
        
        //7
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        //8:  commits, or saves, our capture session after configuring it.
        session.commitConfiguration()
    }
}


extension AssetWriterController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
}
