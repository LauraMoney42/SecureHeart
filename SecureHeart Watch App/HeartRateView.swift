//
//  HeartRateView.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI

struct HeartRateView: View {
    @EnvironmentObject var heartRateManager: HeartRateManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @State private var pulseAnimation = false
    // Digital Crown functionality removed to prevent app crashes
    @State private var isAlwaysOnDisplay = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var historyOffset: CGFloat = 0
    
    @AppStorage("selectedColorTheme") private var selectedColorTheme = 0
    @AppStorage("selectedWatchFace") private var selectedWatchFace = 3
    @AppStorage("alwaysOnEnabled") private var alwaysOnEnabled = true
    // Digital Crown sensitivity setting removed
    @AppStorage("showTimeOnWatch") private var showTimeOnWatch = true
    @AppStorage("watchFaceBackgroundColor") private var selectedBackgroundColor = 14 // 14=Black, 0=Red
    @AppStorage("bpmTextColor") private var selectedBPMTextColor = 14 // Default to black
    @AppStorage("bpmTextColorUserChosen") private var bpmTextColorUserChosen = false // Track if user explicitly chose BPM color
    
    // Custom theme colors stored as hex strings
    @AppStorage("customLowColor") private var customLowColorHex = "#007AFF" // Blue
    @AppStorage("customNormalColor") private var customNormalColorHex = "#34C759" // Green
    @AppStorage("customElevatedColor") private var customElevatedColorHex = "#FFCC00" // Yellow
    @AppStorage("customHighColor") private var customHighColorHex = "#FF3B30" // Red
    
    private let colorThemes: [ColorTheme] = [
        ColorTheme(
            name: "Classic",
            lowColor: .blue,
            normalColor: .green,
            elevatedColor: .yellow,
            highColor: .red,
            noReadingColor: .gray
        ),
        ColorTheme(
            name: "Pretty",
            lowColor: .cyan,
            normalColor: .purple,
            elevatedColor: .pink,
            highColor: .pink,
            noReadingColor: .gray
        ),
        ColorTheme(
            name: "Monochrome",
            lowColor: .white,
            normalColor: .white,
            elevatedColor: .white,
            highColor: .white,
            noReadingColor: .gray
        ),
        ColorTheme(
            name: "Rainbow",
            lowColor: Color(red: 0.0, green: 0.4, blue: 1.0),    // Vibrant blue
            normalColor: Color(red: 0.0, green: 0.9, blue: 0.0), // Vibrant green  
            elevatedColor: Color(red: 1.0, green: 0.6, blue: 0.0), // Vibrant orange
            highColor: Color(red: 1.0, green: 0.0, blue: 0.4),   // Vibrant red-pink
            noReadingColor: Color(red: 0.6, green: 0.0, blue: 1.0) // Vibrant purple
        ),
        ColorTheme(
            name: "Ocean",
            lowColor: .cyan,
            normalColor: .mint,
            elevatedColor: .blue,
            highColor: .indigo,
            noReadingColor: .gray
        ),
        ColorTheme(
            name: "Pastel Rainbow",
            lowColor: Color(red: 0.8, green: 0.9, blue: 1.0),      // Soft blue
            normalColor: Color(red: 0.85, green: 0.95, blue: 0.8), // Soft green
            elevatedColor: Color(red: 1.0, green: 0.9, blue: 0.7), // Soft yellow
            highColor: Color(red: 1.0, green: 0.8, blue: 0.85),    // Soft pink
            noReadingColor: Color(red: 0.9, green: 0.85, blue: 1.0) // Soft purple
        ),
        ColorTheme(
            name: "Pastel",
            lowColor: Color(red: 0.8, green: 0.95, blue: 1.0),     // Soft cyan (like Pretty's cyan)
            normalColor: Color(red: 0.9, green: 0.8, blue: 1.0),   // Soft purple (like Pretty's purple)
            elevatedColor: Color(red: 1.0, green: 0.85, blue: 0.9), // Soft pink (like Pretty's pink)
            highColor: Color(red: 1.0, green: 0.85, blue: 0.9),    // Soft pink (like Pretty's pink)
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Pinks",
            lowColor: Color(red: 1.0, green: 0.9, blue: 0.95),     // Very light pink (like Ocean's cyan)
            normalColor: Color(red: 1.0, green: 0.75, blue: 0.9),  // Light pink (like Ocean's mint)
            elevatedColor: Color(red: 1.0, green: 0.6, blue: 0.8), // Medium pink (like Ocean's blue)
            highColor: Color(red: 0.9, green: 0.4, blue: 0.7),     // Deep pink (like Ocean's indigo)
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Forest",
            lowColor: Color(red: 0.8, green: 1.0, blue: 0.8),      // Light mint green
            normalColor: Color(red: 0.6, green: 0.9, blue: 0.6),   // Fresh green
            elevatedColor: Color(red: 0.4, green: 0.8, blue: 0.4), // Forest green
            highColor: Color(red: 0.2, green: 0.6, blue: 0.2),     // Deep forest
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Fire",
            lowColor: Color(red: 1.0, green: 0.9, blue: 0.7),      // Warm yellow
            normalColor: Color(red: 1.0, green: 0.7, blue: 0.4),   // Orange
            elevatedColor: Color(red: 1.0, green: 0.4, blue: 0.2), // Red-orange
            highColor: Color(red: 0.8, green: 0.2, blue: 0.1),     // Deep red
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Sunshine",
            lowColor: Color(red: 1.0, green: 1.0, blue: 0.8),      // Pale yellow
            normalColor: Color(red: 1.0, green: 1.0, blue: 0.6),   // Light yellow
            elevatedColor: Color(red: 1.0, green: 0.9, blue: 0.3), // Bright yellow
            highColor: Color(red: 1.0, green: 0.8, blue: 0.0),     // Golden yellow
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Midnight",
            lowColor: Color(red: 0.7, green: 0.8, blue: 1.0),      // Light blue
            normalColor: Color(red: 0.5, green: 0.6, blue: 0.9),   // Medium blue
            elevatedColor: Color(red: 0.3, green: 0.4, blue: 0.7), // Dark blue
            highColor: Color(red: 0.1, green: 0.2, blue: 0.5),     // Deep navy
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Sunset",
            lowColor: Color(red: 1.0, green: 0.9, blue: 0.8),      // Cream
            normalColor: Color(red: 1.0, green: 0.7, blue: 0.6),   // Peach
            elevatedColor: Color(red: 1.0, green: 0.5, blue: 0.4), // Coral
            highColor: Color(red: 0.9, green: 0.3, blue: 0.5),     // Pink-red
            noReadingColor: Color(red: 0.85, green: 0.85, blue: 0.85) // Soft gray
        ),
        ColorTheme(
            name: "Custom",
            lowColor: .blue,  // Will be overridden by computed property
            normalColor: .green,
            elevatedColor: .yellow,
            highColor: .red,
            noReadingColor: .gray
        )
    ]
    
    enum Theme: CaseIterable {
        case classic
        case minimal
        case pastel
        case chunky
        case numbersOnly
        
        var name: String {
            switch self {
            case .classic: return "Classic"
            case .minimal: return "Minimal"
            case .pastel: return "Pastel"
            case .chunky: return "Chunky"
            case .numbersOnly: return "Numbers Only"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                themeBackgroundColor
                    .ignoresSafeArea()
                
                mainContentView
                    .gesture(swipeGesture) // Move gesture to mainContentView
                alwaysOnOverlayView
                alertOverlay // Move alert into ZStack
                historyOverlayView // History on top of everything
            }
            .navigationBarHidden(true)
            .ignoresSafeArea(.all)
            .onAppear {
                print("❤️ HeartRateView appeared - forcing authorization")
                setupDefaultsOnFirstLaunch()
                pulseAnimation = true
                setupAlwaysOnDisplay()
                // Force start monitoring when view appears
                heartRateManager.requestAuthorization()
                heartRateManager.startContinuousMonitoring()
            }
            .onTapGesture {
                // Manual refresh on tap
                heartRateManager.fetchLatestHeartRate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                detectAlwaysOnState()
            }
            .animation(.easeInOut(duration: 0.3), value: heartRateManager.showAlert)
            .animation(.easeInOut(duration: 0.3), value: showingHistory)
            .sheet(isPresented: $showingSettings) {
                SettingsView(heartRateManager: heartRateManager)
            }
        }
    }
    
    // MARK: - View Components
    
    private var mainContentView: some View {
        TabView(selection: $selectedWatchFace) {
            classicThemeView.tag(0)
            detailsThemeView.tag(1)
            minimalThemeView.tag(2)
            chunkyThemeView.tag(3)
            numbersOnlyThemeView.tag(4)
            watchFaceThemeView.tag(5)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .opacity(isAlwaysOnDisplay && alwaysOnEnabled ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isAlwaysOnDisplay)
    }
    
    private var alwaysOnOverlayView: some View {
        Group {
            if isAlwaysOnDisplay && alwaysOnEnabled {
                alwaysOnOverlay
                    .transition(.opacity)
            }
        }
    }
    
    private var historyOverlayView: some View {
        Group {
            if showingHistory {
                historyOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10) // Higher z-index to cover everything
            }
        }
    }
    
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { dragValue in
                let translation = dragValue.translation
                // Swipe up to show history
                if translation.height < -30 && !showingHistory && !showingSettings {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingHistory = true
                        historyOffset = 0
                    }
                }
                // Swipe down to show settings
                else if translation.height > 30 && !showingSettings && !showingHistory {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSettings = true
                    }
                }
            }
    }
    
    private var alertOverlay: some View {
        Group {
            if heartRateManager.showAlert {
                ZStack {
                    if heartRateManager.alertMessage.contains("increased") || heartRateManager.alertMessage.contains("decreased") {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                heartRateManager.dismissAlert()
                            }
                    }
                    
                    alertContentView
                }
            }
        }
    }
    
    private var alertContentView: some View {
        VStack {
            VStack(spacing: 8) {
                if heartRateManager.alertMessage.contains("increased") || heartRateManager.alertMessage.contains("decreased") {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                Text(heartRateManager.alertMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if heartRateManager.alertMessage.contains("increased") || heartRateManager.alertMessage.contains("decreased") {
                    Text("Tap to dismiss")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(heartRateManager.alertMessage.contains("increased") || heartRateManager.alertMessage.contains("decreased") ? Color.red : Color.orange.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 3)
                    )
            )
            .onTapGesture {
                heartRateManager.dismissAlert()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Always-On Display Support
    
    private var alwaysOnOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 8) {
                // Simplified heart rate display for Always-On
                Text("\(heartRateManager.currentHeartRate)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.8)
                
                Text("BPM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(0.6)
                
                // Small heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(heartRateColor.opacity(0.7))
            }
        }
    }

    private func setupDefaultsOnFirstLaunch() {
        // Only set defaults if this is truly a first launch
        let hasEverLaunched = UserDefaults.standard.bool(forKey: "SecureHeartHasLaunched")

        if !hasEverLaunched {
            print("🎯 First launch detected - setting up better defaults")

            // Set better defaults only on first launch
            selectedWatchFace = 3           // Chunky theme (Face 3)
            selectedBackgroundColor = 14    // Black background
            selectedBPMTextColor = 14       // Black text (matches background)
            selectedColorTheme = 0          // Classic color theme (heart rate zone guidance)
            bpmTextColorUserChosen = false  // User hasn't chosen BPM color yet

            // Mark that app has launched so we don't override user settings
            UserDefaults.standard.set(true, forKey: "SecureHeartHasLaunched")

            print("✅ First-launch defaults applied: Classic theme, black background, black BPM text")
        } else {
            print("👤 Preserving user's chosen theme: \(selectedColorTheme)")
        }
    }

    private func setupAlwaysOnDisplay() {
        // Configure for always-on display optimization
        if alwaysOnEnabled {
            // Start more frequent updates for watch face integration
            heartRateManager.enableHighFrequencyUpdates()
            
            // Update always-on state based on luminance
            isAlwaysOnDisplay = isLuminanceReduced
            
            // Prevent app from being interrupted by notifications
            preventInterruptions()
        }
        
        // Ensure continuous monitoring is active (TachyMon style)
        heartRateManager.startContinuousMonitoring()
        
        // Monitor for always-on state changes
        monitorAlwaysOnStateChanges()
    }
    
    private func preventInterruptions() {
        // Minimize interruptions in watch face mode (watchOS specific)
        #if os(watchOS)
        
        // Monitor for app state changes
        NotificationCenter.default.addObserver(
            forName: .NSExtensionHostWillEnterForeground,
            object: nil,
            queue: .main
        ) { _ in
            // Immediately regain focus when returning from interruption
            self.regainFocus()
        }
        
        // Extended runtime session disabled to avoid entitlement errors
        
        #endif
    }
    
    private func regainFocus() {
        // Force the app back to the foreground
        DispatchQueue.main.async {
            // Watch face mode disabled
        }
    }
    
    private func monitorAlwaysOnStateChanges() {
        // React to always-on display changes
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let newAlwaysOnState = self.isLuminanceReduced
            if newAlwaysOnState != self.isAlwaysOnDisplay {
                self.isAlwaysOnDisplay = newAlwaysOnState
                
                if newAlwaysOnState {
                    // Entering always-on mode - optimize for power saving
                    self.optimizeForAlwaysOn()
                } else {
                    // Exiting always-on mode - restore full functionality
                    self.restoreFullFunctionality()
                }
            }
        }
    }
    
    private func optimizeForAlwaysOn() {
        // Reduce animation frequency for battery life
        pulseAnimation = false
        
        // Use standard monitoring for battery efficiency in always-on mode
        heartRateManager.startContinuousMonitoring()
    }
    
    private func restoreFullFunctionality() {
        // Restore normal operation when user interacts
        pulseAnimation = true
        
        // Enable high frequency updates when actively used
        heartRateManager.enableHighFrequencyUpdates()
    }
    
    private func detectAlwaysOnState() {
        // Detect when watch enters always-on display mode
        DispatchQueue.main.async {
            let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            isAlwaysOnDisplay = isLowPowerMode
        }
    }
    
    // Digital Crown navigation removed - was causing app crashes
    // Users can swipe or use other gestures to navigate watch faces if needed
    
    private var heartRateColor: Color {
        let heartRate = heartRateManager.currentHeartRate
        
        // Check if Custom theme is selected (last index)
        if selectedColorTheme == colorThemes.count - 1 {
            // Use custom colors
            if heartRate == 0 {
                return .gray
            } else if heartRate < 80 {
                return Color(hex: customLowColorHex) ?? .blue
            } else if heartRate >= 80 && heartRate <= 120 {
                return Color(hex: customNormalColorHex) ?? .green
            } else if heartRate > 120 && heartRate <= 150 {
                return Color(hex: customElevatedColorHex) ?? .yellow
            } else {
                return Color(hex: customHighColorHex) ?? .red
            }
        } else {
            // Use predefined theme colors
            let theme = colorThemes[selectedColorTheme]
            if heartRate == 0 {
                return theme.noReadingColor
            } else if heartRate < 80 {
                return theme.lowColor
            } else if heartRate >= 80 && heartRate <= 120 {
                return theme.normalColor
            } else if heartRate > 120 && heartRate <= 150 {
                return theme.elevatedColor
            } else {
                return theme.highColor
            }
        }
    }
    
    private var isRainbowTheme: Bool {
        return selectedColorTheme == 3 // Rainbow theme index
    }
    
    private var isPastelRainbowTheme: Bool {
        return selectedColorTheme == 5 // Pastel Rainbow theme index
    }
    
    private var rainbowGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.0, blue: 0.0),   // Red
                Color(red: 1.0, green: 0.5, blue: 0.0),   // Orange  
                Color(red: 1.0, green: 1.0, blue: 0.0),   // Yellow
                Color(red: 0.0, green: 1.0, blue: 0.0),   // Green
                Color(red: 0.0, green: 0.0, blue: 1.0),   // Blue
                Color(red: 0.5, green: 0.0, blue: 1.0)    // Purple
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var pastelRainbowGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.9, green: 0.85, blue: 1.0),  // Soft purple
                Color(red: 0.8, green: 0.9, blue: 1.0),   // Soft blue
                Color(red: 0.85, green: 0.95, blue: 0.8), // Soft green
                Color(red: 1.0, green: 0.9, blue: 0.7),   // Soft yellow
                Color(red: 1.0, green: 0.85, blue: 0.8),  // Soft orange
                Color(red: 1.0, green: 0.8, blue: 0.85)   // Soft pink
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // All background colors matching the expanded BackgroundThemeView palette
    private let allBackgroundColors: [Color] = [
        // Row 1: Primary colors
        .red, .orange, .yellow, .green, .mint,
        
        // Row 2: Blues and purples  
        .teal, .cyan, .blue, Color(red: 0.7, green: 0.5, blue: 1.0), .purple,
        
        // Row 3: Neutrals and basics
        Color(red: 1.0, green: 0.2, blue: 0.4), // Hot pink
        .brown, .white, .gray, .black,
        
        // Row 4: Sunset Terra palette
        Color(red: 0.98, green: 0.93, blue: 0.89), // Cream
        Color(red: 1.0, green: 0.78, blue: 0.74),  // Coral Pink
        Color(red: 0.87, green: 0.70, blue: 0.60), // Warm Brown
        Color(red: 0.97, green: 0.88, blue: 0.82), // Peachy Cream
        Color(red: 0.97, green: 0.77, blue: 0.68), // Salmon
        
        // Row 5: Gelato Days palette
        Color(red: 1.0, green: 0.80, blue: 0.76),  // Soft Coral
        Color(red: 0.62, green: 0.90, blue: 0.31), // Lime Green
        Color(red: 1.0, green: 0.88, blue: 0.66),  // Pale Yellow
        Color(red: 0.55, green: 0.85, blue: 0.93), // Sky Blue
        Color(red: 0.86, green: 0.78, blue: 0.93)  // Lavender
    ]
    
    // BPM text colors - same palette as background colors
    private let allBPMTextColors: [Color] = [
        // Row 1: Primary colors
        .red, .orange, .yellow, .green, .mint,
        
        // Row 2: Blues and purples  
        .teal, .cyan, .blue, Color(red: 0.7, green: 0.5, blue: 1.0), .purple,
        
        // Row 3: Neutrals and basics
        Color(red: 1.0, green: 0.2, blue: 0.4), // Hot pink
        .brown, .white, .gray, .black,
        
        // Row 4: Sunset Terra palette
        Color(red: 0.98, green: 0.93, blue: 0.89), // Cream
        Color(red: 1.0, green: 0.78, blue: 0.74),  // Coral Pink
        Color(red: 0.87, green: 0.70, blue: 0.60), // Warm Brown
        Color(red: 0.97, green: 0.88, blue: 0.82), // Peachy Cream
        Color(red: 0.97, green: 0.77, blue: 0.68), // Salmon
        
        // Row 5: Gelato Days palette
        Color(red: 1.0, green: 0.80, blue: 0.76),  // Soft Coral
        Color(red: 0.62, green: 0.90, blue: 0.31), // Lime Green
        Color(red: 1.0, green: 0.88, blue: 0.66),  // Pale Yellow
        Color(red: 0.55, green: 0.85, blue: 0.93), // Sky Blue
        Color(red: 0.86, green: 0.78, blue: 0.93)  // Lavender
    ]
    
    // Background color based on theme selection
    private var themeBackgroundColor: Color {
        if selectedBackgroundColor < allBackgroundColors.count {
            return allBackgroundColors[selectedBackgroundColor]
        }
        return .black
    }
    
    private var isLightBackground: Bool {
        // Determine if current background is light and needs dark text
        let lightBackgrounds: Set<Int> = [
            2,  // Yellow
            4,  // Mint
            12, // White
            15, // Cream
            16, // Coral Pink
            18, // Peachy Cream
            19, // Salmon
            20, // Soft Coral
            22, // Pale Yellow
            23, // Sky Blue
            24  // Lavender
        ]
        return lightBackgrounds.contains(selectedBackgroundColor)
    }
    
    // Dynamic text color based on background
    private var themeTextColor: Color {
        return isLightBackground ? .black : .white
    }
    
    // Custom BPM text color based on user selection
    private var customBPMTextColor: Color {
        if selectedBPMTextColor < allBPMTextColors.count {
            return allBPMTextColors[selectedBPMTextColor]
        }
        return .white
    }

    // Effective BPM text color - auto-matches background or uses zone colors if user hasn't explicitly chosen
    private var effectiveBPMTextColor: Color {
        // If user has explicitly chosen a BPM color, use that
        if bpmTextColorUserChosen {
            return customBPMTextColor
        }

        // Otherwise, auto-match behavior depends on watch face type:
        // Faces WITH hearts (Classic=0, Details=1): Match background color
        if selectedWatchFace == 0 || selectedWatchFace == 1 {
            return themeBackgroundColor
        }

        // Faces WITHOUT hearts (Minimal=2, Chunky=3, Numbers Only=4, Watch Face=5):
        // Use heart rate zone colors (blue/green/yellow/red based on BPM)
        return heartRateColor
    }
    
    private var heartRateTextColor: Color {
        // For watch faces with colored hearts (Classic, Details):
        // Use automatic text color that contrasts with background
        // (black text on light backgrounds, white text on dark backgrounds)
        return themeTextColor
    }
    
    private var heartBeatDuration: Double {
        let heartRate = heartRateManager.currentHeartRate
        
        if heartRate > 0 {
            return 60.0 / Double(heartRate)
        } else {
            return 1.0
        }
    }
    
    // MARK: - Theme Views
    
    private var classicThemeView: some View {
        ZStack {
            // Classic theme - current design
            ZStack {
                if isRainbowTheme {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 170))
                        .foregroundStyle(rainbowGradient)
                        .modifier(PulseEffect())
                } else if isPastelRainbowTheme {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 170))
                        .foregroundStyle(pastelRainbowGradient)
                        .modifier(PulseEffect())
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 170))
                        .foregroundColor(heartRateColor)
                        .modifier(PulseEffect())
                }
                
                VStack(spacing: 2) {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundColor(effectiveBPMTextColor)

                    Text("BPM")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(effectiveBPMTextColor.opacity(0.8))
                }
            }
            .offset(y: 15)
            
            // Delta indicator
            if abs(heartRateManager.heartRateDelta) >= 30 {
                VStack(spacing: 2) {
                    Text("\(heartRateManager.heartRateDelta > 0 ? "↑" : "↓")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(heartRateManager.heartRateDelta > 0 ? .red : .green)
                    Text("\(abs(heartRateManager.heartRateDelta))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .offset(x: 70, y: 15)
            }
            
            // Posture indicator (top-left corner) - Commented out for MVP2
            /*
            VStack(spacing: 2) {
                Image(systemName: heartRateManager.isStanding ? "figure.stand" : "figure.seated.side")
                    .font(.system(size: 12))
                    .foregroundColor(heartRateManager.isStanding ? .green : .blue)
                Text(heartRateManager.isStanding ? "Standing" : "Sitting")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .offset(x: -70, y: -60)
            */
        }
    }
    
    private var detailsThemeView: some View {
        ZStack {
            VStack(spacing: 15) {
                // Large heart with numbers inside (same size as Classic theme)
                ZStack {
                    if isRainbowTheme {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 140))
                            .foregroundStyle(rainbowGradient)
                            .modifier(PulseEffect())
                    } else if isPastelRainbowTheme {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 140))
                            .foregroundStyle(pastelRainbowGradient)
                            .modifier(PulseEffect())
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 140))
                            .foregroundColor(heartRateColor)
                            .modifier(PulseEffect())
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(heartRateManager.currentHeartRate)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(effectiveBPMTextColor)

                        Text("BPM")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(effectiveBPMTextColor.opacity(0.8))
                    }
                }
                .offset(y: 5)
                
                // Status text below heart
                Text(heartRateStatus)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(heartRateColor)
                    .multilineTextAlignment(.center)
                    .offset(y: -5)
            }
            
            // Delta indicator to the right
            if abs(heartRateManager.heartRateDelta) >= 30 {
                VStack(spacing: 2) {
                    Text("\(heartRateManager.heartRateDelta > 0 ? "↑" : "↓")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(heartRateManager.heartRateDelta > 0 ? .red : .green)
                    Text("\(abs(heartRateManager.heartRateDelta))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .offset(x: 55, y: 5)
            }
        }
    }
    
    private var minimalThemeView: some View {
        ZStack {
            VStack(spacing: 20) {
                // Minimal - uses theme colors or zone colors
                if isRainbowTheme {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundStyle(rainbowGradient)
                } else if isPastelRainbowTheme {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundStyle(pastelRainbowGradient)
                } else {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundColor(effectiveBPMTextColor)
                }
                
                if isRainbowTheme {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(rainbowGradient)
                        .modifier(PulseEffect())
                } else if isPastelRainbowTheme {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(pastelRainbowGradient)
                        .modifier(PulseEffect())
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(heartRateColor)
                        .modifier(PulseEffect())
                }
            }
        }
    }
    
    private var chunkyThemeView: some View {
        VStack(spacing: showTimeOnWatch ? 12 : 20) {
            // Time at top (chunky style) - conditional display
            if showTimeOnWatch {
                if isRainbowTheme {
                    Text(currentTimeString)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(rainbowGradient)
                } else if isPastelRainbowTheme {
                    Text(currentTimeString)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(pastelRainbowGradient)
                } else {
                    Text(currentTimeString)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(effectiveBPMTextColor)
                }
            }
            
            // Large heart rate without circle
            VStack(spacing: 4) {
                if isRainbowTheme {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(rainbowGradient)
                } else if isPastelRainbowTheme {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(pastelRainbowGradient)
                } else {
                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(effectiveBPMTextColor)
                }
                    
                    // Trend arrows
                    HStack(spacing: 4) {
                        if heartRateManager.heartRateDelta > 10 {
                            if isRainbowTheme {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                            }
                        } else if heartRateManager.heartRateDelta > 0 {
                            if isRainbowTheme {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                            }
                        } else if heartRateManager.heartRateDelta < -10 {
                            if isRainbowTheme {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                            } else {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                            }
                        } else if heartRateManager.heartRateDelta < 0 {
                            if isRainbowTheme {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                            } else {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                            }
                        } else {
                            if isRainbowTheme {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rainbowGradient)
                            } else {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(effectiveBPMTextColor)
                            }
                        }
                    }
            }
        }
    }
    
    private var numbersOnlyThemeView: some View {
        VStack {
            // Large numbers only - no heart, no BPM, just numbers
            if isRainbowTheme {
                Text("\(heartRateManager.currentHeartRate)")
                    .font(.system(size: 90, weight: .thin, design: .rounded))
                    .foregroundStyle(rainbowGradient)
            } else if isPastelRainbowTheme {
                Text("\(heartRateManager.currentHeartRate)")
                    .font(.system(size: 90, weight: .thin, design: .rounded))
                    .foregroundStyle(pastelRainbowGradient)
            } else {
                Text("\(heartRateManager.currentHeartRate)")
                    .font(.system(size: 90, weight: .thin, design: .rounded))
                    .foregroundColor(effectiveBPMTextColor)
            }
        }
    }
    
    private var watchFaceThemeView: some View {
        WatchFaceView()
            .environmentObject(heartRateManager)
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private var heartRateStatus: String {
        let heartRate = heartRateManager.currentHeartRate
        
        if heartRate == 0 {
            return "Measuring..."
        } else if heartRate < 60 {
            return "Low - Resting"
        } else if heartRate >= 60 && heartRate < 80 {
            return "Normal - Resting"
        } else if heartRate >= 80 && heartRate <= 120 {
            return "Normal - Active"
        } else if heartRate > 120 && heartRate <= 150 {
            return "Elevated"
        } else if heartRate > 150 && heartRate <= 180 {
            return "High - Exercise"
        } else {
            return "Very High"
        }
    }
    
    // MARK: - History Overlay
    
    private var historyOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Full black background to hide everything underneath
                Color.black
                    .ignoresSafeArea(.all) // Ignore all safe areas including status bar
                    .frame(width: geometry.size.width, height: geometry.size.height + 100) // Extend beyond screen
                    .offset(y: -50) // Offset to cover status bar area
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingHistory = false
                        }
                    }
                
                VStack(spacing: 0) {
                    // Header with close indicator
                    Text("Heart Rate History")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 50) // Move down more to avoid settings icon
                        .padding(.bottom, 15)
                    
                    // History list - Much larger and more readable
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(heartRateManager.heartRateHistory) { reading in
                                VStack(alignment: .leading, spacing: 6) {
                                    // Main row with heart rate and time
                                    HStack(alignment: .center) {
                                        // Color indicator
                                        Circle()
                                            .fill(colorForHeartRate(reading.heartRate))
                                            .frame(width: 10, height: 10)
                                        
                                        // Heart rate number only (removed BPM for better visibility)
                                        Text("\(reading.heartRate)")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        // Time
                                        Text(formatTime(reading.timestamp))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    // Second row with context and delta
                                    HStack(spacing: 12) {
                                        // Standing/Sitting indicator - Commented out for MVP2
                                        /*
                                        if let context = reading.context {
                                            HStack(spacing: 4) {
                                                Image(systemName: context.contains("Standing") ? "figure.stand" : "figure.seated.side")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.8))
                                                
                                                Text(context.contains("Standing") ? "Standing" : "Sitting")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        }
                                        */
                                        
                                        // Delta indicator
                                        if !reading.deltaText.isEmpty {
                                            HStack(spacing: 2) {
                                                Image(systemName: reading.delta > 0 ? "arrow.up" : "arrow.down")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(reading.delta > 0 ? .red : .green)
                                                
                                                Text("\(abs(reading.delta))")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(reading.delta > 0 ? .red : .green)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 100)  // Extra bottom padding to ensure last entry is fully visible
                    }
                    .padding(.bottom, 20)  // Additional padding for the ScrollView itself
                }
            }
            .edgesIgnoringSafeArea(.all) // Ensure it covers everything
        }
        .gesture(
            DragGesture()
                .onEnded { dragValue in
                    let translation = dragValue.translation
                    if translation.height > 50 {
                        // Swipe down to close
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingHistory = false
                        }
                    }
                }
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func colorForHeartRate(_ heartRate: Int) -> Color {
        if heartRate < 60 {
            return .blue
        } else if heartRate < 80 {
            return .green
        } else if heartRate < 120 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct PulseEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    scale = 1.1
                }
            }
    }
}



#Preview {
    HeartRateView()
        .environmentObject(HeartRateManager())
}