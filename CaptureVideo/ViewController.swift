//
//  ViewController.swift
//  CaptureVideo
//
//  Created by melisa öztürk on 9.05.2020.
//  Copyright © 2020 melisa öztürk. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {
    
    @IBOutlet fileprivate var capturePreviewView: UIView!
    @IBOutlet weak var btnRecord: UIButton!
    @IBOutlet weak var btnStop: UIButton!
    @IBOutlet weak var lblStatus: UILabel!
    
    let assetWriterController = AssetWriterController()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureCameraController()
        styleCaptureButton()
        btnRecord.isEnabled = true
        btnStop.isEnabled = true
        lblStatus.text = ""
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func toggleFlash(_ sender: UIButton) {
    }
    
    @IBAction func switchCameras(_ sender: UIButton) {
        do {
            try assetWriterController.switchCameras()
        }
        catch {
            print(error)
        }
    }
    
    @IBAction func captureImage(_ sender: UIButton) {

        assetWriterController.startRecording(view: self.capturePreviewView)
        btnRecord.isEnabled = false
        lblStatus.text = "RECORDING.."
    }
    
    
    @IBAction func btnStop(_ sender: Any) {
        assetWriterController.stopRecording()
        btnStop.isEnabled = false
        lblStatus.text = "NOT RECORDING.. RESTART THE APP"
    }
    
    //     prepares our camera controller like we designed it to
    func configureCameraController() {
        assetWriterController.prepare {(error) in
            if let error = error {
                print(error)
            }
        }
        self.assetWriterController.displayPreview(on: self.capturePreviewView)
    }
    
    private func styleCaptureButton() {
        btnRecord.layer.borderColor = UIColor.black.cgColor
        btnRecord.layer.borderWidth = 2
        btnRecord.layer.cornerRadius = min(btnRecord.frame.width, btnRecord.frame.height) / 2
        
        btnStop.layer.borderColor = UIColor.black.cgColor
        btnStop.layer.borderWidth = 2
        btnStop.layer.cornerRadius = min(btnStop.frame.width, btnStop.frame.height) / 2
    }
    
}
