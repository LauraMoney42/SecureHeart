//
//  WatchFaceView.swift
//  Secure Heart Watch App
//
//  A minimal watch face-style view with heart rate, time, and date
//

import SwiftUI

struct WatchFaceView: View {
    @EnvironmentObject var heartRateManager: HeartRateManager
    @State private var currentTime = Date()
    @State private var pulseAnimation = false
    @State private var colonVisible = true
    @AppStorage("watchFaceBackgroundColor") private var selectedBackgroundColor = 0
    @AppStorage("bpmTextColor") private var selectedBPMTextColor = 14 // Default to black
    @AppStorage("bpmTextColorUserChosen") private var bpmTextColorUserChosen = false // Track if user explicitly chose BPM color
    
    // Timer to update time every second
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // Timer for blinking colon
    private let colonTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
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
    
    private var backgroundColor: Color {
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
    
    private var textColor: Color {
        return isLightBackground ? .black : .white
    }
    
    private var secondaryTextColor: Color {
        return isLightBackground ? Color.black.opacity(0.6) : Color.white.opacity(0.6)
    }
    
    private var tertiaryTextColor: Color {
        return isLightBackground ? Color.black.opacity(0.8) : Color.white.opacity(0.8)
    }
    
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

    // Custom BPM text color based on user selection
    private var customBPMTextColor: Color {
        if selectedBPMTextColor < allBPMTextColors.count {
            return allBPMTextColors[selectedBPMTextColor]
        }
        return .white
    }

    // Effective BPM text color - uses zone colors by default (no heart in this view)
    private var effectiveBPMTextColor: Color {
        // If user has explicitly chosen a BPM color, use that
        if bpmTextColorUserChosen {
            return customBPMTextColor
        }

        // Otherwise, use heart rate zone colors (this face has no heart)
        return heartColor
    }

    var body: some View {
        ZStack {
            // Background with theme support
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Layer 1: Date positioned under system time (top-right)
                HStack {
                    Spacer()
                    Text(dateString)
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(textColor)
                        .tracking(1.0)
                }
                .padding(.trailing, 10)
                .padding(.top, -5) // Move higher up and further right

                // Layer 2: Large heart rate in center (main focus)
                Spacer()

                Text("\(heartRateManager.currentHeartRate)")
                    .font(.system(size: 92, weight: .light, design: .default))
                    .foregroundColor(effectiveBPMTextColor)

                // Layer 3: Bottom spacer
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onReceive(colonTimer) { _ in
            colonVisible.toggle()
        }
        .onAppear {
            pulseAnimation = true
            // Request fresh heart rate on appear
            heartRateManager.fetchLatestHeartRate()
        }
        .onTapGesture(count: 2) {
            // Double-tap to cycle through background colors
            selectedBackgroundColor = (selectedBackgroundColor + 1) % allBackgroundColors.count
        }
        .onTapGesture {
            // Single tap to refresh heart rate
            heartRateManager.fetchLatestHeartRate()
        }
    }
    
    // MARK: - Computed Properties
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d" // "SUN 7" format
        return formatter.string(from: currentTime).uppercased()
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h"
        return formatter.string(from: currentTime)
    }
    
    private var minuteString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        return formatter.string(from: currentTime)
    }
    
    private var colonOpacity: Double {
        colonVisible ? 1.0 : 0.3
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: currentTime)
    }
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentTime).uppercased()
    }
    
    private var timeString24Hour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private var heartColor: Color {
        let hr = heartRateManager.currentHeartRate
        if hr == 0 {
            return .gray
        } else if hr < 80 {
            return .blue
        } else if hr <= 120 {
            return .green
        } else if hr <= 150 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var heartBeatDuration: Double {
        let hr = heartRateManager.currentHeartRate
        if hr > 0 {
            return 60.0 / Double(hr)
        } else {
            return 1.0
        }
    }
}

// MARK: - Alternative Layouts

struct WatchFaceViewMinimal: View {
    @EnvironmentObject var heartRateManager: HeartRateManager
    @State private var currentTime = Date()
    @AppStorage("bpmTextColor") private var selectedBPMTextColor = 14 // Default to black
    @AppStorage("bpmTextColorUserChosen") private var bpmTextColorUserChosen = false // Track user choice
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
    
    // Custom BPM text color based on user selection
    private var customBPMTextColor: Color {
        if selectedBPMTextColor < allBPMTextColors.count {
            return allBPMTextColors[selectedBPMTextColor]
        }
        return .white
    }

    // Effective BPM text color - uses zone colors by default (no heart displayed prominently)
    private var effectiveBPMTextColor: Color {
        // If user has explicitly chosen a BPM color, use that
        if bpmTextColorUserChosen {
            return customBPMTextColor
        }

        // Otherwise, use heart rate zone colors
        return heartColor
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                // Time only - very large
                Text(timeString)
                    .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.white)

                // Heart rate - smaller
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(heartColor)

                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(effectiveBPMTextColor.opacity(0.8))
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onTapGesture {
            heartRateManager.fetchLatestHeartRate()
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private var heartColor: Color {
        let hr = heartRateManager.currentHeartRate
        if hr == 0 { return .gray }
        else if hr < 80 { return .blue }
        else if hr <= 120 { return .green }
        else if hr <= 150 { return .yellow }
        else { return .red }
    }
}

// MARK: - Analog Style

struct WatchFaceViewAnalog: View {
    @EnvironmentObject var heartRateManager: HeartRateManager
    @State private var currentTime = Date()
    @AppStorage("bpmTextColor") private var selectedBPMTextColor = 14 // Default to black
    @AppStorage("bpmTextColorUserChosen") private var bpmTextColorUserChosen = false // Track user choice
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
    
    // Custom BPM text color based on user selection
    private var customBPMTextColor: Color {
        if selectedBPMTextColor < allBPMTextColors.count {
            return allBPMTextColors[selectedBPMTextColor]
        }
        return .white
    }

    // Effective BPM text color - uses zone colors by default
    private var effectiveBPMTextColor: Color {
        // If user has explicitly chosen a BPM color, use that
        if bpmTextColorUserChosen {
            return customBPMTextColor
        }

        // Otherwise, use heart rate zone colors
        return heartColor
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Clock face circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 160, height: 160)
            
            // Hour markers
            ForEach(0..<12) { hour in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: hour % 3 == 0 ? 15 : 10)
                    .offset(y: -70)
                    .rotationEffect(.degrees(Double(hour) * 30))
            }
            
            // Clock hands
            ClockHand(angle: hourAngle, length: 50, width: 4, color: .white)
            ClockHand(angle: minuteAngle, length: 70, width: 3, color: .white)
            ClockHand(angle: secondAngle, length: 75, width: 1, color: .red)
            
            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
            
            // Digital time at top
            VStack {
                Text(timeString)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 20)
                
                Spacer()
                
                // Heart rate at bottom
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(heartColor)

                    Text("\(heartRateManager.currentHeartRate)")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(effectiveBPMTextColor)

                    Text("BPM")
                        .font(.system(size: 12))
                        .foregroundColor(effectiveBPMTextColor.opacity(0.6))
                }
                .padding(.bottom, 20)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onTapGesture {
            heartRateManager.fetchLatestHeartRate()
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: currentTime)
    }
    
    private var hourAngle: Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        return Double(hour % 12) * 30 + Double(minute) * 0.5 - 90
    }
    
    private var minuteAngle: Double {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: currentTime)
        let second = calendar.component(.second, from: currentTime)
        return Double(minute) * 6 + Double(second) * 0.1 - 90
    }
    
    private var secondAngle: Double {
        let calendar = Calendar.current
        let second = calendar.component(.second, from: currentTime)
        return Double(second) * 6 - 90
    }
    
    private var heartColor: Color {
        let hr = heartRateManager.currentHeartRate
        if hr == 0 { return .gray }
        else if hr < 80 { return .blue }
        else if hr <= 120 { return .green }
        else if hr <= 150 { return .yellow }
        else { return .red }
    }
}

struct ClockHand: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}

#Preview {
    WatchFaceView()
        .environmentObject(HeartRateManager())
}
