import SwiftUI
import Network
import Foundation
import Combine
struct ContentView: View {
    var body: some View {
        NavigationView{
            VStack {
                NavigationLink(destination: LeaderView()) {
                                    Label("Leader",systemImage: "")
                                        .font(.title)
                                        .padding(2)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                }
                NavigationLink(destination: ClientView()) {
                                    Label("Client",systemImage: "")
                                        .font(.title)
                                        .padding(2)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                }
            }
        }
    }
    
    // Leader视图
    struct LeaderView: View {
        @StateObject private var leader = Leader()
        var body: some View {
            //NavigationView{
                VStack {
                    HStack{
                        Spacer()
                        NavigationLink(destination: CameraSettingView(isoValue: $leader.cameraManager.iso,exposureTime: $leader .cameraManager.exposureTime)) {
                            Label("相机设置", systemImage: "gear")
                                .font(.title3)
                                .padding(2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                        }
                    }
                    Text("本机IP地址:"+leader.addressString)
                        .onAppear {
                            leader.initialize()
                        }
                    Text("本机子网掩码:"+leader.netmaskString)
                    Text(leader.sendState)
                    Text(leader.cameraManager.alignState ? "已对齐":"未对齐")
                    Text("相位偏差："+String(leader.cameraManager.phaseDifference))
                    Button("启动") {
                        DispatchQueue.global(qos:.default).async {
                            leader.startBroadcasting()
                        }
                    }.padding(2)
                    Button("时钟同步"){
                        leader.doSync()
                    }.padding(2)
                    Button("相位对齐"){
                        leader.doAlign()
                    }.padding(2)
                    HStack {
                        Button("捕获"){
                            let captureTime = CACurrentMediaTime()
                            leader.setCaptureRequest(captureRequest: captureTime)
                        }.padding(2)
                        //Spacer() // 推动到右边
                        ZStack {
                            // 指示灯背景，灰色
                            Circle()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                            
                            // 动态改变颜色的指示灯
                            Circle()
                                .frame(width: 40, height: 40)
                                .foregroundColor((leader.alignNum == leader.clientNum)&&leader.cameraManager.alignState ? .green : .red)
                        } // 右上角的间距
                    }
                    
//                    CameraSettingView(isoValue: $leader.cameraManager.iso,exposureTime: $leader .cameraManager.exposureTime)
                    //Text(String(leader.cycleNum))
                    ForEach(leader.clientMap.keys.sorted(),id: \.self){key in
                        if let info = leader.clientMap[key]{
                            Text("Client"+info.name+" "+info.address)
                            Text("Handshake num:"+String(info.cyclenum))
                            Text("Offset:"+String(info.offset)+" us ")
                            Text(" SyncAccuracy:"+String(info.syncAccuracy)+" us")
                            Text(info.aligned ? "已对齐":"未对齐")
                            
                        }
                    }
                    Spacer()
                }.padding(2)
            //}
        }
        
    }

    // Client视图
    struct ClientView: View {
        @StateObject private var client = Client()
        @State private var receivedMessage: String = "等待消息..."
        var body: some View {
            VStack {
                Text("本机IP地址:"+client.addressString)
                    .padding()
                    .onAppear {
                        client.initialize()
                    }
                Text(client.syncState).padding()
                Text(client.cameraManager.alignState ? "已对齐":"未对齐")
                Text("相位偏差："+String(client.cameraManager.phaseDifference))
                Button("启动") {
                    client.run()
                }.padding()
//                if (client.cameraManager.hasCaptureResult){
//                    ImageViewRepresentable(sampleBuffer: client.cameraManager.captureResult)
//                                    .frame(width: 300, height: 300)
//                }
                CameraSettingView(isoValue: $client.cameraManager.iso,exposureTime: $client.cameraManager.exposureTime)
            }.padding()
        }
    }
}

struct CameraSettingView : View{
    let isoRange: ClosedRange<Double> = 25...800
    let exposureTimeRange: ClosedRange<Double> = 1...20
    @Binding var isoValue: Double
    @Binding var exposureTime: Double
    var body: some View{
        Text("ISO: \(Int(isoValue))")
                    
                    // 创建一个滑块用于调整ISO值
        
        Slider(value: $isoValue, in: isoRange, step: 25) {
                        Text("ISO")
                    } minimumValueLabel: {
                        Text("\(Int(25))")
                    } maximumValueLabel: {
                        Text("\(Int(800))")
                    }
                    .padding()
        Text("exposureTime: \(Int(exposureTime))"+"ms")
                    
                    // 创建一个滑块用于调整ISO值
        
        Slider(value: $exposureTime, in: exposureTimeRange, step: 1) {
                        Text("ISO")
                    } minimumValueLabel: {
                        Text("\(Int(1))")
                    } maximumValueLabel: {
                        Text("\(Int(20))")
                    }
                    .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
