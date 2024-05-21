//
//  ImageView.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/20.
//

import SwiftUI
import UIKit
import AVFoundation
import Photos

func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus()
    switch status {
    case .authorized:
        completion(true)
    case .notDetermined:
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    default:
        completion(false)
    }
}

func saveSampleBufferToPhotoAlbum(sampleBuffer: CMSampleBuffer) {
    // 首先，将CMSampleBuffer转换为UIImage
    guard let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else {
        print("Image conversion failed.")
        return
    }

    // 请求保存图片到相册
    PHPhotoLibrary.shared().performChanges {
        // 创建一个图片资产的请求
        PHAssetChangeRequest.creationRequestForAsset(from: image)
    } completionHandler: { success, error in
        if let error = error {
            print("Error saving image to photo album: \(error)")
        } else {
            print("Successfully saved image to photo album.")
        }
    }
}

struct ImageViewRepresentable: UIViewRepresentable {
    var sampleBuffer: CMSampleBuffer?

    func makeUIView(context: Context) -> UIImageView {
        // 创建UIImageView用于显示图像
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // 也可以根据具体需求调整
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // 每当视图需要更新时，根据sampleBuffer渲染图像
        if let buffer = sampleBuffer, let image = imageFromSampleBuffer(sampleBuffer: buffer) {
            uiView.image = image
        }
    }
}

func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
    // 从样本缓冲区获取图像缓冲区
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        return nil
    }

    // 锁定基地址
    CVPixelBufferLockBaseAddress(imageBuffer, [])
    
    // 获取图像信息
    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    
    // 创建颜色空间
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // 根据图像缓冲区信息创建图形上下文
    guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
        return nil
    }
    
    // 通过图形上下文创建CGImage
    guard let cgImage = context.makeImage() else {
        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
        return nil
    }

    // 解锁基地址
    CVPixelBufferUnlockBaseAddress(imageBuffer, [])

    // 通过CGImage创建UIImage
    let image = UIImage(cgImage: cgImage)
    return image
}
