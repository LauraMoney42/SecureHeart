//
//  SettingsView.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

struct SettingsView: View {
    @ObservedObject var heartRateManager: HeartRateManager
    @AppStorage("selectedColorTheme") private var selectedColorTheme = 0
    @AppStorage("recordingInterval") private var recordingInterval = 60.0
    @AppStorage("showTimeOnWatch") private var showTimeOnWatch = true
    
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
            lowColor: .blue,  // Will be overridden by user-selected colors
            normalColor: .green,
            elevatedColor: .yellow,
            highColor: .red,
            noReadingColor: .gray
        )
    ]
    
    var body: some View {
        NavigationStack {
            List {
                
                Section("Appearance") {
                    NavigationLink(destination: ThemesView(selectedColorTheme: $selectedColorTheme, colorThemes: colorThemes)) {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Themes")
                                .padding(.vertical, 6)
                        }
                    }
                    
                    // Time display toggle
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Toggle("Show Theme Time", isOn: $showTimeOnWatch)
                    }
                }
                
                Section("Data") {
                    NavigationLink(destination: HistoryView(heartRateManager: heartRateManager)) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            Text("History")
                        }
                    }
                    
                    Button(action: {
                        heartRateManager.sendTestDataToiPhone()
                    }) {
                        HStack {
                            Image(systemName: "iphone.and.arrow.forward")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("Send Test Data")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Section("Debug - Posture Detection") - Commented out for MVP2
                /*
                Section("Debug - Posture Detection") {
                    // Current posture status
                    HStack {
                        Image(systemName: heartRateManager.isStanding ? "figure.stand" : "figure.seated.side")
                            .foregroundColor(heartRateManager.isStanding ? .green : .blue)
                            .frame(width: 20)
                        Text("Currently: \(heartRateManager.isStanding ? "Standing" : "Sitting")")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    // Manual standing button
                    Button(action: {
                        heartRateManager.manuallySetStanding(true)
                        #if canImport(WatchKit)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "figure.stand")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            Text("Set Standing")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Manual sitting button  
                    Button(action: {
                        heartRateManager.manuallySetStanding(false)
                        #if canImport(WatchKit)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "figure.seated.side")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("Set Sitting")
                                .foregroundColor(.primary)
                        }
                    }
                }
                */
                
                Section("Info") {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            Text("About")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(CarouselListStyle())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Themes View
struct ThemesView: View {
    @Binding var selectedColorTheme: Int
    let colorThemes: [ColorTheme]
    @State private var showingCustomPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Themes")
                    .font(.headline)
                    .padding(.top)
                
                // Background selector - first option
                NavigationLink(destination: BackgroundThemeView()) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("Background")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                // BPM text color selector - second option
                NavigationLink(destination: BPMTextColorView()) {
                    HStack {
                        Image(systemName: "textformat.123")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("BPM Text Color")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Heart Rate Colors")
                    .font(.headline)
                    .padding(.top)
                
                VStack(spacing: 8) {
                    ForEach(0..<colorThemes.count, id: \.self) { index in
                        ThemeSelectionRow(
                            theme: colorThemes[index],
                            isSelected: selectedColorTheme == index,
                            onTap: {
                                selectedColorTheme = index
                                // Show custom picker if Custom theme is selected
                                if index == colorThemes.count - 1 {
                                    showingCustomPicker = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                
                // Show edit button for custom theme
                if selectedColorTheme == colorThemes.count - 1 {
                    NavigationLink(destination: CustomColorPickerView()) {
                        Text("Edit Custom Colors")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 8)
                    }
                }
                
                // Preview of current theme
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if selectedColorTheme == colorThemes.count - 1 {
                        // Custom theme preview
                        HStack(spacing: 12) {
                            ThemePreviewDot(color: Color(hex: UserDefaults.standard.string(forKey: "customLowColor") ?? "#007AFF") ?? .blue, label: "Low")
                            ThemePreviewDot(color: Color(hex: UserDefaults.standard.string(forKey: "customNormalColor") ?? "#34C759") ?? .green, label: "Normal")
                            ThemePreviewDot(color: Color(hex: UserDefaults.standard.string(forKey: "customElevatedColor") ?? "#FFCC00") ?? .yellow, label: "High")
                        }
                    } else {
                        HStack(spacing: 12) {
                            ThemePreviewDot(color: colorThemes[selectedColorTheme].lowColor, label: "Low")
                            ThemePreviewDot(color: colorThemes[selectedColorTheme].normalColor, label: "Normal")
                            ThemePreviewDot(color: colorThemes[selectedColorTheme].elevatedColor, label: "High")
                        }
                    }
                }
                .padding(.top)
            }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - History View
struct HistoryView: View {
    @ObservedObject var heartRateManager: HeartRateManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(heartRateManager.heartRateHistory.prefix(20)) { reading in
                    HStack(spacing: 3) {
                        // Heart rate color indicator
                        Circle()
                            .fill(colorForHeartRate(reading.heartRate))
                            .frame(width: 6, height: 6)
                        
                        // BPM
                        Text("\(reading.heartRate) BPM")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 45, alignment: .leading)
                        
                        // Sitting/Standing icon - Commented out for MVP2
                        /*
                        if let context = reading.context {
                            Image(systemName: context.contains("Standing") ? "figure.stand" : "figure.seated.side")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .frame(width: 12, alignment: .center)
                        } else {
                            Text("—")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                                .frame(width: 12, alignment: .center)
                        }
                        */
                        
                        // Delta indicator  
                        if !reading.deltaText.isEmpty {
                            Text(reading.deltaText)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(reading.delta > 0 ? .red : .green)
                                .frame(width: 20, alignment: .center)
                        } else {
                            Text("—")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                                .frame(width: 20, alignment: .center)
                        }
                        
                        Spacer()
                        
                        // Time
                        Text(formatTime(reading.timestamp))
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
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

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App Icon/Logo area
                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                    .padding(.top, 20)
                
                Text("Heart")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Secure Health Suite")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack(spacing: 12) {
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Monitor your heart rate with beautiful themes and customizable watch faces.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                .padding(.top, 10)
                
                // Contact Information
                VStack(spacing: 8) {
                    Text("Contact")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("kindcode.us")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 15)
                
                Spacer()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Color Theme Struct
struct ColorTheme {
    let name: String
    let lowColor: Color
    let normalColor: Color
    let elevatedColor: Color
    let highColor: Color
    let noReadingColor: Color
}

struct ThemeSelectionRow: View {
    let theme: ColorTheme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Circle().fill(theme.lowColor).frame(width: 12, height: 12)
                    Circle().fill(theme.normalColor).frame(width: 12, height: 12)
                    Circle().fill(theme.elevatedColor).frame(width: 12, height: 12)
                    Circle().fill(theme.highColor).frame(width: 12, height: 12)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(isSelected ? 0.3 : 0.15))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

struct ThemePreviewDot: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Custom Color Picker View
struct CustomColorPickerView: View {
    @AppStorage("customLowColor") private var customLowColorHex = "#007AFF"
    @AppStorage("customNormalColor") private var customNormalColorHex = "#34C759"
    @AppStorage("customElevatedColor") private var customElevatedColorHex = "#FFCC00"
    @AppStorage("customHighColor") private var customHighColorHex = "#FF3B30"
    
    // Simple preset colors for easy selection
    let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown,
        .white, .gray, .black,
        // Sunset Terra palette
        Color(hex: "#F9EEE2") ?? .white, // Cream
        Color(hex: "#FFC8BC") ?? .pink,  // Coral Pink
        Color(hex: "#DDB398") ?? .brown, // Warm Brown
        Color(hex: "#F8E0D2") ?? .pink,  // Peachy Cream
        Color(hex: "#F8C5AD") ?? .orange, // Salmon
        // Gelato Days palette
        Color(hex: "#FFCBC1") ?? .pink,  // Soft Coral
        Color(hex: "#9DE550") ?? .green, // Lime Green
        Color(hex: "#FFE1A8") ?? .yellow, // Pale Yellow
        Color(hex: "#8CD9EC") ?? .cyan,  // Sky Blue
        Color(hex: "#DCC6EC") ?? .purple, // Lavender
        Color(hex: "#FFD084") ?? .orange // Peach
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Custom Colors")
                    .font(.headline)
                    .padding(.top)
                
                // Low Heart Rate Color
                ColorPickerRow(
                    title: "Low (< 80 BPM)",
                    selectedColorHex: $customLowColorHex,
                    presetColors: presetColors
                )
                
                // Normal Heart Rate Color
                ColorPickerRow(
                    title: "Normal (80-120)",
                    selectedColorHex: $customNormalColorHex,
                    presetColors: presetColors
                )
                
                // Elevated Heart Rate Color
                ColorPickerRow(
                    title: "Elevated (120-150)",
                    selectedColorHex: $customElevatedColorHex,
                    presetColors: presetColors
                )
                
                // High Heart Rate Color
                ColorPickerRow(
                    title: "High (> 150)",
                    selectedColorHex: $customHighColorHex,
                    presetColors: presetColors
                )
                
                // Preview
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: customLowColorHex) ?? .blue)
                            .frame(width: 30, height: 30)
                        Circle()
                            .fill(Color(hex: customNormalColorHex) ?? .green)
                            .frame(width: 30, height: 30)
                        Circle()
                            .fill(Color(hex: customElevatedColorHex) ?? .yellow)
                            .frame(width: 30, height: 30)
                        Circle()
                            .fill(Color(hex: customHighColorHex) ?? .red)
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.top)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Custom Colors")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var selectedColorHex: String
    let presetColors: [Color]
    @State private var showingPicker = false
    
    var currentColor: Color {
        Color(hex: selectedColorHex) ?? .gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Circle()
                    .fill(currentColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Color grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(presetColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .scaleEffect(currentColor == color ? 1.2 : 1.0)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedColorHex = color.toHex()
                            }
                        }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - BPM Text Color View
struct BPMTextColorView: View {
    @AppStorage("bpmTextColor") private var selectedBPMTextColor = 12 // Default to white
    
    // All the same colors as background picker
    let bpmTextColors: [Color] = [
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
    
    var currentBPMTextColor: Color {
        if selectedBPMTextColor < bpmTextColors.count {
            return bpmTextColors[selectedBPMTextColor]
        }
        return .white
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("BPM Text Colors")
                    .font(.headline)
                    .padding(.top)
                
                // BPM text color picker row
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("BPM Number Color")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Circle()
                            .fill(currentBPMTextColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Color grid (exactly like Custom color picker)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(Array(bpmTextColors.enumerated()), id: \.offset) { index, color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(selectedBPMTextColor == index ? Color.white : Color.white.opacity(0.3), 
                                               lineWidth: selectedBPMTextColor == index ? 2 : 1)
                                )
                                .scaleEffect(selectedBPMTextColor == index ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedBPMTextColor == index)
                                .onTapGesture {
                                    selectedBPMTextColor = index
                                }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                )
                
                // Preview section
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 2) {
                        Text("95")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(currentBPMTextColor)
                        
                        Text("BPM")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(currentBPMTextColor.opacity(0.8))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                    )
                }
                .padding(.top)
                
                // Tips section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips:")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.gray)
                        Text("Choose colors that contrast well with your background")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.gray)
                        Text("White works best on dark backgrounds, black on light ones")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .padding(.horizontal)
        }
        .navigationTitle("BPM Text Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView(heartRateManager: HeartRateManager())
}
