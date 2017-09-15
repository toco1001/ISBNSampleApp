//
//  ViewController.swift
//  ISBNSampleApp
//
//  Created by toco on 15/09/17.
//  Copyright © 2017 tocozakura. All rights reserved.
//

import UIKit
import AVFoundation

final class ViewController: UIViewController, UIGestureRecognizerDelegate {
  
  @IBOutlet weak var captureView: UIView?
  @IBOutlet weak var resultTextLabel: UILabel!
  @IBOutlet weak var targetView: UIView!
  
  fileprivate lazy var captureSession: AVCaptureSession = AVCaptureSession()
  fileprivate lazy var captureDevice: AVCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
  fileprivate lazy var capturePreviewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    return layer!
  }()
  
  fileprivate var captureInput: AVCaptureDeviceInput? = nil
  fileprivate lazy var captureOutput: AVCaptureMetadataOutput = {
    let output = AVCaptureMetadataOutput()
    output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    return output
  }()
  
  var imageView:UIImageView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.tappedScreen(gestureRecognizer:)))
    tapGesture.delegate = self
    self.view.addGestureRecognizer(tapGesture)
    
    setupDisplay()
    
    setupBarcodeCapture()
  }
  
  func setupDisplay(){
    let screenWidth = UIScreen.main.bounds.size.width;
    let screenHeight = UIScreen.main.bounds.size.height;
    if let iv = imageView {
      iv.removeFromSuperview()
    }
    imageView = UIImageView()
    imageView.frame = CGRect(x: 0.0, y: 0.0, width: screenWidth, height: screenHeight)
    view.addSubview(imageView)
    view.sendSubview(toBack: imageView)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    capturePreviewLayer.frame = self.captureView?.bounds ?? CGRect.zero
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  let focusView = UIView()
  func tappedScreen(gestureRecognizer: UITapGestureRecognizer) {
    let tapCGPoint = gestureRecognizer.location(ofTouch: 0, in: gestureRecognizer.view)
    focusView.frame.size = CGSize(width: 120, height: 120)
    focusView.center = tapCGPoint
    focusView.backgroundColor = UIColor.white.withAlphaComponent(0)
    focusView.layer.borderColor = UIColor.white.cgColor
    focusView.layer.borderWidth = 2
    focusView.alpha = 1
    imageView.addSubview(focusView)
    
    UIView.animate(withDuration: 0.5, animations: {
      self.focusView.frame.size = CGSize(width: 80, height: 80)
      self.focusView.center = tapCGPoint
    }, completion: { Void in
      UIView.animate(withDuration: 0.5, animations: {
        self.focusView.alpha = 0
      })
    })
    
    self.focusWithMode(focusMode: AVCaptureFocusMode.autoFocus, exposeWithMode: AVCaptureExposureMode.autoExpose, atDevicePoint: tapCGPoint, motiorSubjectAreaChange: true)
  }
  
  func focusWithMode(focusMode : AVCaptureFocusMode, exposeWithMode expusureMode :AVCaptureExposureMode, atDevicePoint point:CGPoint, motiorSubjectAreaChange monitorSubjectAreaChange:Bool) {
    
    let queue = DispatchQueue(label: "session queue")
    queue.async {
      let device : AVCaptureDevice = self.captureDevice
      
      do {
        try device.lockForConfiguration()
        if(device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode)){
          device.focusPointOfInterest = point
          device.focusMode = focusMode
        }
        if(device.isExposurePointOfInterestSupported && device.isExposureModeSupported(expusureMode)){
          device.exposurePointOfInterest = point
          device.exposureMode = expusureMode
        }
        
        device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
        device.unlockForConfiguration()
        
      } catch let error as NSError {
        print(error.debugDescription)
      }
    }
  }
  
  // MARK: - private
  private func setupBarcodeCapture() {
    do {
      captureInput = try AVCaptureDeviceInput(device: captureDevice)
      captureSession.addInput(captureInput)
      captureSession.addOutput(captureOutput)
      captureOutput.metadataObjectTypes = captureOutput.availableMetadataObjectTypes
      capturePreviewLayer.frame = CGRect(x: 0, y: 100, width: 240, height: 100)
      capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
      captureView?.layer.addSublayer(capturePreviewLayer)
      captureSession.startRunning()
    } catch let error as NSError {
      print(error)
    }
  }
  
  fileprivate func convartISBN(value: String) -> String? {
    let v = NSString(string: value).longLongValue
    let prefix: Int64 = Int64(v / 10000000000)
    guard prefix == 978 || prefix == 979 else {
      return nil
    }
    let isbn9: Int64 = (v % 10000000000) / 10
    var sum: Int64 = 0
    var tmpISBN = isbn9
    /*
     for var i = 10; i > 0 && tmpISBN > 0; i -= 1 {
     let divisor: Int64 = Int64(pow(10, Double(i - 2)))
     sum += (tmpISBN / divisor) * Int64(i)
     tmpISBN %= divisor
     }
     */
    
    var i = 10
    while i > 0 && tmpISBN > 0 {
      let divisor: Int64 = Int64(pow(10, Double(i - 2)))
      sum += (tmpISBN / divisor) * Int64(i)
      tmpISBN %= divisor
      i -= 1
    }
    
    let checkdigit = 11 - (sum % 11)
    return String(format: "%lld%@", isbn9, (checkdigit == 10) ? "X" : String(format: "%lld", checkdigit % 11))
  }
}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
  
  func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
    self.captureSession.stopRunning()
    guard let objects = metadataObjects as? [AVMetadataObject] else { return }
    var detectionString: String? = nil
    let barcodeTypes = [AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeEAN13Code]
    for metadataObject in objects {
      loop: for type in barcodeTypes {
        guard metadataObject.type == type else { continue }
        guard self.capturePreviewLayer.transformedMetadataObject(for: metadataObject) is AVMetadataMachineReadableCodeObject else { continue }
        if let object = metadataObject as? AVMetadataMachineReadableCodeObject {
          detectionString = object.stringValue
          break loop
        }
      }
      var text = ""
      guard let value = detectionString else {
        continue
      }
      text += "\(value)"
      text += "\n"
      guard let isbn = convartISBN(value: value) else {
        continue
      }
      text += "ISBN:\t\(isbn)"
      resultTextLabel?.text = text
      print(text)
      /*
       
       */
//      let URLString = String(format: "http://amazon.co.jp/dp/%@", isbn)
//      guard let URL = NSURL(string: URLString) else { continue }
//      UIApplication.shared.openURL(URL as URL)
    }
    self.captureSession.startRunning()
  }
}
