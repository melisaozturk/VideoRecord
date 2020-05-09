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
    
//    private var videoDevice: AVCaptureDevice? //= AVCaptureInput(displayID: 69731840) //AVCaptureDevice.default(for: AVMediaType.video)!
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
    
}



extension AssetWriterController {
    
    
    func setup() {
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
        
//        self.deviceInput = try? AVCaptureDeviceInput(device: self.videoDevice!)
//        self.deviceInput = AVCaptureInput(displayID: 724042646)
//        self.deviceInput!.minFrameDuration = CMTimeMake(1, Int32(30))
//        self.deviceInput!.capturesCursor = true
//        self.deviceInput!.capturesMouseClicks = true
        
//        if self.session.canAddInput(self.deviceInput!) {
//            self.session.addInput(self.deviceInput!)
//        }
        
        self.session.startRunning()
        
        DispatchQueue.main.async {
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
    }
    
    func displayPreview(on view: UIView) {
        
        if !session.isRunning {print(CameraControllerError.captureSessionIsMissing) }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer!.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer!.frame = view.frame
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        
        //importent line of code what will did a trick
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
//        let rootLayer = view.layer
//        rootLayer.masksToBounds = true
//        self.previewLayer?.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
//        rootLayer.insertSublayer(self.previewLayer!, at: 0)
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
                    print("Error writing video buffer");
                }
            }
        }
    }
}


extension AssetWriterController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
}
