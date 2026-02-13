
import SwiftUI
import AVFoundation

@main
struct CameraLightApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isLightOn = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                Button(action: toggleFlash) {
                    ZStack {
                        Circle()
                            .fill(isLightOn ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                            .frame(width: 200, height: 200)
                        
                        Image(systemName: isLightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 100)
                            .foregroundColor(isLightOn ? .yellow : .white)
                            .shadow(color: isLightOn ? .orange : .clear, radius: 20)
                    }
                }
                
                Text(isLightOn ? "Light ON" : "Light OFF")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            print("Device does not have a torch/flash")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                isLightOn = false
            } else {
                try device.setTorchModeOn(level: 1.0) // Max brightness
                isLightOn = true
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
}
