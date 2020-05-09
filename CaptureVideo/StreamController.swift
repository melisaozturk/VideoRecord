//
//  StreamController.swift
//  CaptureVideo
//
//  Created by melisa öztürk on 9.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import AVFoundation
import UIKit

class StreamController: NSObject {
    
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
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice? //to represent the actual iOS device’s cameras
    var rearCamera: AVCaptureDevice?
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?

    var movieOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    
    var photoCaptureCompletionBlock: ((Data?, Error?) -> Void)?

}



extension StreamController {
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
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
            
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
                
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.noCamerasAvailable }
        }
        func configureVideoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            let recordingDelegate:AVCaptureFileOutputRecordingDelegate? = self

            if captureSession.canAddOutput(self.movieOutput) {
                captureSession.addOutput(self.movieOutput)
            }
            let filePath = NSURL(fileURLWithPath: "filePath")
            
            movieOutput.startRecording(to: filePath as URL, recordingDelegate: recordingDelegate!)
            #if DEBUG
            print("RECORDING ..")
            #endif
        }
            DispatchQueue(label: "prepare").async {
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
        
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }

//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
//        previewLayer.connection!.videoOrientation = .portrait
//        view.layer.addSublayer(previewLayer)
//
//        previewLayer.position = CGPoint(x: view.frame.width / 2, y: view.frame.height / 2)
//        previewLayer.bounds = view.frame
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer.connection?.videoOrientation = .portrait

        view.layer.insertSublayer(self.previewLayer, at: 0)
        self.previewLayer.frame = view.frame
    }
    
    func switchCameras() throws {
        //5
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
         
        //6
        captureSession.beginConfiguration()
         
        func switchToFrontCamera() throws {
             guard case let inputs = captureSession.inputs, let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
                   let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
               self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
               captureSession.removeInput(rearCameraInput)
            
               if captureSession.canAddInput(self.frontCameraInput!) {
                   captureSession.addInput(self.frontCameraInput!)
            
                   self.currentCameraPosition = .front
               }
            
               else { throw CameraControllerError.invalidOperation }
        }
        func switchToRearCamera() throws {

               guard case let inputs = captureSession.inputs, let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
                   let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
               self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
               captureSession.removeInput(frontCameraInput)
            
               if captureSession.canAddInput(self.rearCameraInput!) {
                   captureSession.addInput(self.rearCameraInput!)
            
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
        captureSession.commitConfiguration()
    }
    
    func stopRecording() {
        movieOutput.stopRecording()
        #if DEBUG
        print("STOPPED ..")
        #endif
    }
    
}

extension StreamController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("error occured : \(error.localizedDescription)")
        } else {
            //        TODO: Send video file from UDP

                UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
            #if DEBUG
            print("SAVED ..")
            #endif
        }
    }
    
}
