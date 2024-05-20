//
//  SntpOffsetResponse.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/17.
//

import Foundation
/// Represents a response with the SNTP offset, synchronization accuracy, and status.
struct SntpOffsetResponse {
    let offset: Int64
    let syncAccuracy: Int64
    let status: Bool
    
    init(offset: Int64, syncAccuracy: Int64, status: Bool) {
        self.offset = offset
        self.syncAccuracy = syncAccuracy
        self.status = status
    }
}
