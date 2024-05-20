//
//  Leader.swift
//  SynchronizedCapture
//
//  Created by mac on 2024/4/17.
//

import Foundation
import AVFoundation
import Socket

class Leader : SntpBase {
    private var udpSocket : Socket?
    @Published var clientMap: Dictionary<String,ClientInfo> = [:]
    @Published var cycleNum = 0
    @Published var alignNum = 0
    @Published var clientNum = 0
    let SocketLock = NSLock()
    var doingSync = false
    var doingAlign = false
    var hasCaptureRequest = false
    let alignCondition = NSCondition()
    let captureCondition = NSCondition()
    var captureRequest:Double = 0
    init() {
        
    }
    
    override open func initialize(){
        super.initialize()
//        broadcastClient = UDPClient(address: int32ToIp(ipInt: ipaddress|SyncConstants.broadcastMask),
//                                    port: SyncConstants.sntpPort)
        do{
            udpSocket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            print(udpSocket!.isConnected)
            try udpSocket!.setReadTimeout(value: 100)
            try udpSocket!.udpBroadcast(enable: true)
        }catch{
            print("\(error)")
        }
    }

    func startBroadcasting() {
        //DispatchQueue.global(qos: .default).async {
            do{
                let broadcastAddress:String = int32ToIp(ipInt: self.ipaddress&self.netmask + ~self.netmask)
                print(broadcastAddress)
                try self.udpSocket!.listen(on: SyncConstants.sntpPort)
                try self.udpSocket!.write(from: toData(from: 114514 as Int32), to: Socket.createAddress(for: broadcastAddress, on: SyncConstants.sntpPort)!)
                print("send successfully")
                self.sendState = "发送成功"
            }catch{
                print("\(error)")
            }
        //}
       
            
            while true {
                do{
                    if(doingSync){
                        break
                    }
                    let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                    if(bytesCount == 0){
                        continue
                    }
                    self.recvState = "收到sntp消息"
                    let recvNumber :Int32 = tovalue(from: data)
                    if recvNumber == 1919810{
                        print("get client")
                        clientNum += 1
                        self.clientMap[remoteAddress!.ipAddressString()] = ClientInfo.create(name: String(clientMap.count), address: remoteAddress!.ipAddressString())
                        self.sendState = "发送成功"
                    }
                }catch{
                    print("read timeout")
                    print("\(error)")
                }
            }
        print("stop broadcast")
    }
    
    func doSync(){
        doingSync = true
        sleep(1)
        for client in clientMap{
            DispatchQueue.global(qos:.default).async {
                self.handleOneClient(ip:client.value.address)
            }
        }
    }
    func doAlign(){
        self.cameraManager.standardTimestamp = CACurrentMediaTime()
        doingAlign = true
        alignCondition.broadcast()
        DispatchQueue.global(qos:.default).async {
            self.cameraManager.startSession()
        }
        DispatchQueue.global(qos:.default).async {
            self.recvAlignState()
        }
    }
    
    func recvAlignState(){
        while(true){
            do{
                let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                if(bytesCount == 0){
                    continue
                }
                if tovalue(from: data)==1 as Int64{
                    if(clientMap[remoteAddress!.ipAddressString()]?.aligned == false){
                        alignNum += 1
                        clientMap[remoteAddress!.ipAddressString()]?.aligned = true
                    }
                    print("client"+remoteAddress!.ipAddressString()+"已对齐")
                    print(alignNum)
                    print(clientNum)
                }else if tovalue(from: data)==0 as Int64{
                    if(clientMap[remoteAddress!.ipAddressString()]?.aligned == true){
                        alignNum -= 1
                        clientMap[remoteAddress!.ipAddressString()]?.aligned = false
                    }
                    print("client"+remoteAddress!.ipAddressString()+"失去对齐")
                    print(alignNum)
                    print(clientNum)
                }
            }catch{
                
            }
        }
    }

    func setCaptureRequest(captureRequest:Double){
        let realRequestTime = getRealRequestTime(captureRequest: captureRequest)
        for (key,value) in clientMap{
            clientMap[key]!.captureRequests.append(realRequestTime)
        }
        self.hasCaptureRequest=false
        self.cameraManager.capture(requestTime: realRequestTime)
        self.captureCondition.broadcast()
    }
    
    func getRealRequestTime(captureRequest:Double)->Double{
        let standardCapturePeriod = CMTimeGetSeconds(CMTimeMake(value: 1, timescale: SyncConstants.cameraFramerate))
        let n = ((captureRequest-cameraManager.standardTimestamp!)/standardCapturePeriod).rounded(.up)
        return cameraManager.standardTimestamp!+n*standardCapturePeriod
    }

    
    func handleOneClient(ip:String){
        
        let SntpResult = self.doSNTP(ip: ip)
        if(SntpResult.status){
            clientMap[ip]?.offset=SntpResult.offset
            clientMap[ip]?.syncAccuracy=SntpResult.syncAccuracy
        }
        print("waiting align condition")
        alignCondition.wait()
        alignCondition.unlock()
        print("get align condition")
        do{
            SocketLock.lock()
            try self.udpSocket?.write(from:toData(from:cameraManager.standardTimestamp!+Double(clientMap[ip]!.offset)/1000_000_000), to: Socket.createAddress(for: ip, on:SyncConstants.sntpPort)!)
            SocketLock.unlock()
        }catch{
            print("\(error)")
        }
        while(true){
            //captureCondition.wait()
            //captureCondition.unlock()
            if(!clientMap[ip]!.captureRequests.isEmpty){
                let realCaptureClientTime = clientMap[ip]!.captureRequests.removeFirst()+Double(clientMap[ip]!.offset)/1000_000_000
                do{
                    SocketLock.lock()
                    print(ip+" "+String(realCaptureClientTime))
                    try self.udpSocket?.write(from:toData(from:realCaptureClientTime), to: Socket.createAddress(for: ip, on:SyncConstants.sntpPort)!)
                    SocketLock.unlock()
                }catch{
                    print("\(error)")
                }
            }
            //captureCondition.unlock()
        }
        
    }
    
    func doSNTP(ip:String)->SntpOffsetResponse{

        //let sntpServer = UDPServer(address: ip, port: SyncConstants.sntpPort)
        var bestLatency = Int64.max // Start with initial high round trip
        var bestOffset : Int64 = 0
        let sendAddress = Socket.createAddress(for: ip, on:SyncConstants.sntpPort)!
        //for _ in 0...100{
            //bestLatency = Int64.max // Start with initial high round trip
            //bestOffset = 0
            for _ in 0...SyncConstants.sntpCycleNum{
                let t0 : Int64 = getTimeStamp()
                do{
                    try self.udpSocket?.write(from:toData(from:t0), to: sendAddress)
                }catch{
                    print("\(error)")
                }
                //print(String(t0))
                //ToDo:信号量阻塞与超时异常
                //while(true){
                do{
                    let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                    if(bytesCount == 0 || bytesCount == 48){
                        //print("empty datagram")
                        continue
                    }
                    //print("Leader recv done")
                    let t3 : Int64 = getTimeStamp()
                    //print(bytesCount)
                    let t0msg:Int64 = tovalue(from: data,at: 0)
                    //print("t0msg="+String(t0msg))
                    if(t0msg != t0){
                        //print("bad sequential !")
                        let (data, bytesCount, remoteAddress) = try self.udpSocket!.readDatagram()
                        continue
                    }
                    
                    let t1: Int64 = tovalue(from: data,at: 8)
                    let t2: Int64 = tovalue(from: data,at: 16)
                    let timeOffset = ((t1-t0)+(t2-t3))/2
                    let roundTripLatency = (t3-t0)-(t2-t1)
                    //print("offset is "+String(timeOffset)+" latency is "+String(roundTripLatency))
                    DispatchQueue.main.async {
                        //self.cycleNum+=1
                        self.clientMap[ip]?.cyclenum+=1
                    }
                    if (roundTripLatency < bestLatency) {
                        bestOffset = timeOffset;
                        bestLatency = roundTripLatency;
                        // If round trip latency is under minimum round trip latency desired, stop here.
                        //                    if (roundTripLatency < SyncConstants.minLatency) {
                        //                        break;
                        //                    }
                    }
                }catch{
                    print("\(error)")
                }
                // }
                
            }
            //print(bestOffset)
        //}
        do{
            try self.udpSocket?.write(from:toData(from:0 as Double), to: Socket.createAddress(for: ip, on:SyncConstants.sntpPort)!)
        }catch{
            print("\(error)")
        }
        return SntpOffsetResponse(offset: bestOffset, syncAccuracy: bestLatency, status: true)
    }
}
