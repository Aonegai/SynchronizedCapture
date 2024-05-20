//
//  SntpBase.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/17.
//

import Foundation
import Combine

class SntpBase : ObservableObject{
    var ipaddress : Int32 = 0
    var netmask : Int32 = 0
    @Published var addressString = "未知IP地址"
    @Published var netmaskString = "未知子网掩码"
    @Published var sendState:String = "发送情况"//for debug
    @Published var recvState:String = "接收情况"
    @Published var cameraManager = CameraManager()
    private var cancellables: Set<AnyCancellable> = []
    init(ipaddress: String = "未知IP地址") {
    }
    
    open func initialize(){
        addressString = getWiFiIPAddress() ?? "获取IP地址失败"
        ipaddress = ipToInt32(ipString: addressString) ?? 0
        netmask = ipToInt32(ipString: netmaskString) ?? 0
        
        cameraManager.$alignState
                   .sink { [weak self] _ in
                       self?.objectWillChange.send()
                   }
                   .store(in: &cancellables)
        
//        cameraManager.$phaseDifference
//                   .sink { [weak self] _ in
//                       self?.objectWillChange.send()
//                   }
//                   .store(in: &cancellables)
    }
    
    
    
    private func getWiFiIPAddress() -> String?{
         var address: String?
         // 获取网络接口的列表
         var ifaddr: UnsafeMutablePointer<ifaddrs>?
         guard getifaddrs(&ifaddr) == 0 else { return nil }
         guard let firstAddr = ifaddr else { return nil }
         
         // 遍历链表
         for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
             let interface = ifptr.pointee
             // 检查接口是否是IPV4
             let addrFamily = interface.ifa_addr.pointee.sa_family
             if addrFamily == UInt8(AF_INET) {
                 
                 // 检查是不是wifi接口
                 let name = String(cString: interface.ifa_name)
                 if name == "en0" {
                     
                     // 转换地址与子网掩码为字符串
                     var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                     getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                 &hostname, socklen_t(hostname.count),
                                 nil, socklen_t(0), NI_NUMERICHOST)
                     address = String(cString: hostname)
                     var ipmask = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                     getnameinfo(interface.ifa_netmask, socklen_t(interface.ifa_netmask.pointee.sa_len),
                                 &ipmask, socklen_t(ipmask.count),
                                 nil, socklen_t(0), NI_NUMERICHOST)
                     self.netmaskString = String(cString: ipmask)
                 }
             }
         }
         freeifaddrs(ifaddr)
         
         return address
     }
}
