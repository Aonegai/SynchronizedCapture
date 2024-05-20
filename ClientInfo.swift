//
//  ClientInfo.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/17.
//

import Foundation
import SwiftCollections

struct ClientInfo :Identifiable {
    let id: UUID = UUID()
    let name: String
    let address: String
    var offset: Int64
    var syncAccuracy: Int64
    var aligned = false
    var cyclenum = 0
    var lastHeartbeat: Int64
    var captureRequests: Deque<Double> = Deque()

    static func create(name: String, address: String, offset: Int64, syncAccuracy: Int64, lastHeartbeat: Int64) -> ClientInfo {
        return ClientInfo(name: name, address: address, offset: offset, syncAccuracy: syncAccuracy, lastHeartbeat: lastHeartbeat)
    }

    static func create(name: String, address: String) -> ClientInfo {
        return ClientInfo(name: name, address: address, offset: 0, syncAccuracy: 0, lastHeartbeat: 0)
    }
}
