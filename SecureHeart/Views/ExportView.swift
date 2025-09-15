//
//  ExportView.swift
//  Secure Heart
//
//  Export and sharing functionality for heart rate data
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ExportOptionsSheet: View {
    @ObservedObject var healthManager: HealthManager
    @Environment(\.dismiss) private var dismiss

    // Cache sample data to avoid regenerating it multiple times during PDF rendering
    @State private var cachedSampleData: [HeartRateEntry]?

    // Use full 60-minute history for export instead of limited in-memory history
    private var sortedHistory: [HeartRateEntry] {
        let fullHistory = healthManager.getFullHeartRateHistory()

        // If no real data is available (simulator/testing), generate sample data for export demo
        if fullHistory.isEmpty {
            if cachedSampleData == nil {
                print("⚠️ [EXPORT] No heart rate data available, generating sample data for export demo")
                cachedSampleData = generateSampleExportData()
            }
            return cachedSampleData ?? []
        }

        return fullHistory
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Options") {
                    ExportOptionRow(icon: "text.alignleft", title: "Share as Text", subtitle: "Messages, Email, Notes", color: .blue) {
                        shareAsText()
                    }
                    
                    ExportOptionRow(icon: "doc.text", title: "Export as PDF", subtitle: "Professional report format", color: .red) {
                        exportAsPDF()
                    }
                    
                    ExportOptionRow(icon: "tablecells", title: "Export as CSV", subtitle: "Spreadsheet data format", color: .green) {
                        exportAsCSV()
                    }
                    
                    ExportOptionRow(icon: "doc.on.doc", title: "Copy to Clipboard", subtitle: "Paste anywhere", color: .orange) {
                        copyToClipboard()
                    }
                }
            }
            .navigationTitle("Export Data")
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
    
    private func shareAsText() {
        print("🔄 [TEXT] Starting text share...")

        let summaryText = generateSummaryText()
        print("✅ [TEXT] Summary generated, length: \(summaryText.count) characters")

        // Dismiss first, then present after a delay
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let activityViewController = UIActivityViewController(activityItems: [summaryText], applicationActivities: nil)

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
                    print("✅ [TEXT] Activity controller presented successfully")
                }
            } else {
                print("❌ [TEXT] Could not find key window or root view controller")
            }
        }
    }
    
    private func exportAsPDF() {
        print("🔄 [PDF] Starting PDF export...")

        guard let pdfData = generatePDFReport() else {
            print("❌ [PDF] Failed to generate PDF report")
            return
        }

        print("✅ [PDF] PDF generated successfully, size: \(pdfData.count) bytes")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("SecureHeart_Report_\(Date().timeIntervalSince1970).pdf")

        do {
            try pdfData.write(to: tempURL)
            print("✅ [PDF] PDF saved to: \(tempURL)")

            // Dismiss first, then present after a longer delay
            dismiss()

            // Use a longer delay and present from the main window's root controller
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let activityViewController = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
                activityViewController.setValue("SecureHeart_Report.pdf", forKey: "subject")

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
                        print("✅ [PDF] Activity controller presented successfully")
                    }
                } else {
                    print("❌ [PDF] Could not find key window or root view controller")
                }
            }
        } catch {
            print("❌ [PDF] Failed to save PDF file: \(error)")
        }
    }
    
    private func exportAsCSV() {
        print("🔄 [CSV] Starting CSV export...")

        let csvContent = generateCSVContent()
        print("✅ [CSV] CSV generated, length: \(csvContent.count) characters")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("SecureHeart_Data_\(Date().timeIntervalSince1970).csv")

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            print("✅ [CSV] CSV saved to: \(tempURL)")

            // Dismiss first, then present after a delay
            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Create a custom activity item that specifies the CSV type
                let csvItem = CSVActivityItem(url: tempURL, filename: "SecureHeart_Data.csv")
                let activityViewController = UIActivityViewController(activityItems: [csvItem], applicationActivities: nil)
                activityViewController.setValue("SecureHeart_Data.csv", forKey: "subject")

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
                        print("✅ [CSV] Activity controller presented successfully")
                    }
                } else {
                    print("❌ [CSV] Could not find key window or root view controller")
                }
            }
        } catch {
            print("❌ [CSV] Failed to create CSV file: \(error)")
        }
    }
    
    private func copyToClipboard() {
        print("🔄 [CLIPBOARD] Copying to clipboard...")

        let summaryText = generateSummaryText()
        UIPasteboard.general.string = summaryText

        print("✅ [CLIPBOARD] Content copied to clipboard (\(summaryText.count) characters)")
        dismiss()
    }
    
    private func generateSummaryText() -> String {
        let totalReadings = sortedHistory.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let oldestReading = sortedHistory.last
        let newestReading = sortedHistory.first
        
        let avgHeartRate = sortedHistory.isEmpty ? 0 : sortedHistory.map { $0.heartRate }.reduce(0, +) / sortedHistory.count
        let minHeartRate = sortedHistory.map { $0.heartRate }.min() ?? 0
        let maxHeartRate = sortedHistory.map { $0.heartRate }.max() ?? 0
        
        var summary = """
        📊 Heart Rate Summary Report
        
        📈 Statistics:
        • Total Readings: \(totalReadings)
        • Average: \(avgHeartRate) BPM
        • Minimum: \(minHeartRate) BPM
        • Maximum: \(maxHeartRate) BPM
        
        """
        
        if let oldest = oldestReading, let newest = newestReading {
            summary += """
            📅 Time Range:
            • From: \(dateFormatter.string(from: oldest.date))
            • To: \(dateFormatter.string(from: newest.date))
            
            """
        }
        
        // Add recent readings
        summary += "📋 Recent Readings:\n"
        for entry in sortedHistory.prefix(10) {
            let contextText = entry.context ?? "Unknown"
            summary += "• \(entry.heartRate) BPM - \(contextText) - \(dateFormatter.string(from: entry.date))\n"
        }
        
        summary += "\n💓 Generated by Secure Heart App"
        
        return summary
    }
    
    private func generateCSVContent() -> String {
        var csvContent = "Date,Time,Heart Rate (BPM),Context,Delta\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for entry in sortedHistory {
            let date = dateFormatter.string(from: entry.date)
            let time = timeFormatter.string(from: entry.date)
            let context = entry.context ?? "Unknown"
            let delta = entry.delta
            
            csvContent += "\(date),\(time),\(entry.heartRate),\(context),\(delta)\n"
        }
        
        return csvContent
    }

    // MARK: - PDF Generation

    private func generatePDFReport() -> Data? {
        print("📄 [PDF] Starting PDF generation...")
        print("📊 [PDF] Data available: \(sortedHistory.count) heart rate entries")

        let pageFormat = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // 8.5 x 11 inches
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: pageFormat)

        return renderer.pdfData { context in
            print("📄 [PDF] Starting page rendering...")
            context.beginPage()

            let title = "Heart Rate Report"
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let headerFont = UIFont.boldSystemFont(ofSize: 14)

            var yPosition: CGFloat = 80

            print("📄 [PDF] Drawing content...")

            // Title
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 40

            // Generated timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .short
            let timestamp = "Generated on \(dateFormatter.string(from: Date()))"
            timestamp.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.gray
            ])
            yPosition += 30

            // Summary Statistics
            "Summary Statistics".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 25

            let totalReadings = sortedHistory.count
            let avgHeartRate = sortedHistory.isEmpty ? 0 : sortedHistory.map { $0.heartRate }.reduce(0, +) / sortedHistory.count
            let minHeartRate = sortedHistory.map { $0.heartRate }.min() ?? 0
            let maxHeartRate = sortedHistory.map { $0.heartRate }.max() ?? 0

            let statsText = """
            Total Readings: \(totalReadings)
            Average Heart Rate: \(avgHeartRate) BPM
            Minimum Heart Rate: \(minHeartRate) BPM
            Maximum Heart Rate: \(maxHeartRate) BPM
            Time Range: \(formatTimeRange())
            """

            let statsRect = CGRect(x: 50, y: yPosition, width: 500, height: 100)
            statsText.draw(in: statsRect, withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 120

            // Heart Rate Zone Analysis
            "Heart Rate Zone Analysis".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 25

            let zoneAnalysis = analyzeHeartRateZones()
            let zoneRect = CGRect(x: 50, y: yPosition, width: 500, height: 80)
            zoneAnalysis.draw(in: zoneRect, withAttributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.black
            ])
            yPosition += 100

            // Recent Readings Table
            if yPosition + 200 < pageRect.height {
                "Recent Readings".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [
                    .font: headerFont,
                    .foregroundColor: UIColor.black
                ])
                yPosition += 25

                drawReadingsTable(context: context.cgContext, startY: yPosition, pageRect: pageRect)
            }

            // Footer
            let footer = "Generated by Secure Heart - Privacy-First Heart Rate Monitoring"
            let footerY = pageRect.height - 50
            footer.draw(at: CGPoint(x: 50, y: footerY), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ])

            print("📄 [PDF] PDF rendering completed")
        }
    }

    private func formatTimeRange() -> String {
        guard let oldest = sortedHistory.last, let newest = sortedHistory.first else {
            return "No data available"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return "\(formatter.string(from: oldest.date)) to \(formatter.string(from: newest.date))"
    }

    private func analyzeHeartRateZones() -> String {
        let lowCount = sortedHistory.filter { $0.heartRate < 60 }.count
        let normalCount = sortedHistory.filter { $0.heartRate >= 60 && $0.heartRate < 100 }.count
        let elevatedCount = sortedHistory.filter { $0.heartRate >= 100 && $0.heartRate < 140 }.count
        let highCount = sortedHistory.filter { $0.heartRate >= 140 }.count

        let total = sortedHistory.count
        guard total > 0 else { return "No data available for analysis" }

        return """
        Low (<60 BPM): \(lowCount) readings (\(Int(Double(lowCount)/Double(total)*100))%)
        Normal (60-99 BPM): \(normalCount) readings (\(Int(Double(normalCount)/Double(total)*100))%)
        Elevated (100-139 BPM): \(elevatedCount) readings (\(Int(Double(elevatedCount)/Double(total)*100))%)
        High (≥140 BPM): \(highCount) readings (\(Int(Double(highCount)/Double(total)*100))%)
        """
    }

    private func drawReadingsTable(context: CGContext, startY: CGFloat, pageRect: CGRect) {
        let tableStartY = startY
        let rowHeight: CGFloat = 20
        let colWidths: [CGFloat] = [120, 80, 100, 150] // Date, Time, BPM, Context
        var currentY = tableStartY

        // Table headers
        let headers = ["Date", "Time", "BPM", "Context"]
        var currentX: CGFloat = 50

        context.setFillColor(UIColor.lightGray.cgColor)
        let headerRect = CGRect(x: 50, y: currentY, width: colWidths.reduce(0, +), height: rowHeight)
        context.fill(headerRect)

        for (index, header) in headers.enumerated() {
            header.draw(at: CGPoint(x: currentX + 5, y: currentY + 5), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ])
            currentX += colWidths[index]
        }
        currentY += rowHeight

        // Table data (limit to first 20 entries to fit on page)
        let limitedData = Array(sortedHistory.prefix(20))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        for entry in limitedData {
            currentX = 50
            let rowData = [
                dateFormatter.string(from: entry.date),
                timeFormatter.string(from: entry.date),
                "\(entry.heartRate)",
                entry.context ?? "Unknown"
            ]

            for (index, data) in rowData.enumerated() {
                data.draw(at: CGPoint(x: currentX + 5, y: currentY + 5), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.black
                ])
                currentX += colWidths[index]
            }
            currentY += rowHeight

            // Stop if we're running out of page space
            if currentY > pageRect.height - 100 {
                break
            }
        }

        // Draw table borders
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.5)

        // Horizontal lines
        for i in 0...(limitedData.count + 1) {
            let y = tableStartY + CGFloat(i) * rowHeight
            context.move(to: CGPoint(x: 50, y: y))
            context.addLine(to: CGPoint(x: 50 + colWidths.reduce(0, +), y: y))
            context.strokePath()
        }

        // Vertical lines
        currentX = 50
        for width in colWidths {
            context.move(to: CGPoint(x: currentX, y: tableStartY))
            context.addLine(to: CGPoint(x: currentX, y: min(currentY, pageRect.height - 100)))
            context.strokePath()
            currentX += width
        }

        // Final right border
        context.move(to: CGPoint(x: currentX, y: tableStartY))
        context.addLine(to: CGPoint(x: currentX, y: min(currentY, pageRect.height - 100)))
        context.strokePath()
    }

    // MARK: - Sample Data Generation for Export Demo

    private func generateSampleExportData() -> [HeartRateEntry] {
        var sampleData: [HeartRateEntry] = []
        let now = Date()

        // Generate 30 sample readings over the last hour for demo purposes
        for i in 0..<30 {
            let timeOffset = TimeInterval(i * 2 * 60) // Every 2 minutes
            let timestamp = now.addingTimeInterval(-timeOffset)

            // Create realistic heart rate patterns
            let baseRate = 75
            let variation = Int.random(in: -15...25)
            let heartRate = max(50, min(150, baseRate + variation))

            // Add some POTS-like episodes
            let isPOTSEpisode = i % 10 == 0 // Every 10th reading
            let finalRate = isPOTSEpisode ? heartRate + Int.random(in: 30...50) : heartRate

            let context = isPOTSEpisode ? "Standing +\(finalRate - heartRate)BPM" : (finalRate > 90 ? "Active" : "Resting")
            let delta = i > 0 ? finalRate - sampleData.last!.heartRate : 0

            let entry = HeartRateEntry(
                heartRate: finalRate,
                date: timestamp,
                delta: delta,
                context: context
            )

            sampleData.append(entry)
        }

        // Sort by date (newest first)
        return sampleData.sorted { $0.date > $1.date }
    }

    // MARK: - Helper for Activity Controller Presentation

    private func presentActivityController(_ activityController: UIActivityViewController, afterDelay delay: TimeInterval = 0.5) {
        print("🔍 [EXPORT] Starting activity controller presentation with delay: \(delay)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("🔍 [EXPORT] Attempting to find window scene...")

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                print("❌ [EXPORT] Could not find window scene")
                return
            }

            guard let window = windowScene.windows.first else {
                print("❌ [EXPORT] Could not find window")
                return
            }

            guard let rootViewController = window.rootViewController else {
                print("❌ [EXPORT] Could not find root view controller")
                return
            }

            print("🔍 [EXPORT] Found root view controller: \(type(of: rootViewController))")

            // Find the view controller that's actually in the window hierarchy
            func findPresentableController(from controller: UIViewController) -> UIViewController {
                print("🔍 [EXPORT] Checking controller: \(type(of: controller))")

                // Check if view is in window hierarchy
                if controller.view.window == nil {
                    print("⚠️ [EXPORT] Controller's view is not in window hierarchy")
                }

                // If currently presenting something, use that
                if let presented = controller.presentedViewController {
                    print("🔍 [EXPORT] Found presented controller: \(type(of: presented))")
                    return findPresentableController(from: presented)
                }

                // If it's a navigation controller, use the top view controller
                if let navController = controller as? UINavigationController,
                   let topController = navController.topViewController {
                    print("🔍 [EXPORT] Found nav top controller: \(type(of: topController))")
                    return findPresentableController(from: topController)
                }

                // If it's a tab bar controller, use the selected view controller
                if let tabController = controller as? UITabBarController,
                   let selectedController = tabController.selectedViewController {
                    print("🔍 [EXPORT] Found tab selected controller: \(type(of: selectedController))")
                    return findPresentableController(from: selectedController)
                }

                return controller
            }

            let presentingController = findPresentableController(from: rootViewController)
            print("🔍 [EXPORT] Final presenting controller: \(type(of: presentingController))")
            print("🔍 [EXPORT] View in window: \(presentingController.view.window != nil)")
            print("🔍 [EXPORT] View loaded: \(presentingController.isViewLoaded)")

            // Wait a bit more if the view isn't ready
            if presentingController.view.window == nil {
                print("⚠️ [EXPORT] View not in window, trying again in 1 second...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.presentActivityController(activityController, afterDelay: 0)
                }
                return
            }

            // iPad specific configuration
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = presentingController.view
                popover.sourceRect = CGRect(x: presentingController.view.bounds.midX, y: presentingController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
                print("🔍 [EXPORT] Configured popover for iPad")
            }

            print("🔍 [EXPORT] Attempting to present activity controller...")
            presentingController.present(activityController, animated: true) {
                print("✅ [EXPORT] Activity controller presented successfully")
            }
        }
    }
}

// MARK: - CSV Activity Item for Proper Type Identification

class CSVActivityItem: NSObject, UIActivityItemSource {
    private let url: URL
    private let filename: String

    init(url: URL, filename: String) {
        self.url = url
        self.filename = filename
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return filename
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return UTType.commaSeparatedText.identifier
    }

    func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
        // Return a CSV icon if desired
        return UIImage(systemName: "tablecells")
    }
}

struct ExportOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .foregroundColor(.primary)
                        .font(.headline)
                    Text(subtitle)
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