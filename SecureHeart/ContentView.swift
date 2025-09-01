//
//  ContentView.swift
//  Secure Heart
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView(healthManager: healthManager)
                .tabItem {
                    Label("Dashboard", systemImage: "heart.fill")
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
                    
                    // Delta Monitoring Card (POTS specific)
                    if healthManager.isDeltaSignificant() {
                        DeltaMonitoringCard(healthManager: healthManager)
                    }
                    
                    // Quick Stats
                    QuickStatsView(healthManager: healthManager)
                    
                    // Daily Heart Rate Trend - Now showing actual data
                    DailyHeartRateGraphView(healthManager: healthManager)
                }
                .padding()
            }
            .navigationTitle("Heart")
            .background(Color.gray.opacity(0.1))
        }
    }
}

// MARK: - Heart Rate Card
struct HeartRateCard: View {
    @ObservedObject var healthManager: HealthManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(healthManager.heartRateColor(for: healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate))
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("Heart Rate")
                    .font(.headline)
                
                Spacer()
                
                // Live indicator
                if healthManager.isWatchConnected && healthManager.liveHeartRate > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            
            HStack(alignment: .bottom) {
                Text("\(healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("BPM")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
                
                // Enhanced Delta Monitoring Display
                if healthManager.isDeltaSignificant() {
                    VStack(spacing: 2) {
                        // Delta icon
                        Image(systemName: healthManager.getDeltaIcon())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(healthManager.getDeltaColor())
                        
                        // Delta value vs recent average
                        Text("\(healthManager.deltaFromAverage > 0 ? "+" : "")\(healthManager.deltaFromAverage)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(healthManager.getDeltaColor())
                        
                        // "vs avg" label
                        Text("vs avg")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
                }
                
                Spacer()
            }
            
            // Heart Rate Zone Indicator
            HeartRateZoneIndicator(healthManager: healthManager, heartRate: healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate)
            
            // Last Updated
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(healthManager.lastUpdated)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Delta Monitoring Card (POTS Specific)
struct DeltaMonitoringCard: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundColor(healthManager.getDeltaColor())
                
                Text("Delta Monitoring")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // POTS indicator if criteria met
                if healthManager.deltaFromAverage >= 30 {
                    Text("POTS Alert")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
            
            // Main delta display
            HStack(spacing: 24) {
                // Current vs Average
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: healthManager.getDeltaIcon())
                            .font(.title)
                            .foregroundColor(healthManager.getDeltaColor())
                        
                        Text("\(healthManager.deltaFromAverage > 0 ? "+" : "")\(healthManager.deltaFromAverage)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(healthManager.getDeltaColor())
                    }
                    
                    Text("BPM vs Recent Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Divider
                Divider()
                    .frame(height: 60)
                
                // Recent Average Display
                VStack(spacing: 8) {
                    Text("\(healthManager.recentAverageHeartRate)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Recent Average\n(10 readings)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Description text
            if !healthManager.getDeltaDescription().isEmpty {
                Text(healthManager.getDeltaDescription())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // POTS explanation if triggered
            if healthManager.deltaFromAverage >= 30 {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("POTS Monitoring")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Text("Heart rate increased 30+ BPM from recent average. This may indicate a postural orthostatic response.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Heart Rate Zone Indicator
struct HeartRateZoneIndicator: View {
    @ObservedObject var healthManager: HealthManager
    let heartRate: Int
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(healthManager.heartRateColor(for: heartRate))
                .frame(width: 4, height: 20)
            
            Text(healthManager.heartRateZone(for: heartRate))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(healthManager.heartRateColor(for: heartRate))
            
            Spacer()
        }
    }
}

// MARK: - Watch Status Card (Simplified for Demo)
struct WatchStatusCard: View {
    var body: some View {
        HStack {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text("Apple Watch")
                    .font(.headline)
                Text("Demo Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Quick Stats View
struct QuickStatsView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Summary")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 16) {
                StatCard(
                    icon: "heart",
                    title: "Average",
                    value: "\(healthManager.averageHeartRate)",
                    unit: "BPM",
                    color: .red
                )
                
                StatCard(
                    icon: "arrow.down",
                    title: "Min",
                    value: "\(healthManager.minHeartRate)",
                    unit: "BPM",
                    color: .blue
                )
                
                StatCard(
                    icon: "arrow.up",
                    title: "Max",
                    value: "\(healthManager.maxHeartRate)",
                    unit: "BPM",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - History Tab View
struct HistoryTabView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var sortOption: HistorySortOption = .newestFirst
    @State private var showingSortMenu = false
    @State private var showingShareSheet = false
    
    enum HistorySortOption: String, CaseIterable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case heartRateHigh = "Heart Rate (High to Low)"
        case heartRateLow = "Heart Rate (Low to High)"
        case standingOnly = "Standing Only"
        case sittingOnly = "Sitting Only"
    }
    
    var sortedHistory: [HeartRateEntry] {
        switch sortOption {
        case .newestFirst:
            return healthManager.heartRateHistory.sorted { $0.date > $1.date }
        case .oldestFirst:
            return healthManager.heartRateHistory.sorted { $0.date < $1.date }
        case .heartRateHigh:
            return healthManager.heartRateHistory.sorted { $0.heartRate > $1.heartRate }
        case .heartRateLow:
            return healthManager.heartRateHistory.sorted { $0.heartRate < $1.heartRate }
        case .standingOnly:
            return healthManager.heartRateHistory.filter { entry in
                entry.context?.contains("Standing") ?? false
            }.sorted { $0.date > $1.date }
        case .sittingOnly:
            return healthManager.heartRateHistory.filter { entry in
                entry.context?.contains("Sitting") ?? false || entry.context == nil
            }.sorted { $0.date > $1.date }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Heart Rate History Section Only - Simplified
                ForEach(sortedHistory) { entry in
                    HeartRateHistoryRow(entry: entry, healthManager: healthManager)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Share Button with all export options
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    
                    // Sort Button  
                    Button(action: {
                        showingSortMenu = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }
                    .confirmationDialog("Sort Heart Rate History", isPresented: $showingSortMenu, titleVisibility: .visible) {
                        ForEach(HistorySortOption.allCases, id: \.self) { option in
                            Button(option.rawValue) {
                                sortOption = option
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ExportOptionsSheet(healthManager: healthManager, sortedHistory: sortedHistory)
            }
        }
    }
    
    // MARK: - Share Functionality (handled by ExportOptionsSheet)
    
    private func generateSummaryText() -> String {
        let totalReadings = sortedHistory.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let oldestReading = sortedHistory.last
        let newestReading = sortedHistory.first
        
        var summary = "📱 Secure Heart - Heart Rate History Summary\n\n"
        summary += "📊 Total Readings: \(totalReadings)\n"
        
        if let oldest = oldestReading, let newest = newestReading {
            summary += "📅 Period: \(dateFormatter.string(from: oldest.date)) - \(dateFormatter.string(from: newest.date))\n"
        }
        
        // Calculate stats
        let heartRates = sortedHistory.map { $0.heartRate }
        let avgHR = heartRates.reduce(0, +) / max(heartRates.count, 1)
        let minHR = heartRates.min() ?? 0
        let maxHR = heartRates.max() ?? 0
        
        summary += "\n📈 Statistics:\n"
        summary += "• Average: \(avgHR) BPM\n"
        summary += "• Minimum: \(minHR) BPM\n"
        summary += "• Maximum: \(maxHR) BPM\n"
        
        // Medical Events Summary
        let tachycardiaEvents = sortedHistory.filter { $0.context?.contains("Tachycardia") == true }
        let bradycardiaEvents = sortedHistory.filter { $0.context?.contains("Bradycardia") == true }
        let arrhythmiaEvents = sortedHistory.filter { $0.context?.contains("Irregular") == true }
        let orthostaticEvents = sortedHistory.filter { $0.context?.contains("Standing +") == true }
        
        if !tachycardiaEvents.isEmpty || !bradycardiaEvents.isEmpty || !arrhythmiaEvents.isEmpty || !orthostaticEvents.isEmpty {
            summary += "\n🏥 Medical Events:\n"
            if !tachycardiaEvents.isEmpty {
                summary += "• Tachycardia Episodes: \(tachycardiaEvents.count)\n"
            }
            if !bradycardiaEvents.isEmpty {
                summary += "• Bradycardia Episodes: \(bradycardiaEvents.count)\n"
            }
            if !arrhythmiaEvents.isEmpty {
                summary += "• Arrhythmia Events: \(arrhythmiaEvents.count)\n"
            }
            if !orthostaticEvents.isEmpty {
                summary += "• Orthostatic Events: \(orthostaticEvents.count)\n"
            }
        }
        
        summary += "\n📱 Generated by Secure Heart App"
        
        return summary
    }
    
    private func generateCSVData() -> URL? {
        var csvString = "Timestamp,Heart Rate (BPM),Delta (BPM),Activity,Medical Event\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for entry in sortedHistory.sorted(by: { $0.date < $1.date }) { // Sort chronologically for CSV
            let timestamp = dateFormatter.string(from: entry.date)
            let heartRate = entry.heartRate
            let delta = entry.delta
            let activity = entry.context?.contains("Standing") == true ? "Standing" : 
                          entry.context?.contains("Sitting") == true ? "Sitting" : "Unknown"
            let medicalEvent = entry.context ?? ""
            
            csvString += "\"\(timestamp)\",\(heartRate),\(delta),\"\(activity)\",\"\(medicalEvent)\"\n"
        }
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "SecureHeart_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none).replacingOccurrences(of: "/", with: "-")).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write CSV file: \(error)")
            return nil
        }
    }
    
    private func generatePDFSummary() -> String {
        // For now, return a formatted text that could be converted to PDF
        var pdfContent = "SECURE HEART - MEDICAL REPORT\n"
        pdfContent += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))\n\n"
        
        pdfContent += "HEART RATE ANALYSIS\n"
        pdfContent += "Total Readings: \(sortedHistory.count)\n"
        
        let heartRates = sortedHistory.map { $0.heartRate }
        let avgHR = heartRates.reduce(0, +) / max(heartRates.count, 1)
        let minHR = heartRates.min() ?? 0
        let maxHR = heartRates.max() ?? 0
        
        pdfContent += "Average Heart Rate: \(avgHR) BPM\n"
        pdfContent += "Minimum Heart Rate: \(minHR) BPM\n"
        pdfContent += "Maximum Heart Rate: \(maxHR) BPM\n\n"
        
        pdfContent += "MEDICAL EVENTS:\n"
        let medicalEvents = sortedHistory.filter { $0.context != nil }
        for event in medicalEvents.prefix(20) { // Top 20 medical events
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            pdfContent += "• \(formatter.string(from: event.date)): \(event.heartRate) BPM - \(event.context ?? "")\n"
        }
        
        return pdfContent
    }
    
    // Helper function for severity colors
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "normal":
            return .green
        case "mild response":
            return .yellow
        case "moderate response":
            return .orange
        case "significant response":
            return .red
        default:
            return .gray
        }
    }
}


// Share Option Row Component
struct ShareOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Export Options Sheet
struct ExportOptionsSheet: View {
    @ObservedObject var healthManager: HealthManager
    let sortedHistory: [HeartRateEntry]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Options") {
                    // Share as Text
                    ExportOptionRow(
                        icon: "text.alignleft",
                        title: "Share as Text",
                        subtitle: "Messages, Email, Notes",
                        color: .blue
                    ) {
                        shareAsText()
                    }
                    
                    // Export as PDF
                    ExportOptionRow(
                        icon: "doc.text",
                        title: "Export as PDF",
                        subtitle: "Professional report format",
                        color: .red
                    ) {
                        exportAsPDF()
                    }
                    
                    // Export as CSV
                    ExportOptionRow(
                        icon: "tablecells",
                        title: "Export as CSV",
                        subtitle: "Spreadsheet data format",
                        color: .green
                    ) {
                        exportAsCSV()
                    }
                    
                    // Copy to Clipboard
                    ExportOptionRow(
                        icon: "doc.on.doc",
                        title: "Copy to Clipboard",
                        subtitle: "Paste anywhere",
                        color: .orange
                    ) {
                        copyToClipboard()
                    }
                }
            }
            .navigationTitle("Export Heart Rate Data")
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
    
    // MARK: - Export Actions
    private func shareAsText() {
        let summary = generateSummaryText()
        let activityViewController = UIActivityViewController(activityItems: [summary], applicationActivities: nil)
        presentShareSheet(activityViewController)
    }
    
    private func exportAsPDF() {
        print("📄 Starting PDF export...")
        
        if let pdfData = generatePDF() {
            print("📄 PDF generated successfully, size: \(pdfData.count) bytes")
            let activityViewController = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
            presentShareSheet(activityViewController)
        } else {
            print("❌ PDF generation failed")
            // Fallback: share as text if PDF fails
            let summary = generateSummaryText()
            let activityViewController = UIActivityViewController(activityItems: [summary], applicationActivities: nil)
            presentShareSheet(activityViewController)
        }
    }
    
    private func exportAsCSV() {
        let csvText = generateCSVText()
        let activityViewController = UIActivityViewController(activityItems: [csvText], applicationActivities: nil)
        presentShareSheet(activityViewController)
    }
    
    private func copyToClipboard() {
        let summary = generateSummaryText()
        UIPasteboard.general.string = summary
        dismiss()
    }
    
    private func presentShareSheet(_ activityViewController: UIActivityViewController) {
        print("📤 Preparing to present share sheet...")
        
        // For iPad support
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            print("📤 Presenting share sheet...")
            rootViewController.present(activityViewController, animated: true)
        } else {
            print("❌ Could not find root view controller")
        }
        
        dismiss()
    }
    
    // MARK: - Data Generation
    private func generateSummaryText() -> String {
        let totalReadings = sortedHistory.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let oldestReading = sortedHistory.last
        let newestReading = sortedHistory.first
        
        var summary = "📱 Secure Heart - Heart Rate History Summary\n\n"
        summary += "📊 Total Readings: \(totalReadings)\n"
        
        if let oldest = oldestReading, let newest = newestReading {
            summary += "📅 Period: \(dateFormatter.string(from: oldest.date)) - \(dateFormatter.string(from: newest.date))\n"
        }
        
        // Calculate stats
        let heartRates = sortedHistory.map { $0.heartRate }
        let avgHR = heartRates.reduce(0, +) / max(heartRates.count, 1)
        let minHR = heartRates.min() ?? 0
        let maxHR = heartRates.max() ?? 0
        
        summary += "\n📈 Statistics:\n"
        summary += "• Average: \(avgHR) BPM\n"
        summary += "• Minimum: \(minHR) BPM\n"
        summary += "• Maximum: \(maxHR) BPM\n"
        
        // Medical Events Summary
        let medicalEvents = sortedHistory.filter { $0.context != nil }
        if !medicalEvents.isEmpty {
            summary += "\n🏥 Medical Events: \(medicalEvents.count)\n"
        }
        
        summary += "\n📱 Generated by Secure Heart App"
        
        return summary
    }
    
    private func generateCSVText() -> String {
        var csvString = "Timestamp,Heart Rate (BPM),Delta (BPM),Activity,Medical Event\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for entry in sortedHistory.sorted(by: { $0.date < $1.date }) {
            let timestamp = dateFormatter.string(from: entry.date)
            let heartRate = entry.heartRate
            let delta = entry.delta
            let activity = entry.context?.contains("Standing") == true ? "Standing" : 
                          entry.context?.contains("Sitting") == true ? "Sitting" : "Unknown"
            let medicalEvent = entry.context ?? ""
            
            csvString += "\"\(timestamp)\",\(heartRate),\(delta),\"\(activity)\",\"\(medicalEvent)\"\n"
        }
        
        return csvString
    }
    
    private func generatePDF() -> Data? {
        print("📄 Generating PDF with \(sortedHistory.count) heart rate entries")
        
        // Create PDF renderer
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        do {
            let data = renderer.pdfData { context in
                context.beginPage()
                
                let title = "Secure Heart - Heart Rate Report"
                let titleFont = UIFont.boldSystemFont(ofSize: 20)
                let bodyFont = UIFont.systemFont(ofSize: 12)
                
                var yPosition: CGFloat = 50
            
            // Title
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 40
            
            // Date
            let dateText = "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))"
            dateText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.gray
            ])
            yPosition += 30
            
            // Statistics
            let heartRates = sortedHistory.map { $0.heartRate }
            let avgHR = heartRates.reduce(0, +) / max(heartRates.count, 1)
            let minHR = heartRates.min() ?? 0
            let maxHR = heartRates.max() ?? 0
            
            let statsText = """
            HEART RATE ANALYSIS
            Total Readings: \(sortedHistory.count)
            Average Heart Rate: \(avgHR) BPM
            Minimum Heart Rate: \(minHR) BPM
            Maximum Heart Rate: \(maxHR) BPM
            """
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            
            statsText.draw(in: CGRect(x: 50, y: yPosition, width: 500, height: 200), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ])
            yPosition += 140
            
            // Medical Events
            "MEDICAL EVENTS:".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ])
            yPosition += 25
            
            let medicalEvents = sortedHistory.filter { $0.context != nil }.prefix(15)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            for event in medicalEvents {
                let eventText = "• \(formatter.string(from: event.date)): \(event.heartRate) BPM - \(event.context ?? "")"
                eventText.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: [
                    .font: bodyFont,
                    .foregroundColor: UIColor.black
                ])
                yPosition += 18
                
                // Start new page if needed
                if yPosition > 720 {
                    context.beginPage()
                    yPosition = 50
                }
            }
        }
        
        print("📄 PDF data generated successfully")
        return data
    }
}
}

// MARK: - Export Option Row Component
struct ExportOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Native Share Sheet (for fallback)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("highHeartRateAlert") private var highHeartRateAlert = 150
    @AppStorage("lowHeartRateAlert") private var lowHeartRateAlert = 40
    @AppStorage("recordingInterval") private var recordingInterval = 60.0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device Connection") {
                    WatchStatusCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }
                
                Section("Recording Settings") {
                    HStack {
                        Text("Recording Interval")
                        Spacer()
                        Picker("Recording Interval", selection: $recordingInterval) {
                            Text("8 seconds").tag(8.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("2 minutes").tag(120.0)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section("Heart Rate Alerts") {
                    HStack {
                        Text("High Heart Rate")
                        Spacer()
                        Text("\(highHeartRateAlert) BPM")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Low Heart Rate")
                        Spacer()
                        Text("\(lowHeartRateAlert) BPM")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
        }
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
                        ForEach(healthManager.orthostaticEvents.prefix(3)) { event in
                            OrthostaticPatternCard(event: event)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Daily Heart Rate Graph View
struct DailyHeartRateGraphView: View {
    @ObservedObject var healthManager: HealthManager
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Heart Rate Trend")
                    .font(.headline)
                Spacer()
                Text("(\(healthManager.heartRateHistory.count) readings)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            if healthManager.heartRateHistory.isEmpty {
                // Empty state
                VStack {
                    Text("No heart rate data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Data will appear here when available")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Heart rate trend graph
                DailyHeartRateTrendGraph(entries: healthManager.heartRateHistory, healthManager: healthManager)
                
                // Time range indicator
                HStack {
                    if let earliest = healthManager.heartRateHistory.last,
                       let latest = healthManager.heartRateHistory.first {
                        
                        Text("\(timeFormatter.string(from: earliest.date)) - \(timeFormatter.string(from: latest.date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Heart rate zones legend
                    HStack(spacing: 8) {
                        LegendItem(color: .blue, label: "Rest")
                        LegendItem(color: .green, label: "Normal")
                        LegendItem(color: .yellow, label: "Active")
                        LegendItem(color: .orange, label: "High")
                        LegendItem(color: .red, label: "Peak")
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Daily Heart Rate Trend Graph
struct DailyHeartRateTrendGraph: View {
    let entries: [HeartRateEntry]
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Calculate min/max for scaling (with padding)
            let heartRates = entries.map { $0.heartRate }
            let minHR = max(40, heartRates.min() ?? 60 - 10)
            let maxHR = min(200, heartRates.max() ?? 100 + 20)
            let hrRange = maxHR - minHR
            
            ZStack {
                // Background grid
                ForEach(0..<5, id: \.self) { i in
                    let y = height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                }
                
                // Heart rate zones background
                HeartRateZoneBackground(width: width, height: height, minHR: minHR, maxHR: maxHR)
                
                // Heart rate trend line
                Path { path in
                    for (index, entry) in entries.enumerated() {
                        let x = width * CGFloat(entries.count - 1 - index) / CGFloat(max(entries.count - 1, 1))
                        let normalizedHR = (CGFloat(entry.heartRate) - CGFloat(minHR)) / CGFloat(hrRange)
                        let y = height * (1 - normalizedHR)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.green, Color.yellow, Color.orange, Color.red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                
                // Data points
                ForEach(Array(entries.enumerated().prefix(20)), id: \.offset) { index, entry in
                    let x = width * CGFloat(entries.count - 1 - index) / CGFloat(max(entries.count - 1, 1))
                    let normalizedHR = (CGFloat(entry.heartRate) - CGFloat(minHR)) / CGFloat(hrRange)
                    let y = height * (1 - normalizedHR)
                    
                    Circle()
                        .fill(healthManager.heartRateColor(for: entry.heartRate))
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }
                
                // Y-axis labels
                VStack {
                    ForEach(0..<5, id: \.self) { i in
                        let hr = maxHR - (hrRange * i / 4)
                        HStack {
                            Spacer()
                            Text("\(hr)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.trailing, -5)
                        }
                        if i < 4 { Spacer() }
                    }
                }
            }
        }
        .frame(height: 120)
    }
}

// MARK: - Heart Rate Zone Background
struct HeartRateZoneBackground: View {
    let width: CGFloat
    let height: CGFloat
    let minHR: Int
    let maxHR: Int
    
    var body: some View {
        let hrRange = maxHR - minHR
        
        // Define zone boundaries
        let zones = [
            (range: 40..<60, color: Color.blue.opacity(0.1)),
            (range: 60..<100, color: Color.green.opacity(0.1)),
            (range: 100..<140, color: Color.yellow.opacity(0.1)),
            (range: 140..<170, color: Color.orange.opacity(0.1)),
            (range: 170..<200, color: Color.red.opacity(0.1))
        ]
        
        ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
            let zoneMinHR = max(minHR, zone.range.lowerBound)
            let zoneMaxHR = min(maxHR, zone.range.upperBound - 1)
            
            if zoneMinHR < zoneMaxHR {
                let normalizedMin = CGFloat(zoneMinHR - minHR) / CGFloat(hrRange)
                let normalizedMax = CGFloat(zoneMaxHR - minHR) / CGFloat(hrRange)
                
                let zoneHeight = height * (normalizedMax - normalizedMin)
                let zoneY = height * (1 - normalizedMax)
                
                Rectangle()
                    .fill(zone.color)
                    .frame(width: width, height: zoneHeight)
                    .position(x: width / 2, y: zoneY + zoneHeight / 2)
            }
        }
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty Orthostatic Pattern Card
struct EmptyOrthostaticPatternCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with placeholder
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Text("--:--")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Empty graph area
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Empty baseline
                    Path { path in
                        let baselineY = height * 0.8
                        path.move(to: CGPoint(x: 10, y: baselineY))
                        path.addLine(to: CGPoint(x: width - 10, y: baselineY))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Text("No Data")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                    )
                }
                .frame(height: 60)
            }
            
            // Empty stats
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Peak:")
                    Spacer()
                    Text("--")
                        .foregroundColor(.gray)
                }
                .font(.caption)
                
                HStack {
                    Text("Sustained:")
                    Spacer()
                    Text("--")
                        .foregroundColor(.gray)
                }
                .font(.caption)
                
                HStack {
                    Text("Recovery:")
                    Spacer()
                    Text("--")
                        .foregroundColor(.gray)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Orthostatic Pattern Card
struct OrthostaticPatternCard: View {
    let event: OrthostaticEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with severity color
            HStack {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                
                Text(event.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if event.sustainedDuration >= 600 && event.increase >= 30 {
                    Text("POTS")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
            }
            
            // Visual graph showing elevation and recovery pattern
            OrthostaticTimelineView(event: event)
            
            // Stats summary
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Peak:")
                    Spacer()
                    Text("+\(event.increase) BPM")
                        .fontWeight(.bold)
                        .foregroundColor(severityColor)
                }
                .font(.caption)
                
                HStack {
                    Text("Sustained:")
                    Spacer()
                    Text(event.sustainedMinutes)
                        .fontWeight(.medium)
                }
                .font(.caption)
                
                HStack {
                    Text("Recovery:")
                    Spacer()
                    Text(event.recoveryText)
                        .fontWeight(.medium)
                        .foregroundColor(event.isRecovered ? .green : .orange)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(severityColor, lineWidth: 1)
        )
    }
    
    private var severityColor: Color {
        switch event.severity.lowercased() {
        case "normal":
            return .green
        case "mild response":
            return .yellow
        case "moderate response":
            return .orange
        case "significant response", "severe":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Orthostatic Timeline View
struct OrthostaticTimelineView: View {
    let event: OrthostaticEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Heart rate progression graph
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                
                Path { path in
                    // Calculate key time points
                    let totalDuration = event.sustainedDuration + (event.recoveryTime ?? 60)
                    let elevationStartX: CGFloat = 20
                    let sustainedEndX = elevationStartX + (CGFloat(event.sustainedDuration) / CGFloat(totalDuration)) * (width - 40)
                    let recoveryEndX = event.recoveryTime != nil ? width - 20 : sustainedEndX
                    
                    // Heart rate heights (inverted for SwiftUI coordinate system)
                    let baselineY = height * 0.8
                    let peakY = height * 0.2
                    let recoveryY = event.isRecovered ? baselineY : height * 0.5
                    
                    // Draw the heart rate curve
                    path.move(to: CGPoint(x: 10, y: baselineY)) // Baseline start
                    path.addLine(to: CGPoint(x: elevationStartX, y: peakY)) // Rise to peak
                    path.addLine(to: CGPoint(x: sustainedEndX, y: peakY)) // Sustained elevation
                    
                    if event.recoveryTime != nil {
                        path.addLine(to: CGPoint(x: recoveryEndX, y: recoveryY)) // Recovery
                    }
                }
                .stroke(event.isRecovered ? Color.blue : Color.red, lineWidth: 2)
                
                // Add markers for key phases
                VStack(alignment: .leading) {
                    Spacer()
                    HStack {
                        Text("Stand")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if event.recoveryTime != nil {
                            Text(event.isRecovered ? "Recovered" : "Partial")
                                .font(.caption2)
                                .foregroundColor(event.isRecovered ? .green : .orange)
                        } else {
                            Text("No Recovery")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .frame(height: 60)
        }
    }
}

// MARK: - Heart Rate History Row
struct HeartRateHistoryRow: View {
    let entry: HeartRateEntry
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(healthManager.heartRateColor(for: entry.heartRate))
            
            Text("\(entry.heartRate) BPM")
                .font(.headline)
            
            if let context = entry.context {
                Text(context.contains("Standing") ? "Standing" : "Sitting")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(entry.formattedDateTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
