
import SwiftUI
import AVFoundation
import Cocoa
import ApplicationServices
import CoreImage

@main
struct CameraLightMacApp: App {
    @StateObject private var appSelectionManager = AppSelectionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSelectionManager) // Inject into environment
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

// MARK: - Extensions

extension NSImage {
    var averageColor: Color {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .gray }
        
        let inputImage = CIImage(cgImage: cgImage)
        let extent = inputImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent]) else { return .gray }
        guard let outputImage = filter.outputImage else { return .gray }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return Color(red: Double(bitmap[0]) / 255.0, green: Double(bitmap[1]) / 255.0, blue: Double(bitmap[2]) / 255.0)
    }
}

// MARK: - Visual Effects

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow // Gives a nice dark/light blur depending on system theme
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.callback(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Models

struct WatchedApp: Identifiable, Codable, Hashable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let iconPath: String?
}

// MARK: - App Selection Manager

class AppSelectionManager: ObservableObject {
    @Published var watchedApps: [WatchedApp] = [] {
        didSet {
            saveApps()
            notificationWatcher?.updateWatchedApps(watchedApps)
        }
    }
    
    @Published var isMonitoring = false {
        didSet {
            if isMonitoring { 
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var activeAppIDs: Set<String> = [] {
        didSet {
           updateLight()
        }
    }
    
    @Published var showDebugLogs: Bool = true {
        didSet {
            UserDefaults.standard.set(showDebugLogs, forKey: "ShowDebugLogs")
        }
    }
    
    @Published var enableBlur: Bool = false {
        didSet {
            UserDefaults.standard.set(enableBlur, forKey: "EnableBlur")
        }
    }
    
    @Published var accessibilityPermissionGranted = false
    @Published var debugLog: String = "Waiting for notifications..."
    
    private var notificationWatcher: NotificationWatcher?
    private var workspaceObserver: NSObjectProtocol?
    
    init() {
        loadApps()
        // Load Settings
        showDebugLogs = UserDefaults.standard.object(forKey: "ShowDebugLogs") as? Bool ?? true
        enableBlur = UserDefaults.standard.object(forKey: "EnableBlur") as? Bool ?? false
        
        checkAccessibilityPermissions()
        
        // Setup Notification Watcher
        notificationWatcher = NotificationWatcher(
            watchedApps: watchedApps,
            onNotificationDetected: { [weak self] bundleID, name in
                DispatchQueue.main.async {
                    self?.handleNewNotification(bundleID: bundleID, name: name)
                }
            },
            logHandler: { [weak self] log in
                DispatchQueue.main.async {
                    self?.debugLog = "LOG: \(log)"
                }
            }
        )
        
        // Setup Workspace Observer for App Activation
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }
    
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - App Management
    
    func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let bundle = Bundle(url: url),
                   let bundleID = bundle.bundleIdentifier {
                    // Try to get a friendly name
                    let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                               bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                               url.deletingPathExtension().lastPathComponent
                    
                    let newApp = WatchedApp(name: name, bundleIdentifier: bundleID, iconPath: url.path)
                    
                    if !watchedApps.contains(where: { $0.bundleIdentifier == bundleID }) {
                        watchedApps.append(newApp)
                    }
                }
            }
        }
    }
    
    func removeApp(_ app: WatchedApp) {
        if let index = watchedApps.firstIndex(of: app) {
            watchedApps.remove(at: index)
        }
        activeAppIDs.remove(app.bundleIdentifier)
    }
    
    func toggleActiveState(for app: WatchedApp) {
        if activeAppIDs.contains(app.bundleIdentifier) {
            activeAppIDs.remove(app.bundleIdentifier)
        } else {
            // Manual toggle ON (for testing or manual reminder)
            activeAppIDs.insert(app.bundleIdentifier)
        }
    }
    
    // MARK: - Monitoring Logic
    
    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        accessibilityPermissionGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func startMonitoring() {
        checkAccessibilityPermissions()
        if !accessibilityPermissionGranted {
            isMonitoring = false
            return
        }
        notificationWatcher?.start()
    }
    
    private func stopMonitoring() {
        notificationWatcher?.stop()
        activeAppIDs.removeAll()
        updateLight()
    }
    
    private func handleNewNotification(bundleID: String, name: String) {
        // Find the app in our list that matches the name/ID
        if let app = watchedApps.first(where: { $0.bundleIdentifier == bundleID || $0.name == name }) {
             activeAppIDs.insert(app.bundleIdentifier)
             debugLog = "Active: \(app.name)"
        } else {
            // Fallback: search by name
            if let app = watchedApps.first(where: { name.localizedCaseInsensitiveContains($0.name) }) {
                activeAppIDs.insert(app.bundleIdentifier)
                debugLog = "Active (Match): \(app.name)"
            }
        }
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }
        
        if activeAppIDs.contains(bundleID) {
            activeAppIDs.remove(bundleID)
            debugLog = "Cleared: \(app.localizedName ?? bundleID)"
        }
    }
    
    private func updateLight() {
        if !activeAppIDs.isEmpty {
            CameraManager.shared.toggleCamera(forceOn: true)
        } else {
             CameraManager.shared.toggleCamera(forceOff: true)
        }
    }
    
    // MARK: - Persistence
    
    private func saveApps() {
        if let encoded = try? JSONEncoder().encode(watchedApps) {
            UserDefaults.standard.set(encoded, forKey: "WatchedApps")
        }
    }
    
    private func loadApps() {
        if let data = UserDefaults.standard.data(forKey: "WatchedApps"),
           let decoded = try? JSONDecoder().decode([WatchedApp].self, from: data) {
            watchedApps = decoded
        }
    }
}

// MARK: - Notification Watcher

class NotificationWatcher {
    private var appObserver: AXObserver?
    private var watchedApps: [WatchedApp]
    private let onNotificationDetected: (String, String) -> Void // BundleID or Name, DisplayName
    private let logHandler: (String) -> Void
    private var isRunning = false
    
    init(watchedApps: [WatchedApp], onNotificationDetected: @escaping (String, String) -> Void, logHandler: @escaping (String) -> Void) {
        self.watchedApps = watchedApps
        self.onNotificationDetected = onNotificationDetected
        self.logHandler = logHandler
    }
    
    func updateWatchedApps(_ apps: [WatchedApp]) {
        self.watchedApps = apps
    }
    
    func start() {
        guard !isRunning else { return }
        
        let bundleID = "com.apple.notificationcenterui"
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            logHandler("Error: Notification Center process not found")
            return
        }
        let pid = app.processIdentifier
        
        // Create Observer
        var observer: AXObserver?
        let result = AXObserverCreate(pid, { (observer, element, notification, refcon) in
            guard let refcon = refcon else { return }
            let watcher = Unmanaged<NotificationWatcher>.fromOpaque(refcon).takeUnretainedValue()
            
            if notification == kAXWindowCreatedNotification as CFString {
                watcher.handleWindowCreated(element: element)
            }
        }, &observer)
        
        guard result == .success, let axObserver = observer else {
            logHandler("Error: Failed to create AXObserver")
            return
        }
        self.appObserver = axObserver
        
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let appElement = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(axObserver, appElement, kAXWindowCreatedNotification as CFString, selfPtr)
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        isRunning = true
        logHandler("Started listening for new notifications")
    }
    
    func stop() {
        guard isRunning, let axObserver = appObserver else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        self.appObserver = nil
        isRunning = false
        logHandler("Stopped watching")
    }
    
    private func handleWindowCreated(element: AXUIElement) {
        // Inspect for app name match
        if let match = findMatchingApp(element: element) {
            // We found a notification for a watched app!
            // We pass matched app info back
            onNotificationDetected(match.bundleIdentifier, match.name)
        }
    }
    
    private func findMatchingApp(element: AXUIElement) -> WatchedApp? {
        var foundApp: WatchedApp?
        
        func traverse(_ el: AXUIElement, depth: Int) {
            if foundApp != nil { return }
            if depth > 4 { return }
            
            // Helper to check text against apps
            func check(_ text: String?) {
                guard let text = text, foundApp == nil else { return }
                if let match = watchedApps.first(where: { text.localizedCaseInsensitiveContains($0.name) }) {
                    foundApp = match
                }
            }
            
            check(getAXAttributeString(el, kAXTitleAttribute as CFString))
            check(getAXAttributeString(el, kAXValueAttribute as CFString))
            check(getAXAttributeString(el, kAXDescriptionAttribute as CFString))
            
            if foundApp != nil { return }
            
            if let children = getAXAttributeArray(el, kAXChildrenAttribute as CFString) as? [AXUIElement] {
                for child in children {
                    traverse(child, depth: depth + 1)
                }
            }
        }
        
        traverse(element, depth: 0)
        return foundApp
    }
}

// Helpers
func getAXAttributeString(_ element: AXUIElement, _ attribute: CFString) -> String? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    if result == .success, let str = value as? String { return str }
    return nil
}

func getAXAttributeArray(_ element: AXUIElement, _ attribute: CFString) -> [Any]? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    if result == .success, let arr = value as? [Any] { return arr }
    return nil
}


// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    private let captureSession = AVCaptureSession()
    @Published var isCameraOn = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupCamera() } }
            }
        case .denied, .restricted:
            errorMessage = "Camera access denied."
        @unknown default: break
        }
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .low
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
        guard let device = discoverySession.devices.first else {
            DispatchQueue.main.async { self.errorMessage = "No camera found." }
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) { captureSession.addInput(input) }
            let output = AVCaptureVideoDataOutput()
            if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
            captureSession.commitConfiguration()
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Setup error: \(error.localizedDescription)" }
            captureSession.commitConfiguration()
        }
    }
    
    func toggleCamera(forceOn: Bool? = nil, forceOff: Bool? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let forceOff = forceOff, forceOff {
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                    DispatchQueue.main.async { self.isCameraOn = false }
                }
                return
            }
            if let forceOn = forceOn, forceOn {
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                    DispatchQueue.main.async { self.isCameraOn = true }
                }
                return
            }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async { self.isCameraOn = false }
            } else {
                self.captureSession.startRunning()
                DispatchQueue.main.async { self.isCameraOn = true }
            }
        }
    }
}

// MARK: - Views

struct SettingsView: View {
    @EnvironmentObject var appManager: AppSelectionManager
    @StateObject private var cameraManager = CameraManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Divider()
            
            Toggle("Show Debug Logs", isOn: $appManager.showDebugLogs)
                .toggleStyle(SwitchToggleStyle(tint: .green))
            
            Toggle("Enable Window Blur", isOn: $appManager.enableBlur)
                .toggleStyle(SwitchToggleStyle(tint: .green))
            
            Divider()
            
            Button(action: {
                cameraManager.toggleCamera()
            }) {
                HStack {
                    Image(systemName: cameraManager.isCameraOn ? "camera.fill" : "camera")
                        .foregroundColor(cameraManager.isCameraOn ? .green : .primary)
                    Text(cameraManager.isCameraOn ? "Turn Off Light" : "Test Light")
                }
                .frame(width: 150)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}

struct AppCardView: View {
    let app: WatchedApp
    let isActive: Bool
    let onRemove: () -> Void
    let onToggle: () -> Void
    @EnvironmentObject var appManager: AppSelectionManager
    
    var body: some View {
        Button(action: onToggle) {
            ZStack {
                // Background Blur (App Card level)
                if let iconPath = app.iconPath {
                     let icon = NSWorkspace.shared.icon(forFile: iconPath)
                     icon.averageColor
                        .opacity(appManager.enableBlur ? 0.2 : 0.4) // Adjust opacity for vibrancy
                        .blur(radius: 20)
                } else {
                    Color.gray.opacity(0.3)
                        .blur(radius: 20)
                }
                
                // Content
                VStack {
                    let icon = NSWorkspace.shared.icon(forFile: app.iconPath ?? "")
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                .padding()
                
                // Active Indicator (Border)
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                }
                
                // Delete Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(5)
                    }
                    Spacer()
                }
            }
            .frame(width: 120, height: 120)
            .background(
                appManager.enableBlur ? Color.white.opacity(0.1) : Color(nsColor: .windowBackgroundColor).opacity(0.6)
            )
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ContentView: View {
    @EnvironmentObject var appManager: AppSelectionManager
    @StateObject private var cameraManager = CameraManager.shared
    @State private var showSettings = false
    
    let columns = [
        GridItem(.adaptive(minimum: 120))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Notification Light")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(appManager.isMonitoring ? "Monitoring Active" : "Monitoring Paused")
                        .font(.subheadline)
                        .foregroundColor(appManager.isMonitoring ? .green : .secondary)
                }
                Spacer()
                
                Toggle("", isOn: $appManager.isMonitoring)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .disabled(!appManager.accessibilityPermissionGranted)
                    .padding(.trailing, 10)
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(",", modifiers: .command)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
            .padding()
            .background(
                appManager.enableBlur 
                ? Color(nsColor: .controlBackgroundColor).opacity(0.3) 
                : Color(nsColor: .controlBackgroundColor)
            )
            
            if !appManager.accessibilityPermissionGranted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Accessibility Permission Needed")
                    Button("Open Settings") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
            }
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(appManager.watchedApps) { app in
                        AppCardView(
                            app: app,
                            isActive: appManager.activeAppIDs.contains(app.bundleIdentifier),
                            onRemove: { appManager.removeApp(app) },
                            onToggle: { appManager.toggleActiveState(for: app) }
                        )
                    }
                    
                    // Add Button Card
                    Button(action: appManager.addApp) {
                        ZStack {
                            if appManager.enableBlur {
                                Color.white.opacity(0.1)
                            } else {
                                Color(nsColor: .controlBackgroundColor).opacity(0.5)
                            }
                            
                            VStack {
                                Image(systemName: "plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Add App")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            
            Divider()
            
            // Footer Log
            VStack(alignment: .leading) {
                HStack {
                    if cameraManager.isCameraOn {
                        Label("Light ON", systemImage: "camera.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Light OFF", systemImage: "camera")
                            .foregroundColor(.secondary)
                    }
                    
                    // Simple "Clear All" button for convenience
                    if !appManager.activeAppIDs.isEmpty {
                        Spacer()
                        Button("Clear All") {
                            appManager.activeAppIDs.removeAll()
                        }
                        .font(.caption)
                    }
                    
                    if appManager.showDebugLogs {
                        Spacer()
                        Text(appManager.debugLog)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(
                appManager.enableBlur 
                ? Color(nsColor: .controlBackgroundColor).opacity(0.3) 
                : Color(nsColor: .controlBackgroundColor)
            )
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(
            Group {
                if appManager.enableBlur {
                    VisualEffectView().ignoresSafeArea()
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
        )
        // Window Accessor to toggle transparency on the window itself
        .background(WindowAccessor { window in
            guard let window = window else { return }
            
            if appManager.enableBlur {
                window.isOpaque = false
                window.backgroundColor = .clear
                // Adding fullSizeContentView to style mask helps the view extend behind titlebar
                if !window.styleMask.contains(.fullSizeContentView) {
                    window.styleMask.insert(.fullSizeContentView)
                }
                window.titlebarAppearsTransparent = true
            } else {
                window.isOpaque = true
                window.backgroundColor = .windowBackgroundColor
                // We might want to remove fullSizeContentView if it wasn't there, 
                // but HiddenTitleBarWindowStyle likely adds it anyway.
            }
        })
    }
}
