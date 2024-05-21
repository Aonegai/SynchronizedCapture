//
//  CameraController.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/19.
//

import Foundation
import AVFoundation
import SwiftCollections
import Combine

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,ObservableObject {
    var captureSession: AVCaptureSession?
    private let bufferQueue = DispatchQueue(label: "com.yourapp.bufferqueue")
    var standardTimestamp: Double? = Date().timeIntervalSince1970
    private var isCapturing = false
    @Published var alignState = false
    @Published var iterationNum = 0
    @Published var phaseDifference = 0.0
    @Published var hasCaptureResult = false
    @Published var captureResult:CMSampleBuffer? = nil
    @Published var exposureTime :Double = 10
    @Published var iso : Double = 200
    var captureRequests:[Double] = []
    var captureBuffer:Deque<CMSampleBuffer> = Deque()
    var streamCounter = 0
    var alignStartTimestamp:Double = 0
    var alignTimestamp:Double = 0
    func getCaptureResult(sample:CMSampleBuffer){
        self.hasCaptureResult = true
        captureResult = sample
        print("Capture Result Got")
        checkPhotoLibraryPermission { authorized in
            if authorized {
                saveSampleBufferToPhotoAlbum(sampleBuffer: sample)
            } else {
                print("Permission to access photo library was denied.")
            }
        }
    }
    
    func capture(requestTime:Double){
        captureRequests.append(requestTime)
    }
    
    func startSession() {
        streamCounter = 0
        iterationNum += 1
        // 配置并启动捕获会话
        captureSession = AVCaptureSession()
        //captureSession?.sessionPreset = AVCaptureSession.Preset.high
        
        guard let captureSession = captureSession, let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            captureSession.addInput(input)
        } catch {
            print("Error setting up the input device.")
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_32BGRA)]//may crash
        output.setSampleBufferDelegate(self, queue: bufferQueue)
        
        captureSession.addOutput(output)
        
        do{
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1,timescale: SyncConstants.cameraFramerate)
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1,timescale: SyncConstants.cameraFramerate)
            device.setExposureModeCustom(duration: CMTimeMake(value: Int64(exposureTime), timescale: 1000), iso: Float(iso))
            device.unlockForConfiguration()
        }catch{
            print("\(error)")
        }
        for a in device.activeFormat.videoSupportedFrameRateRanges{
            //print(String(a.minFrameRate)+" "+String(a.maxFrameRate))
        }
        captureSession.startRunning()
    }
    
    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    private func checkPhaseDifference(with timestamp: CMTime) {
        let framePeriod = CMTimeGetSeconds(CMTimeMake(value: 1, timescale: SyncConstants.cameraFramerate))
        let phaseDifference = minimalPhaseDifference(timeStamp: CMTimeGetSeconds(timestamp),standardTimestamp:standardTimestamp! ,period: framePeriod)
        //print(String(CMTimeGetSeconds(timestamp)))
        DispatchQueue.main.async {
            self.phaseDifference = phaseDifference
           }
        
        //print("当前帧相位差："+String(phaseDifference))
        // 若相位差超过1ms
        if(true){
            if phaseDifference > 0.001 {
                stopSession()
                if(self.alignState){
                    self.alignStartTimestamp = CMTimeGetSeconds(timestamp)
                    DispatchQueue.main.async {
                        self.alignState = false
                    }
                }

                // 随机睡眠一个0到1000ms的时间
                let sleepTime = UInt32.random(in: 0..<30000)
                usleep(sleepTime)
                
                startSession()
            }
            else{
                if(!self.alignState){
                    self.alignTimestamp = CMTimeGetSeconds(timestamp)
                    DispatchQueue.main.async {
                        self.alignState = true
                    }
                    print(alignTimestamp-alignStartTimestamp)
                }

            }
        }
    }
    
    func minimalPhaseDifference(timeStamp: Double, standardTimestamp: Double, period T: Double) -> Double {
        let deltaTime = timeStamp - standardTimestamp
        var phaseDifference = deltaTime.truncatingRemainder(dividingBy: T)
        if phaseDifference > T / 2 {
            phaseDifference = phaseDifference - T
        } else if phaseDifference < -T / 2 {
            phaseDifference = T + phaseDifference
        }
        return abs(phaseDifference)
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        // 计算相位偏差并根据需要重启会话
        streamCounter+=1
        if(streamCounter>2){
            checkPhaseDifference(with: timestamp)
        }
        if(captureBuffer.count>=10){
            dequeBuffer()
        }
        captureBuffer.append(sampleBuffer)
        //print("捕获缓冲区内容量："+String(captureBuffer.count))
    }
    
    func dequeBuffer(){
        let sampleBuffer = captureBuffer.removeFirst()
        if(!captureRequests.isEmpty){
            let requestTime:Double = captureRequests.first!
            print("deque "+String(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))))
            print("request:"+String(requestTime))
            if(abs(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))-requestTime)<=0.005){
                captureRequests.removeFirst()
                self.getCaptureResult(sample:sampleBuffer)
            }else if(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))>requestTime){
                captureRequests.removeFirst()
            }
        }
        
    }
}
