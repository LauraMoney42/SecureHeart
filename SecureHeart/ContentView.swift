//
//  ContentView.swift
//  Secure Heart
//
//  Main application view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var emergencyManager = EmergencyContactsManager()
    @StateObject private var simplifiedEmergencyManager = SimplifiedEmergencyContactsManager()
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    // Emergency threshold settings
    @AppStorage("emergencyHighBPM") private var highBPM: Double = 150
    @AppStorage("emergencyLowBPM") private var lowBPM: Double = 40

    // POTS Emergency Alert States
    @State private var showEmergencyConfirmation = false
    @State private var emergencyHeartRate = 0
    @State private var emergencyType = ""
    @State private var emergencyDetails = ""
    @AppStorage("rapidIncreaseEnabled") private var rapidIncreaseEnabled = true
    @AppStorage("rapidIncreaseBPM") private var rapidIncreaseBPM: Double = 30
    @AppStorage("extremeSpikeEnabled") private var extremeSpikeEnabled = true
    @AppStorage("extremeSpikeBPM") private var extremeSpikeBPM: Double = 40
    
    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardView(healthManager: healthManager)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }
                .tag(0)
            
            // Data Tab
            DataTabView(healthManager: healthManager)
                .tabItem {
                    Label("Data", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            // Settings Tab
            SettingsTabView()
                .environmentObject(emergencyManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onAppear {
            healthManager.requestAuthorization()
            // Initialize WatchConnectivity to receive data from Apple Watch
            _ = WatchConnectivityManager.shared
            print("📱 [iPhone] Initialized WatchConnectivity to receive data from Watch")
            
            // Monitor heart rate for POTS-aware emergency conditions with confirmation dialogs
            healthManager.emergencyThresholdCallback = { heartRate in
                let heartRateInt = Int(heartRate)

                // Determine emergency type and trigger confirmation dialog
                if heartRateInt > Int(self.highBPM) {
                    self.emergencyHeartRate = heartRateInt
                    self.emergencyType = "High Heart Rate Alert"
                    self.showEmergencyConfirmation = true
                } else if heartRateInt < Int(self.lowBPM) {
                    self.emergencyHeartRate = heartRateInt
                    self.emergencyType = "Low Heart Rate Alert"
                    self.showEmergencyConfirmation = true
                }
            }

            // Monitor for POTS-specific patterns (rapid increases)
            healthManager.rapidIncreaseCallback = { currentHR, baselineHR, timeSpanSeconds in
                let increase = currentHR - baselineHR
                let timeMinutes = Int(timeSpanSeconds / 60)

                if timeSpanSeconds <= 300 && increase >= Int(self.extremeSpikeBPM) {
                    // Extreme spike: +40 BPM in 5 minutes
                    self.emergencyHeartRate = currentHR
                    self.emergencyType = "POTS Extreme Spike"
                    self.emergencyDetails = "+\(increase) BPM in \(timeMinutes) minutes (from \(baselineHR) to \(currentHR))"
                    self.showEmergencyConfirmation = true
                } else if timeSpanSeconds <= 600 && increase >= Int(self.rapidIncreaseBPM) {
                    // Rapid increase: +30 BPM in 10 minutes (POTS diagnostic criteria)
                    self.emergencyHeartRate = currentHR
                    self.emergencyType = "POTS Rapid Increase"
                    self.emergencyDetails = "+\(increase) BPM in \(timeMinutes) minutes (from \(baselineHR) to \(currentHR))"
                    self.showEmergencyConfirmation = true
                }
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .alert(emergencyType, isPresented: $showEmergencyConfirmation) {
            Button("Cancel", role: .cancel) {
                // User cancelled - no emergency alert sent
                print("🚫 [iPhone] Emergency alert cancelled by user")
            }
            Button("Send Alert", role: .destructive) {
                // User confirmed - send emergency alert with POTS context
                print("🚨 [iPhone] Emergency alert confirmed by user - sending to contacts")
                Task {
                    do {
                        try await simplifiedEmergencyManager.triggerEmergency(
                            heartRate: emergencyHeartRate,
                            includeLocation: true
                        )
                    } catch {
                        print("❌ [iPhone] Failed to send emergency alert: \(error)")
                    }
                }
            }
        } message: {
            if emergencyDetails.isEmpty {
                Text("Heart rate: \(emergencyHeartRate) BPM\n\nDo you want to alert your emergency contacts? This will send your location and heart rate data.")
            } else {
                Text("Heart rate: \(emergencyHeartRate) BPM\n\(emergencyDetails)\n\nDo you want to alert your emergency contacts? This will send your location and heart rate data.")
            }
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Heart Rate Card
                    HeartRateCard(healthManager: healthManager)
                    
                    // Delta Monitoring Card (Standing Response) - Commented out for MVP2
                    // DeltaMonitoringCard(healthManager: healthManager)
                    
                    // Quick Stats
                    QuickStatsView(healthManager: healthManager)
                    
                    // Orthostatic Graph
                    if !healthManager.orthostaticEvents.isEmpty {
                        OrthostaticGraphView(healthManager: healthManager)
                    }
                    
                    // Daily Graph
                    DailyHeartRateGraphView(healthManager: healthManager)
                    
                    // Orthostatic Vital Signs Chart
                    OrthosticVitalSignsChart(healthManager: healthManager)
                }
                .padding()
            }
            .navigationTitle("Secure Heart")
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

// MARK: - Delta Monitoring Card (Standing Response) - Commented out for MVP2
/*
struct DeltaMonitoringCard: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Standing Response")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(healthManager.currentHeartRate)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Recent Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(healthManager.recentAverageHeartRate)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Delta")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("\(healthManager.deltaFromAverage > 0 ? "+" : "")\(healthManager.deltaFromAverage)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(healthManager.getDeltaColor())
                            Text("BPM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Delta Status Bar
                if healthManager.isDeltaSignificant() {
                    HStack {
                        Image(systemName: healthManager.getDeltaIcon())
                            .foregroundColor(healthManager.getDeltaColor())
                        Text(healthManager.getDeltaDescription())
                            .font(.subheadline)
                            .foregroundColor(healthManager.getDeltaColor())
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(healthManager.getDeltaColor().opacity(0.1))
                    .cornerRadius(8)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Heart rate stable (within ±30 BPM)")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
*/

// MARK: - Heart Rate Zone Indicator
struct HeartRateZoneIndicator: View {
    @ObservedObject var healthManager: HealthManager
    let heartRate: Int
    
    var body: some View {
        HStack {
            ForEach(["Low", "Normal", "Elevated", "High", "Max"], id: \.self) { zone in
                Rectangle()
                    .fill(colorForZone(zone, heartRate: heartRate))
                    .frame(height: 8)
                    .cornerRadius(4)
            }
        }
    }
    
    private func colorForZone(_ zone: String, heartRate: Int) -> Color {
        switch zone {
        case "Low":
            return heartRate < 60 ? .blue : .gray.opacity(0.3)
        case "Normal":
            return (60..<100).contains(heartRate) ? .green : .gray.opacity(0.3)
        case "Elevated":
            return (100..<140).contains(heartRate) ? .orange : .gray.opacity(0.3)
        case "High":
            return (140..<170).contains(heartRate) ? .red : .gray.opacity(0.3)
        case "Max":
            return heartRate >= 170 ? .purple : .gray.opacity(0.3)
        default:
            return .gray
        }
    }
}

// WatchStatusCard moved to Views/SettingsView.swift

// MARK: - Quick Stats View
struct QuickStatsView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "Average", value: "\(healthManager.averageHeartRate)", unit: "BPM", color: .blue)
            StatCard(title: "Min", value: "\(healthManager.minHeartRate)", unit: "BPM", color: .green)  
            StatCard(title: "Max", value: "\(healthManager.maxHeartRate)", unit: "BPM", color: .red)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.primary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Orthostatic Graph View  
struct OrthostaticGraphView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Orthostatic Patterns")
                    .font(.headline)
                Spacer()
                Text("(\(healthManager.orthostaticEvents.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if healthManager.orthostaticEvents.isEmpty {
                        // Show empty state cards
                        ForEach(0..<3, id: \.self) { _ in
                            EmptyOrthostaticPatternCard()
                        }
                    } else {
                        ForEach(healthManager.orthostaticEvents.prefix(5)) { event in
                            OrthostaticPatternCard(event: event)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Daily Heart Rate Graph
struct DailyHeartRateGraphView: View {
    @ObservedObject var healthManager: HealthManager
    
    @State private var showingGraphExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Heart Rate")
                    .font(.headline)

                Spacer()

                Button(action: {
                    showingGraphExport = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            ImprovedDailyGraph(healthManager: healthManager)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingGraphExport) {
            GraphExportSheet(healthManager: healthManager)
        }
    }
}

// MARK: - Orthostatic Vital Signs Chart
struct OrthosticVitalSignsChart: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with medical context
            HStack {
                Text("Orthostatic Vital Signs")
                    .font(.headline)
                Spacer()
                // Text("Supine → Standing") - Commented out for MVP2
                //     .font(.caption)
                //     .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            OrthosticChartContent(healthManager: healthManager)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct OrthosticChartContent: View {
    @ObservedObject var healthManager: HealthManager
    @State private var selectedEventIndex = 0
    
    // Use real orthostatic events from HealthManager
    var orthostaticEvents: [(startTime: String, endTime: String, data: [(time: String, supineHR: Int, standingHR: Int, delta: Int)])] {
        // Convert real orthostatic events to chart format
        return healthManager.orthostaticEvents.map { event in
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let startTime = formatter.string(from: event.timestamp)
            let endTime = formatter.string(from: event.timestamp.addingTimeInterval(600)) // +10 minutes

            return (
                startTime: startTime,
                endTime: endTime,
                data: [
                    (time: "Baseline", supineHR: event.baselineHeartRate, standingHR: event.baselineHeartRate, delta: 0),
                    (time: "Peak", supineHR: event.baselineHeartRate, standingHR: event.peakHeartRate, delta: event.peakHeartRate - event.baselineHeartRate)
                ]
            )
        }
    }
    
    var currentEvent: (startTime: String, endTime: String, data: [(time: String, supineHR: Int, standingHR: Int, delta: Int)])? {
        guard !orthostaticEvents.isEmpty && selectedEventIndex < orthostaticEvents.count else { return nil }
        return orthostaticEvents[selectedEventIndex]
    }

    var orthostaticTestData: [(time: String, supineHR: Int, standingHR: Int, delta: Int)] {
        currentEvent?.data ?? []
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Show empty state if no orthostatic events
            if orthostaticEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        Text("No Orthostatic Events")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Orthostatic responses will appear here when detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            } else {
                // Event selector if multiple events exist
                if orthostaticEvents.count > 1 {
                HStack {
                    Text("Event:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(orthostaticEvents.enumerated()), id: \.offset) { index, event in
                                Button(action: {
                                    selectedEventIndex = index
                                }) {
                                    VStack(spacing: 2) {
                                        Text(event.startTime)
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(event.data.last?.delta ?? 0 >= 30 ? "Elevated" : "Normal")
                                            .font(.system(size: 9))
                                            .foregroundColor(event.data.last?.delta ?? 0 >= 30 ? .orange : .green)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedEventIndex == index ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Main chart
            HStack(spacing: 8) {
                // Y-axis BPM labels
                VStack(alignment: .trailing, spacing: 0) {
                    Text("140").font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    Text("120").font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    Text("100").font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    Text("80").font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    Text("60").font(.system(size: 9)).foregroundColor(.secondary)
                }
                .frame(width: 25, height: 150)
                
                // Chart area
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let minHR = 60
                    let maxHR = 140
                    let range = maxHR - minHR
                    
                    ZStack {
                        // Background zones
                        VStack(spacing: 0) {
                            // Tachycardia zone (>100 BPM)
                            Rectangle()
                                .fill(Color.red.opacity(0.05))
                                .frame(height: height * 0.5)
                            // Normal zone (60-100 BPM)
                            Rectangle()
                                .fill(Color.green.opacity(0.05))
                                .frame(height: height * 0.5)
                        }
                        
                        // Response threshold line at +30 BPM from baseline
                        let thresholdLineY = height * (1 - CGFloat(100 - minHR) / CGFloat(range))
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: thresholdLineY))
                            path.addLine(to: CGPoint(x: width, y: thresholdLineY))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundColor(.orange)
                        
                        // Supine (baseline) line
                        Path { path in
                            let baselineY = height * (1 - CGFloat(70 - minHR) / CGFloat(range))
                            for (index, _) in orthostaticTestData.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(max(orthostaticTestData.count - 1, 1))
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: baselineY))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: baselineY))
                                }
                            }
                        }
                        .stroke(Color.blue, lineWidth: 2)
                        
                        // Standing HR line
                        Path { path in
                            for (index, dataPoint) in orthostaticTestData.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(max(orthostaticTestData.count - 1, 1))
                                let y = height * (1 - CGFloat(dataPoint.standingHR - minHR) / CGFloat(range))

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.red, lineWidth: 2)
                        
                        // Data points
                        ForEach(Array(orthostaticTestData.enumerated()), id: \.offset) { index, dataPoint in
                            let x = width * CGFloat(index) / CGFloat(max(orthostaticTestData.count - 1, 1))
                            let standingY = height * (1 - CGFloat(dataPoint.standingHR - minHR) / CGFloat(range))
                            let supineY = height * (1 - CGFloat(dataPoint.supineHR - minHR) / CGFloat(range))
                            
                            // Standing point
                            Circle()
                                .fill(dataPoint.delta >= 30 ? Color.orange : Color.red)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: standingY)
                            
                            // Supine point
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: supineY)
                        }
                        
                        // Response threshold label
                        Text("Response Threshold (+30)")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                            .position(x: width - 50, y: thresholdLineY - 8)
                    }
                }
                .frame(height: 150)
            }
            
            // Time axis
            HStack {
                ForEach(orthostaticTestData, id: \.time) { dataPoint in
                    Text(dataPoint.time)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 33)
            
            // Test timestamps
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Started:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(currentEvent?.startTime ?? "No data")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Duration:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("10 minutes")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ended:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(currentEvent?.endTime ?? "No data")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 33)
            .padding(.top, 4)
            
            // Clinical interpretation
            VStack(spacing: 8) {
                // Delta values row
                HStack {
                    Text("ΔHR:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(orthostaticTestData, id: \.time) { dataPoint in
                        Text("+\(dataPoint.delta)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(dataPoint.delta >= 30 ? .orange : (dataPoint.delta >= 20 ? .yellow : .green))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 33)
                
                // Diagnosis indicator
                HStack {
                    Image(systemName: orthostaticTestData.last?.delta ?? 0 >= 30 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(orthostaticTestData.last?.delta ?? 0 >= 30 ? .orange : .green)
                        .font(.system(size: 12))
                    
                    Text(getDiagnosticInterpretation())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(orthostaticTestData.last?.delta ?? 0 >= 30 ? .orange : .green)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((orthostaticTestData.last?.delta ?? 0 >= 30 ? Color.orange : Color.green).opacity(0.1))
                .cornerRadius(6)
            }
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("Supine").font(.system(size: 10)).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Standing").font(.system(size: 10)).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Color.orange).frame(width: 12, height: 1)
                    Text("Threshold Criteria").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 4)
            } // Close else block for orthostatic events
        }
    }
    
    private func getDiagnosticInterpretation() -> String {
        let maxDelta = orthostaticTestData.map { $0.delta }.max() ?? 0
        let sustained = orthostaticTestData.suffix(2).allSatisfy { $0.delta >= 30 }
        
        if maxDelta >= 40 && sustained {
            return "Severe orthostatic response (ΔHR ≥40 BPM sustained)"
        } else if maxDelta >= 30 && sustained {
            return "Significant orthostatic response (ΔHR ≥30 BPM sustained)"
        } else if maxDelta >= 30 {
            return "Borderline response - Transient orthostatic elevation"
        } else if maxDelta >= 20 {
            return "Mild orthostatic response - Within normal range"
        } else {
            return "Normal orthostatic response (ΔHR <20 BPM)"
        }
    }
}

struct ImprovedDailyGraph: View {
    @ObservedObject var healthManager: HealthManager
    
    var todaysEntries: [HeartRateEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return healthManager.heartRateHistory.filter { entry in
            entry.date >= today && entry.date < tomorrow
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if todaysEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.6))
                    Text("No readings today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 240)
            } else {
                // Graph with left legend
                HStack(spacing: 8) {
                    // Left BPM legend
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("150").font(.system(size: 10)).foregroundColor(.red)
                        Spacer()
                        Text("130").font(.system(size: 10)).foregroundColor(.orange)
                        Spacer()
                        Text("100").font(.system(size: 10)).foregroundColor(.orange)
                        Spacer()
                        Text("80").font(.system(size: 10)).foregroundColor(.green)
                        Spacer()
                        Text("60").font(.system(size: 10)).foregroundColor(.green)
                        Spacer()
                        Text("40").font(.system(size: 10)).foregroundColor(.blue)
                    }
                    .frame(width: 25, height: 240)

                    // Graph area
                    SimpleHeartRateGraph(entries: todaysEntries)
                        .frame(height: 240)
                }
                
                // Time axis
                SimpleTimeAxis(entries: todaysEntries)
            }
        }
    }
}

struct SimpleHeartRateGraph: View {
    let entries: [HeartRateEntry]

    // Medical-grade time-based aggregation with POTS/arrhythmia preservation
    private var sampledEntries: [HeartRateEntry] {
        guard entries.count > 50 else { return entries } // No sampling needed for small datasets

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600) // 1 hour ago

        var result: [HeartRateEntry] = []

        // Always keep ALL points from the last hour (recent detail)
        let recentEntries = entries.filter { $0.date >= oneHourAgo }

        // Process older entries with medical-aware time aggregation
        let olderEntries = entries.filter { $0.date < oneHourAgo }

        if !olderEntries.isEmpty {
            result.append(contentsOf: medicalTimeBasedSampling(olderEntries))
        }

        result.append(contentsOf: recentEntries)

        return result.sorted { $0.date < $1.date }
    }

    private func medicalTimeBasedSampling(_ entries: [HeartRateEntry]) -> [HeartRateEntry] {
        guard entries.count > 20 else { return entries }

        var result: [HeartRateEntry] = []

        // Group entries by 15-minute intervals for time-based aggregation
        let calendar = Calendar.current
        var intervalGroups: [Date: [HeartRateEntry]] = [:]

        for entry in entries {
            // Round down to nearest 15-minute interval
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
            let roundedMinute = (components.minute! / 15) * 15
            let intervalStart = calendar.date(from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: components.hour,
                minute: roundedMinute
            ))!

            if intervalGroups[intervalStart] == nil {
                intervalGroups[intervalStart] = []
            }
            intervalGroups[intervalStart]!.append(entry)
        }

        // Process each 15-minute interval
        for (intervalStart, intervalEntries) in intervalGroups.sorted(by: { $0.key < $1.key }) {
            let processedEntries = processInterval(intervalEntries, intervalStart: intervalStart)
            result.append(contentsOf: processedEntries)
        }

        return result.sorted { $0.date < $1.date }
    }

    private func processInterval(_ entries: [HeartRateEntry], intervalStart: Date) -> [HeartRateEntry] {
        guard !entries.isEmpty else { return [] }

        // Check for orthostatic events or arrhythmias in this interval
        let hasOrthostatic = detectOrthostatic(entries)
        let hasArrhythmia = detectArrhythmia(entries)

        if hasOrthostatic || hasArrhythmia {
            // Preserve ALL data points around medical events
            return entries
        } else {
            // Normal interval: use time-based aggregation (like Apple Health)
            return aggregateNormalInterval(entries, intervalStart: intervalStart)
        }
    }

    private func detectOrthostatic(_ entries: [HeartRateEntry]) -> Bool {
        // Look for POTS-like patterns: rapid HR increase ≥30 BPM within short time
        for i in 1..<entries.count {
            let current = entries[i].heartRate
            let previous = entries[i-1].heartRate
            let timeDiff = entries[i].date.timeIntervalSince(entries[i-1].date)

            // Detect rapid increase (≥30 BPM within 3 minutes = potential orthostatic change)
            if current - previous >= 30 && timeDiff <= 180 {
                return true
            }
        }
        return false
    }

    private func detectArrhythmia(_ entries: [HeartRateEntry]) -> Bool {
        // Look for irregular patterns: sudden spikes, drops, or erratic changes
        guard entries.count >= 3 else { return false }

        for i in 1..<(entries.count - 1) {
            let prev = entries[i-1].heartRate
            let current = entries[i].heartRate
            let next = entries[i+1].heartRate

            // Detect potential arrhythmia patterns
            let deltaUp = current - prev
            let deltaDown = current - next

            // Sudden spike and drop (≥40 BPM in either direction)
            if abs(deltaUp) >= 40 || abs(deltaDown) >= 40 {
                return true
            }

            // Very high HR (≥160 BPM) or very low HR (≤45 BPM)
            if current >= 160 || current <= 45 {
                return true
            }
        }
        return false
    }

    private func aggregateNormalInterval(_ entries: [HeartRateEntry], intervalStart: Date) -> [HeartRateEntry] {
        // For normal intervals, create min/max aggregation (like Apple Health)
        let sortedByHR = entries.sorted { $0.heartRate < $1.heartRate }
        let minEntry = sortedByHR.first!
        let maxEntry = sortedByHR.last!

        // If min and max are very close (≤10 BPM), just return one representative point
        if maxEntry.heartRate - minEntry.heartRate <= 10 {
            // Return the median entry
            let medianEntry = sortedByHR[sortedByHR.count / 2]
            return [HeartRateEntry(
                heartRate: medianEntry.heartRate,
                date: intervalStart.addingTimeInterval(7.5 * 60), // Middle of 15-min interval
                delta: medianEntry.delta,
                context: "Aggregated"
            )]
        } else {
            // Return both min and max for this interval
            return [
                HeartRateEntry(
                    heartRate: minEntry.heartRate,
                    date: minEntry.date,
                    delta: minEntry.delta,
                    context: minEntry.context
                ),
                HeartRateEntry(
                    heartRate: maxEntry.heartRate,
                    date: maxEntry.date,
                    delta: maxEntry.delta,
                    context: maxEntry.context
                )
            ]
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width

            // Calculate total width based on time span (1 hour = 300 points)
            let timeSpan = sampledEntries.last?.date.timeIntervalSince(sampledEntries.first?.date ?? Date()) ?? 3600
            let hoursSpan = max(1, timeSpan / 3600)
            let requiredWidth = hoursSpan * 300 // 300pt per hour

            // Only use ScrollView if content exceeds available width (roughly 2+ hours of data)
            let needsScrolling = requiredWidth > availableWidth
            let totalWidth = needsScrolling ? requiredWidth : availableWidth

            if needsScrolling {
                ScrollView(.horizontal, showsIndicators: false) {
                    GraphContent(entries: sampledEntries, width: totalWidth, height: geometry.size.height)
                }
            } else {
                GraphContent(entries: sampledEntries, width: totalWidth, height: geometry.size.height)
            }
        }
    }
}

struct GraphContent: View {
    let entries: [HeartRateEntry]
    let width: CGFloat
    let height: CGFloat

    // Use fixed range to match the legend on the left
    private var dynamicRange: (min: Int, max: Int) {
        // Fixed range from 40 to 150 BPM to match the legend
        return (min: 40, max: 150)
    }

    private var dynamicGridLines: [Int] {
        let minHR = dynamicRange.min
        let maxHR = dynamicRange.max
        let range = maxHR - minHR

        // Generate grid lines at reasonable intervals
        let interval = range <= 50 ? 10 : (range <= 100 ? 20 : 30)
        let startLine = ((minHR + interval - 1) / interval) * interval // Round up to next interval

        var lines: [Int] = []
        var currentLine = startLine
        while currentLine <= maxHR {
            if currentLine >= minHR {
                lines.append(currentLine)
            }
            currentLine += interval
        }

        return lines
    }

    var body: some View {
        let minHR = dynamicRange.min
        let maxHR = dynamicRange.max
        let range = maxHR - minHR

        ZStack {
            // Background zones aligned with fixed scale (40-150 BPM range = 110 BPM total)
            VStack(spacing: 0) {
                // Red zone: 140-150 BPM (10/110 of height)
                Rectangle().fill(Color.red.opacity(0.1)).frame(height: height * (10.0/110.0))
                // Orange zone: 100-140 BPM (40/110 of height)
                Rectangle().fill(Color.orange.opacity(0.1)).frame(height: height * (40.0/110.0))
                // Green zone: 60-100 BPM (40/110 of height)
                Rectangle().fill(Color.green.opacity(0.1)).frame(height: height * (40.0/110.0))
                // Blue zone: 40-60 BPM (20/110 of height)
                Rectangle().fill(Color.blue.opacity(0.1)).frame(height: height * (20.0/110.0))
            }
            .frame(width: width)
            .cornerRadius(4)

            // Dynamic grid lines
            ForEach(dynamicGridLines, id: \.self) { bpm in
                let y = height * (1 - CGFloat(bpm - minHR) / CGFloat(range))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            }

            // Heart rate line
            if !entries.isEmpty {
                HeartRatePath(entries: entries, width: width, height: height, minHR: minHR, maxHR: maxHR)
                    .stroke(Color.red.opacity(0.8), lineWidth: 2)
            }
        }
    }
}

struct HeartRatePath: Shape {
    let entries: [HeartRateEntry]
    let width: CGFloat
    let height: CGFloat
    let minHR: Int
    let maxHR: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard !entries.isEmpty else { return path }

        let range = maxHR - minHR
        let timeSpan = entries.last?.date.timeIntervalSince(entries.first?.date ?? Date()) ?? 3600

        for (index, entry) in entries.enumerated() {
            let x: CGFloat
            if timeSpan > 0 {
                let timeProgress = entry.date.timeIntervalSince(entries.first?.date ?? Date()) / timeSpan
                x = rect.width * CGFloat(timeProgress)
            } else {
                x = rect.width * CGFloat(index) / CGFloat(max(entries.count - 1, 1))
            }

            // Clamp heart rate to valid range to prevent rendering outside bounds
            let clampedHR = max(minHR, min(maxHR, entry.heartRate))
            let y = rect.height * (1 - CGFloat(clampedHR - minHR) / CGFloat(range))

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

struct SimpleTimeAxis: View {
    let entries: [HeartRateEntry]
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            if let first = entries.first, let last = entries.last {
                Text(timeFormatter.string(from: first.date))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if entries.count > 2 {
                    let mid = entries[entries.count / 2]
                    Text(timeFormatter.string(from: mid.date))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(timeFormatter.string(from: last.date))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 33)
    }
}

struct HeartRateZoneBackground: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.red.opacity(0.1)).frame(height: height * 0.2)
            Rectangle().fill(Color.orange.opacity(0.1)).frame(height: height * 0.3)
            Rectangle().fill(Color.green.opacity(0.1)).frame(height: height * 0.3)
            Rectangle().fill(Color.blue.opacity(0.1)).frame(height: height * 0.2)
        }
        .cornerRadius(8)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyOrthostaticPatternCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand")
                .font(.title)
                .foregroundColor(.gray.opacity(0.4))
            
            Text("No Events")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("--")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
        }
        .frame(width: 100, height: 80)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct OrthostaticPatternCard: View {
    let event: OrthostaticEvent
    
    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("+\(event.increase)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorForSeverity(event.severity))
                
                Text("BPM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(event.formattedTime)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(event.sustainedMinutes)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 100, height: 80)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForSeverity(event.severity).opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "mild":
            return .green
        case "moderate":
            return .orange
        case "severe":
            return .red
        default:
            return .gray
        }
    }
}

struct OrthostaticTimelineView: View {
    let events: [OrthostaticEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(events.prefix(3)) { event in
                HStack {
                    Circle()
                        .fill(colorForSeverity(event.severity))
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("+\(event.increase) BPM")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if event.sustainedDuration >= 600 {
                                Text("• Sustained")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(event.severity.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(colorForSeverity(event.severity))
                        
                        if event.isRecovered {
                            Text("✓")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                if event.id != events.prefix(3).last?.id {
                    Divider()
                }
            }
        }
    }
    
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "mild":
            return .green
        case "moderate":
            return .orange
        case "severe":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Graph Export Sheet

struct GraphExportSheet: View {
    @ObservedObject var healthManager: HealthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Export Today's Heart Rate Graph") {
                    Button(action: {
                        exportGraphAsPDF()
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.red)
                                .font(.title2)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Export as PDF")
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                Text("High-quality vector format")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        exportGraphAsImage()
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                                .font(.title2)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Export as Image")
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                Text("PNG format for sharing")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Export Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportGraphAsPDF() {
        print("🔄 [GRAPH] Starting graph PDF export...")

        guard let pdfData = generateGraphPDF() else {
            print("❌ [GRAPH] Failed to generate graph PDF - generateGraphPDF() returned nil")
            return
        }

        print("✅ [GRAPH] Graph PDF generated successfully, size: \(pdfData.count) bytes")

        if pdfData.isEmpty {
            print("⚠️ [GRAPH] Warning: PDF data is empty!")
        }

        // Dismiss first, then present after a delay
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let activityViewController = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
            activityViewController.setValue("SecureHeart_Graph.pdf", forKey: "subject")

            // Find the main app window and present from there
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootViewController = keyWindow.rootViewController {

                // For iPad
                if let popover = activityViewController.popoverPresentationController {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }

                rootViewController.present(activityViewController, animated: true) {
                    print("✅ [GRAPH] Graph PDF activity controller presented successfully")
                }
            } else {
                print("❌ [GRAPH] Could not find key window or root view controller")
            }
        }
    }

    private func exportGraphAsImage() {
        print("🔄 [GRAPH] Starting graph image export...")

        guard let imageData = generateGraphImage() else {
            print("❌ [GRAPH] Failed to generate graph image")
            return
        }

        print("✅ [GRAPH] Graph image generated successfully, size: \(imageData.count) bytes")

        // Dismiss first, then present after a delay
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let activityViewController = UIActivityViewController(activityItems: [imageData], applicationActivities: nil)
            activityViewController.setValue("SecureHeart_Graph.png", forKey: "subject")

            // Find the main app window and present from there
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootViewController = keyWindow.rootViewController {

                // For iPad
                if let popover = activityViewController.popoverPresentationController {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }

                rootViewController.present(activityViewController, animated: true) {
                    print("✅ [GRAPH] Graph image activity controller presented successfully")
                }
            } else {
                print("❌ [GRAPH] Could not find key window or root view controller")
            }
        }
    }

    private func generateGraphPDF() -> Data? {
        print("📄 [GRAPH] Starting graph PDF generation...")

        let todaysEntries = getTodaysHeartRateData()
        print("📄 [GRAPH] Got \(todaysEntries.count) entries for today")

        if todaysEntries.isEmpty {
            print("⚠️ [GRAPH] No data available for PDF generation")
            return nil
        }

        // Simple single-page PDF (revert to original working approach)
        let pageSize = CGSize(width: 792, height: 612) // 11 x 8.5 inches (landscape)
        let pageFormat = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: pageFormat)

        return renderer.pdfData { context in
            context.beginPage()

            let title = "Today's Heart Rate Graph"
            let titleFont = UIFont.boldSystemFont(ofSize: 20)
            let subtitleFont = UIFont.systemFont(ofSize: 12)

            var yPosition: CGFloat = 40

            // Title
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 30

            // Subtitle with date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            let subtitle = "Generated on \(dateFormatter.string(from: Date()))"
            subtitle.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: subtitleFont,
                .foregroundColor: UIColor.gray
            ])
            yPosition += 35

            // Generate the graph
            let graphRect = CGRect(x: 50, y: yPosition, width: pageSize.width - 100, height: pageSize.height - yPosition - 80)
            renderSimpleGraphInRect(todaysEntries, in: graphRect, context: context.cgContext)

            // Footer
            let footer = "Generated by Secure Heart - Privacy-First Heart Rate Monitoring"
            let footerY = pageSize.height - 25
            footer.draw(at: CGPoint(x: 50, y: footerY), withAttributes: [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ])

            print("📄 [GRAPH] Single-page PDF rendering completed")
        }
    }

    private func renderSimpleGraphInRect(_ entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        print("📊 [GRAPH] Rendering simple graph with \(entries.count) entries")

        guard !entries.isEmpty else {
            let message = "No heart rate data available"
            let messageFont = UIFont.systemFont(ofSize: 16)
            let messageAttributes: [NSAttributedString.Key: Any] = [
                .font: messageFont,
                .foregroundColor: UIColor.gray
            ]

            let messageSize = message.size(withAttributes: messageAttributes)
            let messageX = rect.midX - messageSize.width / 2
            let messageY = rect.midY - messageSize.height / 2

            message.draw(at: CGPoint(x: messageX, y: messageY), withAttributes: messageAttributes)
            return
        }

        // Draw background zones
        drawHeartRateZones(in: rect, context: context)

        // Draw grid lines
        drawGridLines(in: rect, context: context)

        // Draw the heart rate line
        drawSimpleHeartRateLine(entries: entries, in: rect, context: context)

        // Draw axis labels
        drawSimpleAxisLabels(entries: entries, in: rect, context: context)
    }

    private func drawSimpleHeartRateLine(entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        guard !entries.isEmpty else { return }

        let minHR: CGFloat = 40
        let maxHR: CGFloat = 150
        let range = maxHR - minHR

        let startTime = entries.first!.date
        let endTime = entries.last!.date
        let duration = endTime.timeIntervalSince(startTime)

        print("📊 [GRAPH] Drawing simple line: \(entries.count) entries, duration: \(duration)s")

        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(2.0)

        let path = CGMutablePath()
        var isFirstPoint = true

        for (index, entry) in entries.enumerated() {
            let timeProgress: CGFloat
            if duration > 0 {
                timeProgress = entry.date.timeIntervalSince(startTime) / duration
            } else {
                timeProgress = entries.count > 1 ? CGFloat(index) / CGFloat(entries.count - 1) : 0.5
            }

            let x = rect.minX + timeProgress * rect.width
            let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.addPath(path)
        context.strokePath()

        // Draw points
        context.setFillColor(UIColor.systemBlue.cgColor)
        for (index, entry) in entries.enumerated() {
            let timeProgress: CGFloat
            if duration > 0 {
                timeProgress = entry.date.timeIntervalSince(startTime) / duration
            } else {
                timeProgress = entries.count > 1 ? CGFloat(index) / CGFloat(entries.count - 1) : 0.5
            }

            let x = rect.minX + timeProgress * rect.width
            let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

            let pointRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            context.fillEllipse(in: pointRect)
        }
    }

    private func drawSimpleAxisLabels(entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        guard !entries.isEmpty else { return }

        let labelFont = UIFont.boldSystemFont(ofSize: 12)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]

        // Y-axis labels (heart rate)
        let hrLabels = [40, 60, 80, 100, 120, 140]
        for hr in hrLabels {
            let y = rect.maxY - (CGFloat(hr - 40) / 110.0) * rect.height
            let label = "\(hr)"
            let labelSize = label.size(withAttributes: labelAttributes)
            label.draw(at: CGPoint(x: rect.minX - labelSize.width - 10, y: y - labelSize.height / 2), withAttributes: labelAttributes)
        }

        // X-axis labels (time)
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let startTime = entries.first!.date
        let endTime = entries.last!.date

        // Show start and end times
        let startLabel = timeFormatter.string(from: startTime)
        let endLabel = timeFormatter.string(from: endTime)

        let startSize = startLabel.size(withAttributes: labelAttributes)
        let endSize = endLabel.size(withAttributes: labelAttributes)

        startLabel.draw(at: CGPoint(x: rect.minX, y: rect.maxY + 10), withAttributes: labelAttributes)
        endLabel.draw(at: CGPoint(x: rect.maxX - endSize.width, y: rect.maxY + 10), withAttributes: labelAttributes)

        // Y-axis title
        let yAxisTitle = "Heart Rate (BPM)"
        context.saveGState()
        context.translateBy(x: 15, y: rect.midY)
        context.rotate(by: -CGFloat.pi / 2)
        let yTitleSize = yAxisTitle.size(withAttributes: labelAttributes)
        yAxisTitle.draw(at: CGPoint(x: -yTitleSize.width / 2, y: -yTitleSize.height / 2), withAttributes: labelAttributes)
        context.restoreGState()

        // X-axis title
        let xAxisTitle = "Time"
        let xTitleSize = xAxisTitle.size(withAttributes: labelAttributes)
        xAxisTitle.draw(at: CGPoint(x: rect.midX - xTitleSize.width / 2, y: rect.maxY + 35), withAttributes: labelAttributes)
    }

    private func splitIntoFourHourChunks(_ entries: [HeartRateEntry]) -> [[HeartRateEntry]] {
        guard !entries.isEmpty else { return [] }

        var chunks: [[HeartRateEntry]] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: entries.first!.date)

        // Create 4-hour time windows (0-4, 4-8, 8-12, 12-16, 16-20, 20-24)
        for hourOffset in stride(from: 0, to: 24, by: 4) {
            let chunkStart = calendar.date(byAdding: .hour, value: hourOffset, to: startOfDay)!
            let chunkEnd = calendar.date(byAdding: .hour, value: hourOffset + 4, to: startOfDay)!

            let chunkEntries = entries.filter { entry in
                entry.date >= chunkStart && entry.date < chunkEnd
            }

            if !chunkEntries.isEmpty {
                chunks.append(chunkEntries)
            }
        }

        return chunks
    }

    private func renderChunkGraphInRect(_ entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        print("📊 [GRAPH] Rendering 4-hour chunk with \(entries.count) entries")

        if entries.isEmpty {
            // Draw "No data available" message
            let message = "No heart rate data for this time period"
            let messageFont = UIFont.systemFont(ofSize: 16)
            let messageAttributes: [NSAttributedString.Key: Any] = [
                .font: messageFont,
                .foregroundColor: UIColor.gray
            ]

            let messageSize = message.size(withAttributes: messageAttributes)
            let messageX = rect.midX - messageSize.width / 2
            let messageY = rect.midY - messageSize.height / 2

            message.draw(at: CGPoint(x: messageX, y: messageY), withAttributes: messageAttributes)
            return
        }

        // Draw background zones
        drawHeartRateZones(in: rect, context: context)

        // Draw grid lines
        drawGridLines(in: rect, context: context)

        // Draw the heart rate line for this chunk
        drawChunkHeartRateLine(entries: entries, in: rect, context: context)

        // Draw axis labels with 4-hour time range
        drawChunkAxisLabels(entries: entries, in: rect, context: context)
    }

    private func drawChunkHeartRateLine(entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        guard !entries.isEmpty else {
            print("⚠️ [GRAPH] No entries to draw in chunk")
            return
        }

        let minHR: CGFloat = 40
        let maxHR: CGFloat = 150
        let range = maxHR - minHR

        let chunkStart = entries.first!.date
        let chunkEnd = entries.last!.date
        let chunkDuration = chunkEnd.timeIntervalSince(chunkStart)

        print("📊 [GRAPH] Drawing chunk: \(entries.count) entries, duration: \(chunkDuration)s")

        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(3.0)

        let path = CGMutablePath()
        var isFirstPoint = true

        // Handle case where all data points have the same timestamp
        if chunkDuration <= 0 {
            print("⚠️ [GRAPH] Zero duration chunk detected, spacing points evenly")

            // Space points evenly across the rect width
            for (index, entry) in entries.enumerated() {
                let timeProgress = entries.count > 1 ? CGFloat(index) / CGFloat(entries.count - 1) : 0.5
                let x = rect.minX + timeProgress * rect.width
                let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

                if isFirstPoint {
                    path.move(to: CGPoint(x: x, y: y))
                    isFirstPoint = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        } else {
            // Normal case with proper time distribution
            for entry in entries {
                let timeProgress = entry.date.timeIntervalSince(chunkStart) / chunkDuration
                let x = rect.minX + CGFloat(timeProgress) * rect.width
                let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

                if isFirstPoint {
                    path.move(to: CGPoint(x: x, y: y))
                    isFirstPoint = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }

        context.addPath(path)
        context.strokePath()

        // Draw larger, more visible points
        context.setFillColor(UIColor.systemBlue.cgColor)
        for (index, entry) in entries.enumerated() {
            let timeProgress: CGFloat
            if chunkDuration <= 0 {
                // Handle zero duration case
                timeProgress = entries.count > 1 ? CGFloat(index) / CGFloat(entries.count - 1) : 0.5
            } else {
                timeProgress = entry.date.timeIntervalSince(chunkStart) / chunkDuration
            }

            let x = rect.minX + timeProgress * rect.width
            let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

            let pointRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8) // Larger points for PDF
            context.fillEllipse(in: pointRect)

            // Add white border around points
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: pointRect)
        }
    }

    private func drawChunkAxisLabels(entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        guard !entries.isEmpty else { return }

        let labelFont = UIFont.boldSystemFont(ofSize: 14)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]

        // Y-axis labels (heart rate)
        let hrLabels = [40, 60, 80, 100, 120, 140]
        for hr in hrLabels {
            let y = rect.maxY - (CGFloat(hr - 40) / 110.0) * rect.height
            let label = "\(hr) BPM"
            let labelSize = label.size(withAttributes: labelAttributes)
            label.draw(at: CGPoint(x: rect.minX - labelSize.width - 15, y: y - labelSize.height / 2), withAttributes: labelAttributes)
        }

        // X-axis labels (time) - 4 labels across the chunk
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let chunkStart = entries.first!.date
        let chunkEnd = entries.last!.date
        let chunkDuration = chunkEnd.timeIntervalSince(chunkStart)

        if chunkDuration <= 0 {
            // For zero duration, just show the single timestamp
            let timeLabel = timeFormatter.string(from: chunkStart)
            let labelSize = timeLabel.size(withAttributes: labelAttributes)
            timeLabel.draw(at: CGPoint(x: rect.midX - labelSize.width / 2, y: rect.maxY + 15), withAttributes: labelAttributes)
        } else {
            // Normal case with 4 time labels
            for i in 0...3 {
                let timeOffset = (chunkDuration / 3) * Double(i)
                let timePoint = chunkStart.addingTimeInterval(timeOffset)
                let timeLabel = timeFormatter.string(from: timePoint)

                let x = rect.minX + (CGFloat(i) / 3.0) * rect.width
                let labelSize = timeLabel.size(withAttributes: labelAttributes)
                timeLabel.draw(at: CGPoint(x: x - labelSize.width / 2, y: rect.maxY + 15), withAttributes: labelAttributes)
            }
        }

        // Axis titles
        let yAxisTitle = "Heart Rate (BPM)"
        let xAxisTitle = "Time"

        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]

        // Y-axis title (rotated)
        context.saveGState()
        context.translateBy(x: 15, y: rect.midY)
        context.rotate(by: -CGFloat.pi / 2)
        let yTitleSize = yAxisTitle.size(withAttributes: titleAttributes)
        yAxisTitle.draw(at: CGPoint(x: -yTitleSize.width / 2, y: -yTitleSize.height / 2), withAttributes: titleAttributes)
        context.restoreGState()

        // X-axis title
        let xTitleSize = xAxisTitle.size(withAttributes: titleAttributes)
        xAxisTitle.draw(at: CGPoint(x: rect.midX - xTitleSize.width / 2, y: rect.maxY + 45), withAttributes: titleAttributes)
    }

    private func generateGraphImage() -> Data? {
        print("🖼️ [GRAPH] Starting graph image generation...")

        let imageSize = CGSize(width: 1200, height: 800) // High resolution
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            // Title
            let title = "Today's Heart Rate Graph"
            let titleFont = UIFont.boldSystemFont(ofSize: 28)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]

            let titleSize = title.size(withAttributes: titleAttributes)
            let titleX = (imageSize.width - titleSize.width) / 2
            title.draw(at: CGPoint(x: titleX, y: 30), withAttributes: titleAttributes)

            // Graph area
            let graphRect = CGRect(x: 80, y: 100, width: imageSize.width - 160, height: imageSize.height - 200)
            renderGraphInRect(graphRect, context: context.cgContext)

            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            let dateText = "Generated on \(dateFormatter.string(from: Date()))"
            let dateFont = UIFont.systemFont(ofSize: 16)
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.gray
            ]

            let dateSize = dateText.size(withAttributes: dateAttributes)
            let dateX = (imageSize.width - dateSize.width) / 2
            dateText.draw(at: CGPoint(x: dateX, y: imageSize.height - 40), withAttributes: dateAttributes)
        }

        let imageData = image.pngData()
        print("🖼️ [GRAPH] Graph image generation completed")
        return imageData
    }

    private func renderGraphInRect(_ rect: CGRect, context: CGContext) {
        print("📊 [GRAPH] Rendering graph in rect: \(rect)")

        // Get today's heart rate data
        let todaysEntries = getTodaysHeartRateData()

        if todaysEntries.isEmpty {
            // Draw "No data available" message
            let message = "No heart rate data available for today"
            let messageFont = UIFont.systemFont(ofSize: 18)
            let messageAttributes: [NSAttributedString.Key: Any] = [
                .font: messageFont,
                .foregroundColor: UIColor.gray
            ]

            let messageSize = message.size(withAttributes: messageAttributes)
            let messageX = rect.midX - messageSize.width / 2
            let messageY = rect.midY - messageSize.height / 2

            message.draw(at: CGPoint(x: messageX, y: messageY), withAttributes: messageAttributes)
            return
        }

        // Draw background zones
        drawHeartRateZones(in: rect, context: context)

        // Draw grid lines
        drawGridLines(in: rect, context: context)

        // Draw the heart rate line
        drawHeartRateLine(entries: todaysEntries, in: rect, context: context)

        // Draw axis labels
        drawAxisLabels(in: rect, context: context)
    }

    private func getTodaysHeartRateData() -> [HeartRateEntry] {
        let calendar = Calendar.current
        let today = Date()

        let realData = healthManager.heartRateHistory.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: today)
        }

        // If no real data, generate sample data for demo
        if realData.isEmpty {
            if TestDataManager.shared.shouldGenerateTestData(for: .dailyPatterns) {
                print("⚠️ [GRAPH] No real data for today, generating sample data")
                return generateSampleTodaysData()
            } else {
                print("📊 [GRAPH] No data available and test data is disabled")
                return []
            }
        }

        // Apply PDF-optimized sampling for export (much more aggressive)
        return pdfOptimizedSampling(realData.sorted { $0.date < $1.date })
    }

    private func pdfOptimizedSampling(_ entries: [HeartRateEntry]) -> [HeartRateEntry] {
        guard entries.count > 20 else { return entries }

        var result: [HeartRateEntry] = []
        let calendar = Calendar.current

        // Group entries by hour for PDF export
        var hourlyGroups: [Date: [HeartRateEntry]] = [:]

        for entry in entries {
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: entry.date)
            let hourStart = calendar.date(from: components)!

            if hourlyGroups[hourStart] == nil {
                hourlyGroups[hourStart] = []
            }
            hourlyGroups[hourStart]!.append(entry)
        }

        // Process each hour with PDF-optimized sampling (~10 points max per hour)
        for (hourStart, hourEntries) in hourlyGroups.sorted(by: { $0.key < $1.key }) {
            let sampledHour = sampleHourForPDF(hourEntries, hourStart: hourStart)
            result.append(contentsOf: sampledHour)
        }

        return result.sorted { $0.date < $1.date }
    }

    private func sampleHourForPDF(_ entries: [HeartRateEntry], hourStart: Date) -> [HeartRateEntry] {
        guard !entries.isEmpty else { return [] }

        // For very small datasets, return as-is
        if entries.count <= 10 {
            return entries
        }

        var result: [HeartRateEntry] = []
        var anomalyIndices: Set<Int> = []

        // Find anomalies (significant changes, highs, lows)
        for i in 0..<entries.count {
            let current = entries[i].heartRate

            // Mark extreme values
            if current >= 140 || current <= 50 {
                // Include anomaly and surrounding context
                for offset in -2...2 {
                    let index = i + offset
                    if index >= 0 && index < entries.count {
                        anomalyIndices.insert(index)
                    }
                }
            }

            // Mark significant deltas
            if i > 0 {
                let previous = entries[i-1].heartRate
                let delta = abs(current - previous)

                if delta >= 25 { // Significant change
                    for offset in -2...2 {
                        let index = i + offset
                        if index >= 0 && index < entries.count {
                            anomalyIndices.insert(index)
                        }
                    }
                }
            }
        }

        // Add all anomalies
        for index in anomalyIndices.sorted() {
            result.append(entries[index])
        }

        // Fill to ~10 points total with regular sampling if needed
        let targetPoints = 10
        let currentPoints = result.count

        if currentPoints < targetPoints {
            let neededPoints = targetPoints - currentPoints
            let stepSize = max(1, entries.count / neededPoints)

            for i in stride(from: 0, to: entries.count, by: stepSize) {
                if !anomalyIndices.contains(i) && result.count < targetPoints {
                    result.append(entries[i])
                }
            }
        }

        // Always include first and last points of the hour
        let firstEntry = entries.first!
        let lastEntry = entries.last!

        if !result.contains(where: { $0.date == firstEntry.date }) {
            result.append(firstEntry)
        }
        if !result.contains(where: { $0.date == lastEntry.date }) {
            result.append(lastEntry)
        }

        return result.sorted { $0.date < $1.date }
    }

    private func generateSampleTodaysData() -> [HeartRateEntry] {
        var sampleData: [HeartRateEntry] = []
        let calendar = Calendar.current
        let now = Date()

        // Generate 8 hours of realistic POTS data (every 2 minutes = 240 data points)
        let startTime = calendar.date(byAdding: .hour, value: -8, to: now) ?? now

        print("📊 [SAMPLE] Generating realistic POTS test data for 8-hour period")

        // Define orthostatic episodes throughout the day
        let orthostaticEpisodes: [(hour: Int, minute: Int, intensity: String)] = [
            (hour: 1, minute: 30, intensity: "mild"),     // Morning episode
            (hour: 3, minute: 15, intensity: "severe"),   // Mid-morning severe episode
            (hour: 5, minute: 45, intensity: "moderate"), // Afternoon episode
            (hour: 7, minute: 20, intensity: "mild")      // Evening episode
        ]

        for minuteOffset in stride(from: 0, to: 480, by: 2) { // Every 2 minutes for 8 hours
            let timestamp = calendar.date(byAdding: .minute, value: minuteOffset, to: startTime)!
            let hour = minuteOffset / 60
            let minute = minuteOffset % 60

            // Base heart rate patterns
            var baseRate = 72 // Typical POTS resting rate (slightly elevated)
            var context = "Sitting"
            var isStanding = false

            // Simulate daily activity patterns
            if hour < 2 {
                baseRate = 75 // Morning
            } else if hour >= 2 && hour < 6 {
                baseRate = 80 // Active mid-day
            } else {
                baseRate = 78 // Evening
            }

            // Check for orthostatic episodes
            var heartRate = baseRate
            var isEpisode = false

            for episode in orthostaticEpisodes {
                let episodeStart = episode.hour * 60 + episode.minute
                let episodeEnd = episodeStart + (episode.intensity == "severe" ? 20 : 10) // Duration varies

                if minuteOffset >= episodeStart && minuteOffset <= episodeEnd {
                    isEpisode = true
                    isStanding = true
                    context = "Standing"

                    // POTS response based on intensity
                    switch episode.intensity {
                    case "severe":
                        heartRate = baseRate + Int.random(in: 45...65) // 45-65 BPM increase
                    case "moderate":
                        heartRate = baseRate + Int.random(in: 30...45) // 30-45 BPM increase
                    case "mild":
                        heartRate = baseRate + Int.random(in: 20...35) // 20-35 BPM increase
                    default:
                        heartRate = baseRate + Int.random(in: 25...40)
                    }

                    // Add some variability during episode
                    heartRate += Int.random(in: -5...8)
                    break
                }
            }

            // Add normal variability if not in episode
            if !isEpisode {
                // Simulate occasional standing (non-episode)
                if Int.random(in: 1...100) <= 15 { // 15% chance of standing
                    isStanding = true
                    context = "Standing"
                    heartRate = baseRate + Int.random(in: 8...18) // Normal standing response
                } else {
                    heartRate = baseRate + Int.random(in: -8...12) // Normal sitting variability
                }
            }

            // Ensure realistic bounds
            heartRate = max(60, min(160, heartRate))

            let entry = HeartRateEntry(
                heartRate: heartRate,
                date: timestamp,
                delta: isEpisode ? heartRate - baseRate : Int.random(in: -5...10),
                context: context
            )

            sampleData.append(entry)
        }

        print("📊 [SAMPLE] Generated \(sampleData.count) entries with \(orthostaticEpisodes.count) orthostatic episodes")

        return sampleData
    }

    private func drawHeartRateZones(in rect: CGRect, context: CGContext) {
        let minHR: CGFloat = 40
        let maxHR: CGFloat = 150
        let range = maxHR - minHR

        // Zone colors and ranges - More prominent for PDF export
        let zones = [
            (range: 40...60, color: UIColor.blue.withAlphaComponent(0.2)),
            (range: 60...100, color: UIColor.green.withAlphaComponent(0.2)),
            (range: 100...140, color: UIColor.orange.withAlphaComponent(0.2)),
            (range: 140...150, color: UIColor.red.withAlphaComponent(0.2))
        ]

        for zone in zones {
            let bottomY = rect.maxY - (CGFloat(zone.range.lowerBound - Int(minHR)) / range) * rect.height
            let topY = rect.maxY - (CGFloat(zone.range.upperBound - Int(minHR)) / range) * rect.height
            let zoneRect = CGRect(x: rect.minX, y: topY, width: rect.width, height: bottomY - topY)

            context.setFillColor(zone.color.cgColor)
            context.fill(zoneRect)
        }
    }

    private func drawGridLines(in rect: CGRect, context: CGContext) {
        context.setStrokeColor(UIColor.gray.cgColor) // Darker gray for better visibility
        context.setLineWidth(1.0) // Thicker lines

        // Horizontal grid lines (heart rate) - More prominent lines
        let hrLines = [60, 80, 100, 120, 140] // Key heart rate thresholds
        for hr in hrLines {
            let y = rect.maxY - (CGFloat(hr - 40) / 110.0) * rect.height
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
        }

        // Vertical grid lines (time) - Lighter weight
        context.setLineWidth(0.8)
        context.setStrokeColor(UIColor.lightGray.cgColor)
        let timeIntervals = 6 // Every 4 hours
        for i in 0...timeIntervals {
            let x = rect.minX + (CGFloat(i) / CGFloat(timeIntervals)) * rect.width
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.strokePath()
        }
    }

    private func drawHeartRateLine(entries: [HeartRateEntry], in rect: CGRect, context: CGContext) {
        guard entries.count > 1 else { return }

        let minHR: CGFloat = 40
        let maxHR: CGFloat = 150
        let range = maxHR - minHR

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: entries.first?.date ?? Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let totalDayDuration = endOfDay.timeIntervalSince(startOfDay)

        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(3.0) // Thicker line for better visibility

        let path = CGMutablePath()
        var isFirstPoint = true

        for entry in entries {
            let timeProgress = entry.date.timeIntervalSince(startOfDay) / totalDayDuration
            let x = rect.minX + CGFloat(timeProgress) * rect.width
            let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.addPath(path)
        context.strokePath()

        // Draw larger, more visible points
        context.setFillColor(UIColor.systemBlue.cgColor)
        for entry in entries {
            let timeProgress = entry.date.timeIntervalSince(startOfDay) / totalDayDuration
            let x = rect.minX + CGFloat(timeProgress) * rect.width
            let y = rect.maxY - (CGFloat(entry.heartRate) - minHR) / range * rect.height

            let pointRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6) // Larger points
            context.fillEllipse(in: pointRect)

            // Add white border around points for better contrast
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: pointRect)
        }
    }

    private func drawAxisLabels(in rect: CGRect, context: CGContext) {
        let labelFont = UIFont.boldSystemFont(ofSize: 16) // Larger, bold font for better readability
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]

        // Y-axis labels (heart rate) - More prominent values
        let hrLabels = [40, 60, 80, 100, 120, 140]
        for hr in hrLabels {
            let y = rect.maxY - (CGFloat(hr - 40) / 110.0) * rect.height
            let label = "\(hr) BPM" // Add "BPM" for clarity
            let labelSize = label.size(withAttributes: labelAttributes)
            label.draw(at: CGPoint(x: rect.minX - labelSize.width - 15, y: y - labelSize.height / 2), withAttributes: labelAttributes)
        }

        // X-axis labels (time) - Larger font
        let timeLabels = ["12 AM", "4 AM", "8 AM", "12 PM", "4 PM", "8 PM", "12 AM"]
        let timeLabelFont = UIFont.boldSystemFont(ofSize: 14)
        let timeLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: timeLabelFont,
            .foregroundColor: UIColor.black
        ]

        for (i, timeLabel) in timeLabels.enumerated() {
            let x = rect.minX + (CGFloat(i) / CGFloat(timeLabels.count - 1)) * rect.width
            let labelSize = timeLabel.size(withAttributes: timeLabelAttributes)
            timeLabel.draw(at: CGPoint(x: x - labelSize.width / 2, y: rect.maxY + 15), withAttributes: timeLabelAttributes)
        }

        // Axis titles - Much larger and more prominent
        let yAxisTitle = "Heart Rate (BPM)"
        let xAxisTitle = "Time of Day"

        let titleFont = UIFont.boldSystemFont(ofSize: 18) // Larger title font
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]

        // Y-axis title (rotated)
        context.saveGState()
        context.translateBy(x: 20, y: rect.midY)
        context.rotate(by: -CGFloat.pi / 2)
        let yTitleSize = yAxisTitle.size(withAttributes: titleAttributes)
        yAxisTitle.draw(at: CGPoint(x: -yTitleSize.width / 2, y: -yTitleSize.height / 2), withAttributes: titleAttributes)
        context.restoreGState()

        // X-axis title
        let xTitleSize = xAxisTitle.size(withAttributes: titleAttributes)
        xAxisTitle.draw(at: CGPoint(x: rect.midX - xTitleSize.width / 2, y: rect.maxY + 50), withAttributes: titleAttributes)
    }
}

#Preview {
    ContentView()
}
