//
//  SyncConstants.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/17.
//

import Foundation
import QuartzCore

enum SyncConstants{
    static let sntpPort : Int = 33989
    static let sntpPort2 : Int = 33989
    static let broadcastMask : Int32 = 0x000000FF
    static let ReqMagicNum: Int32 = 114514
    static let AckmagicNum: Int32 = 1919810
    static let sntpCycleNum: Int = 200
    static let minLatency: Int64 = 1000_000 //ns
    static let cameraFramerate: Int32 = 24
}

func todata<T>(from value: T) -> [UInt8] {
    var mutableValue = value
    let data = withUnsafeBytes(of: &mutableValue) { Data($0) }
    return [UInt8](data)
}

func tovalue<T>(from bytes: [UInt8], at offset: Int = 0) -> T{
//    guard bytes.count >= offset + MemoryLayout<T>.size else {
//        return nil// 确保有足够的数据进行反序列化
//    }

    return bytes[offset..<(offset + MemoryLayout<T>.size)].withUnsafeBytes {
        $0.load(as: T.self)
    }
}

func toData<T>(from value: T) -> Data {
    var mutableValue = value
    return withUnsafeBytes(of: &mutableValue) { Data($0) }
}

func toValue<T>(from data: Data, at offset: Int = 0) -> T {
    return data[offset..<(offset + MemoryLayout<T>.size)].withUnsafeBytes {
        $0.load(as: T.self)
    }
}

func ipToInt32(ipString: String) -> Int32? {
    let parts = ipString.split(separator: ".")
    guard parts.count == 4 else { return nil }
    
    var ipInt: Int32 = 0
    for part in parts {
        guard let byte = UInt8(part) else { return nil }
        ipInt = ipInt << 8
        ipInt |= Int32(byte)
    }
    
    return ipInt
}

func int32ToIp(ipInt: Int32) -> String {
    let bytes = [
        (ipInt >> 24) & 0xFF,
        (ipInt >> 16) & 0xFF,
        (ipInt >> 8) & 0xFF,
        ipInt & 0xFF
    ]
    return bytes.map { String($0) }.joined(separator: ".")
}

func getTimeStamp()->Int64{
    return Int64(CACurrentMediaTime()*1000_000_000)
}
