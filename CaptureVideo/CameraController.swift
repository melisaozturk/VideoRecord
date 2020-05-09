//
//  CameraController.swift
//  CaptureVideo
//
//  Created by melisa öztürk on 9.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import UIKit
import AVFoundation

class CameraController: NSObject {

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
    
    var photoOutput: AVCapturePhotoOutput? //to get the necessary data out of our capture session.
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var flashMode = AVCaptureDevice.FlashMode.off
    
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
}

extension CameraController {
//    to handle the creation and configuration of a new capture session
    func prepare(completionHandler: @escaping (Error?) -> Void) {
       // Creating a capture session
        func createCaptureSession() {
            self.captureSession = AVCaptureSession() //creates a new AVCaptureSession and stores it in the captureSession property
            
        }
//      to find the cameras available on the device. - Obtaining and configuring the necessary capture devices
        func configureCaptureDevices() throws {
            //1: find all of the wide angle cameras available on the current device and convert them into an array of non-optional AVCaptureDevice instances. If no cameras are available, we throw an error.
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            guard case let cameras = (session.devices.compactMap { $0 }), !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
             
            //2: the available cameras found in code segment 1 and determines which is the front camera and which is the rear camera. It additionally configures the rear camera to autofocus, throwing any errors that are encountered along the way.
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
//        Creating inputs using the capture devices - we can create capture device inputs, which take capture devices and connect them to our capture session - we found the available cameras on the device and configured them to meet our specifications.we will connect them to our capture session.
        func configureDeviceInputs() throws {
            //3: ensures that captureSession exists. If not, we throw an error.
               guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
               //4: if statements are responsible for creating the necessary capture device input to support photo capture. AVFoundation only allows one camera-based input per capture session at a time.
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
        
        //Configuring a photo output object to process captured images - It just configures photoOutput, telling it to use the JPEG file format for its video codec. Then, it adds photoOutput to captureSession. Finally, it starts captureSession.
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
         
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
         
            if captureSession.canAddOutput(self.photoOutput!) { captureSession.addOutput(self.photoOutput!) }
         
            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
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
//    to show what camera captures on screen. - responsible for creating a capture preview and displaying it on the provided view. -  creates an AVCaptureVideoPreview using captureSession, sets it to have the portrait orientation, and adds it to the provided view.
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
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
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
       guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
     
        let settings =  AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
     
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
  
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if let error = error {
            print("error occured : \(error.localizedDescription)")
        }

        if let dataImage = photo.fileDataRepresentation() {
            print(UIImage(data: dataImage)?.size as Any)

            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.right)

            /**
               save image in array / do whatever you want to do with the image here
            */
            self.photoCaptureCompletionBlock?(image, nil)

        } else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
    
//    public func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
//                        resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
//        if let error = error {
//            self.photoCaptureCompletionBlock?(nil, error)
//        }
//        else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
//            let image = UIImage(data: data) {
//
//            self.photoCaptureCompletionBlock?(image, nil)
//        }
//
//        else {
//            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
//        }
//    }
}

