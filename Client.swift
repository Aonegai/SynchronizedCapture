//
//  Client.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/17.
//

import Foundation
import Socket

class Client : SntpBase {
    @Published var syncState:String = "同步状态:尚未开始同步"
    private var leaderIP: Int32 = 0
    private var leaderIPString : String = "unknown"
    private var udpSocket : Socket?
    init() {
    }
    
    override open func initialize(){
        super.initialize()
        do{
            udpSocket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            try udpSocket!.udpBroadcast(enable: true)
            try udpSocket!.setReadTimeout(value: 500)
        }catch{
            print("\(error)")
        }
    }

    func run() {
        self.syncState = "启动同步"
        do{
            try udpSocket!.listen(on: SyncConstants.sntpPort)
        }catch{
            print("\(error)")
        }
        DispatchQueue.global(qos: .default).async {
            while true {
                do{
                    let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                    if(bytesCount == 0){
                        continue
                    }
                    self.recvState = "收到"+String(remoteAddress?.ipAddressString() ?? "unknown")+"消息"
                        self.recvState = "收到sntp消息"
                        let recvNumber :Int32 = tovalue(from: data)
                        if recvNumber == 114514{
                            DispatchQueue.global(qos: .default).async {
                                
                                self.handleSntp (leaderIp: remoteAddress?.ipAddressString() ?? "unknown")
                            }
                            break
                        }
                }catch{
                    print("\(error)")
                }
                
            }
            //self.server?.close()

        }
    }
    
    func traceAlignState(){
        var currentAlignState = false
        while(true){
            if(cameraManager.alignState != currentAlignState){
                currentAlignState = cameraManager.alignState
                do{
                    try udpSocket!.write(from: toData(from: currentAlignState ? 1 as Int64 : 0 as Int64), to: Socket.createAddress(for: self.leaderIPString, on: SyncConstants.sntpPort)!)
                }catch{
                    print("send error")
                }
            }
        }
    }
    
    func handleCamera(){
        do{
            while(true){
                let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                if(bytesCount == 0){
                    continue
                }
                let stdTimeStamp:Double = tovalue(from:data)
                self.cameraManager.standardTimestamp = stdTimeStamp
                print("标准相位时间戳："+String(stdTimeStamp))
                DispatchQueue.global(qos:.default).async {
                    self.cameraManager.startSession()
                }
                DispatchQueue.global(qos:.default).async {
                    self.traceAlignState()
                }
                break
            }
        }catch{
            print("\(error)")
        }
        while(true){
            do{
                let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                if(bytesCount == 0){
                    continue
                }
                let requestTime = tovalue(from: data) as Double
                print("收到捕获请求"+String(requestTime))
                cameraManager.capture(requestTime: requestTime)
            }catch{
                print("\(error)")
            }
        }
        
    }
    
    func handleSntp(leaderIp:String){
        self.leaderIPString = leaderIp
        let sendAddress = Socket.createAddress(for: leaderIp, on: SyncConstants.sntpPort)!
        do{
            try self.udpSocket!.write(from: toData(from: 1919810), to: sendAddress)
        }catch{
            print("\(error)")
        }
        syncState = "同步状态:开始同步"
        while(true){
            do{
                let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                if(bytesCount == 0){
                    continue
                }
                let t1 : Int64 = getTimeStamp()
                let t0msg:Int64 = tovalue(from: data,at: 0)
                if(t0msg==0){
                    break
                }
                print("client recv sntp message")
                print(String(t0msg))
                var buffer :Data = toData(from: t0msg)+toData(from: t1)
                let t2 = getTimeStamp()
                buffer.append(contentsOf:toData(from: t2))
                try self.udpSocket!.write(from: buffer, to: sendAddress)
                print("client sent sntp message")
            }catch{
                print("\(error)")
            }
        }
        DispatchQueue.global(qos: .default).async {
            print("client synchronized")
            self.handleCamera()
        }
        
    }
}
