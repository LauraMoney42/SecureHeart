//
//  ContentView.swift
//  Secure Heart
//
//  Main application view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    
    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardView(healthManager: healthManager)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }
                .tag(0)
            
            // History Tab  
            HistoryTabView(healthManager: healthManager)
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            // Settings Tab
            SettingsTabView()
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
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
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
                    
                    // Delta Monitoring Card (Standing Response)
                    DeltaMonitoringCard(healthManager: healthManager)
                    
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

// MARK: - Delta Monitoring Card (Standing Response)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Heart Rate")
                .font(.headline)
                .padding(.horizontal)
            
            ImprovedDailyGraph(healthManager: healthManager)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
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
                Text("Supine → Standing")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    
    // Simulate multiple orthostatic events throughout the day
    var orthostaticEvents: [(startTime: String, endTime: String, data: [(time: String, supineHR: Int, standingHR: Int, delta: Int)])] {
        return [
            (startTime: "8:15 AM", endTime: "8:25 AM", data: [
                (time: "Baseline", supineHR: 70, standingHR: 70, delta: 0),
                (time: "1 min", supineHR: 70, standingHR: 95, delta: 25),
                (time: "3 min", supineHR: 70, standingHR: 105, delta: 35),
                (time: "5 min", supineHR: 70, standingHR: 108, delta: 38),
                (time: "10 min", supineHR: 70, standingHR: 110, delta: 40)
            ]),
            (startTime: "2:30 PM", endTime: "2:40 PM", data: [
                (time: "Baseline", supineHR: 75, standingHR: 75, delta: 0),
                (time: "1 min", supineHR: 75, standingHR: 98, delta: 23),
                (time: "3 min", supineHR: 75, standingHR: 102, delta: 27),
                (time: "5 min", supineHR: 75, standingHR: 105, delta: 30),
                (time: "10 min", supineHR: 75, standingHR: 107, delta: 32)
            ]),
            (startTime: "6:45 PM", endTime: "6:55 PM", data: [
                (time: "Baseline", supineHR: 68, standingHR: 68, delta: 0),
                (time: "1 min", supineHR: 68, standingHR: 85, delta: 17),
                (time: "3 min", supineHR: 68, standingHR: 88, delta: 20),
                (time: "5 min", supineHR: 68, standingHR: 90, delta: 22),
                (time: "10 min", supineHR: 68, standingHR: 92, delta: 24)
            ])
        ]
    }
    
    var currentEvent: (startTime: String, endTime: String, data: [(time: String, supineHR: Int, standingHR: Int, delta: Int)]) {
        orthostaticEvents[selectedEventIndex]
    }
    
    var orthostaticTestData: [(time: String, supineHR: Int, standingHR: Int, delta: Int)] {
        currentEvent.data
    }
    
    var body: some View {
        VStack(spacing: 8) {
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
                    Text(currentEvent.startTime)
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
                    Text(currentEvent.endTime)
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
                .frame(height: 120)
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
                        Text("50").font(.system(size: 10)).foregroundColor(.blue)
                    }
                    .frame(width: 25, height: 120)
                    
                    // Graph area
                    SimpleHeartRateGraph(entries: todaysEntries)
                        .frame(height: 120)
                }
                
                // Time axis
                SimpleTimeAxis(entries: todaysEntries)
            }
        }
    }
}

struct SimpleHeartRateGraph: View {
    let entries: [HeartRateEntry]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minHR = 50
            let maxHR = 150
            let range = maxHR - minHR
            
            ZStack {
                // Background zones
                VStack(spacing: 0) {
                    Rectangle().fill(Color.red.opacity(0.1)).frame(height: height * 0.2)
                    Rectangle().fill(Color.orange.opacity(0.1)).frame(height: height * 0.3) 
                    Rectangle().fill(Color.green.opacity(0.1)).frame(height: height * 0.4)
                    Rectangle().fill(Color.blue.opacity(0.1)).frame(height: height * 0.1)
                }
                .cornerRadius(4)
                
                // Grid lines
                ForEach([60, 80, 100, 130], id: \.self) { bpm in
                    let y = height * (1 - CGFloat(bpm - minHR) / CGFloat(range))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                }
                
                // Heart rate line (no dots)
                Path { path in
                    for (index, entry) in entries.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(entries.count - 1, 1))
                        let clampedRate = max(minHR, min(maxHR, entry.heartRate))
                        let normalizedRate = CGFloat(clampedRate - minHR) / CGFloat(range)
                        let y = height * (1 - normalizedRate)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.red.opacity(0.8), lineWidth: 2)
            }
        }
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

#Preview {
    ContentView()
}
