//
//  HistoryView.swift
//  Secure Heart
//
//  Heart rate data analysis and history display
//

import SwiftUI

enum HistorySortOption: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case heartRateHigh = "Heart Rate (High to Low)"
    case heartRateLow = "Heart Rate (Low to High)"
    // case standingOnly = "Standing Only" // Commented out for MVP2
    // case sittingOnly = "Sitting Only" // Commented out for MVP2
}

struct DataTabView: View {
    @ObservedObject var healthManager: HealthManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Recent History Section
                    RecentHistoryView(healthManager: healthManager)

                    // Weekly Trend Graph
                    WeeklyTrendGraphView(healthManager: healthManager)

                    // Monthly Trend Graph
                    MonthlyTrendGraphView(healthManager: healthManager)
                }
                .padding()
            }
            .navigationTitle("Data")
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

struct RecentHistoryView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var sortOption: HistorySortOption = .newestFirst
    @State private var showingSortMenu = false
    @State private var showingShareSheet = false

    var sortedHistory: [HeartRateEntry] {
        // Show recent entries (last 50 for better performance)
        let recentEntries = Array(healthManager.heartRateHistory.prefix(50))

        switch sortOption {
        case .newestFirst:
            return recentEntries.sorted { $0.date > $1.date }
        case .oldestFirst:
            return recentEntries.sorted { $0.date < $1.date }
        case .heartRateHigh:
            return recentEntries.sorted { $0.heartRate > $1.heartRate }
        case .heartRateLow:
            return recentEntries.sorted { $0.heartRate < $1.heartRate }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Recent History")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Sort Button
                Button(action: {
                    showingSortMenu = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.blue)
                }
                .confirmationDialog("Sort Recent History", isPresented: $showingSortMenu, titleVisibility: .visible) {
                    ForEach(HistorySortOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            sortOption = option
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }

                // Share Button
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
            }

            // Content
            Group {
                if sortedHistory.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            Text("No Heart Rate Data Yet")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Connect your Apple Watch to start tracking.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                } else {
                    // Scrollable container for history entries
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(sortedHistory) { entry in
                                HeartRateHistoryRow(entry: entry, healthManager: healthManager)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 300) // Full height now that label is removed
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingShareSheet) {
            ExportOptionsSheet(healthManager: healthManager)
        }
    }
}

struct WeeklyTrendGraphView: View {
    @ObservedObject var healthManager: HealthManager

    var weeklyData: [DayTrendData] {
        let calendar = Calendar.current
        let today = Date()
        var data: [DayTrendData] = []

        // Get last 7 days
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let allHistoricalData = healthManager.getAllHistoricalDataForTrends()

            // DEBUG: Show date range we're searching and sample data dates
            if i == 0 { // Only log for first day to avoid spam
                print("📊 [WEEKLY] Searching date range: \(startOfDay) to \(endOfDay)")
                if !allHistoricalData.isEmpty {
                    let sampleDates = allHistoricalData.prefix(3).map { $0.date }
                    print("📊 [WEEKLY] Sample data dates: \(sampleDates)")
                }
            }

            let dayEntries = allHistoricalData.filter { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }

            print("📊 [WEEKLY] Day \(i): \(dayEntries.count) entries for \(startOfDay.formatted(.dateTime.day().month().year()))")

            let avgHR = dayEntries.isEmpty ? 0 : dayEntries.map { $0.heartRate }.reduce(0, +) / dayEntries.count
            let maxHR = dayEntries.map { $0.heartRate }.max() ?? 0
            let minHR = dayEntries.map { $0.heartRate }.min() ?? 0

            if !dayEntries.isEmpty {
                print("📊 [WEEKLY] Day \(i) HR: avg=\(avgHR), max=\(maxHR), min=\(minHR)")
            } else {
                print("📊 [WEEKLY] Day \(i): NO ENTRIES FOUND - this will make entryCount=0")
            }

            // COMMENTED OUT FOR PHYSICAL TESTING - No fake data generation
            /*
            // TESTING: Force entryCount and avgHR to ensure data points are drawn
            let testEntryCount = dayEntries.count > 0 ? dayEntries.count : 10 // Force non-zero
            let testAvgHR = avgHR > 0 ? avgHR : (70 + i * 5) // Force non-zero heart rate

            print("🔧 [TESTING] Day \(i): Forcing entryCount=\(testEntryCount), avgHR=\(testAvgHR)")

            data.append(DayTrendData(
                date: date,
                averageHR: testAvgHR,
                maxHR: maxHR > 0 ? maxHR : testAvgHR + 10,
                minHR: minHR > 0 ? minHR : testAvgHR - 10,
                entryCount: testEntryCount
            ))
            */

            // PHYSICAL TESTING - Use real data only (no fake data)
            data.append(DayTrendData(
                date: date,
                averageHR: avgHR,
                maxHR: maxHR,
                minHR: minHR,
                entryCount: dayEntries.count
            ))
        }

        return data.reversed() // Show oldest to newest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Trend")
                .font(.title2)
                .fontWeight(.semibold)

            if weeklyData.allSatisfy({ $0.entryCount == 0 }) {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No data for the past week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                WeeklyTrendChart(data: weeklyData)
                    .frame(height: 200)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct MonthlyTrendGraphView: View {
    @ObservedObject var healthManager: HealthManager

    var monthlyData: [WeekTrendData] {
        let calendar = Calendar.current
        let today = Date()
        var data: [WeekTrendData] = []

        // Get last 4 weeks
        for i in 0..<4 {
            let startDate = calendar.date(byAdding: .weekOfYear, value: -i, to: today)!
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startDate)!.start
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: startDate)!.end

            let allHistoricalData = healthManager.getAllHistoricalDataForTrends()
            let weekEntries = allHistoricalData.filter { entry in
                entry.date >= startOfWeek && entry.date < endOfWeek
            }

            let avgHR = weekEntries.isEmpty ? 0 : weekEntries.map { $0.heartRate }.reduce(0, +) / weekEntries.count
            let maxHR = weekEntries.map { $0.heartRate }.max() ?? 0
            let minHR = weekEntries.map { $0.heartRate }.min() ?? 0

            // COMMENTED OUT FOR PHYSICAL TESTING - No fake data generation
            /*
            // TESTING: Force entryCount and avgHR to ensure data points are drawn
            let testEntryCount = weekEntries.count > 0 ? weekEntries.count : 25 // Force non-zero
            let testAvgHR = avgHR > 0 ? avgHR : (75 + i * 3) // Force non-zero heart rate

            print("🔧 [TESTING] Week \(i): Forcing entryCount=\(testEntryCount), avgHR=\(testAvgHR)")

            data.append(WeekTrendData(
                weekStart: startOfWeek,
                averageHR: testAvgHR,
                maxHR: maxHR > 0 ? maxHR : testAvgHR + 15,
                minHR: minHR > 0 ? minHR : testAvgHR - 15,
                entryCount: testEntryCount
            ))
            */

            // PHYSICAL TESTING - Use real data only (no fake data)
            data.append(WeekTrendData(
                weekStart: startOfWeek,
                averageHR: avgHR,
                maxHR: maxHR,
                minHR: minHR,
                entryCount: weekEntries.count
            ))
        }

        return data.reversed() // Show oldest to newest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Trend")
                .font(.title2)
                .fontWeight(.semibold)

            if monthlyData.allSatisfy({ $0.entryCount == 0 }) {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No data for the past month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                MonthlyTrendChart(data: monthlyData)
                    .frame(height: 200)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Data Models for Trend Analysis

struct DayTrendData {
    let date: Date
    let averageHR: Int
    let maxHR: Int
    let minHR: Int
    let entryCount: Int
}

struct WeekTrendData {
    let weekStart: Date
    let averageHR: Int
    let maxHR: Int
    let minHR: Int
    let entryCount: Int
}

// MARK: - Chart Components

struct WeeklyTrendChart: View {
    let data: [DayTrendData]

    var body: some View {
        // DEBUG: Log what data the chart is receiving
        let _ = print("🎯 [CHART] WeeklyTrendChart received \(data.count) days of data")
        let _ = data.enumerated().forEach { index, dayData in
            print("🎯 [CHART] Day \(index): entryCount=\(dayData.entryCount), avgHR=\(dayData.averageHR)")
        }
        VStack(spacing: 12) {
            // Chart area
            GeometryReader { geometry in
                let maxHR = data.map { $0.maxHR }.max() ?? 100
                let minHR = data.map { $0.minHR }.filter { $0 > 0 }.min() ?? 60
                let range = max(maxHR - minHR, 20) // Minimum range of 20

                ZStack {
                    // Background grid
                    ForEach(0..<5) { i in
                        let y = geometry.size.height * CGFloat(i) / 4
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }

                    // Average line
                    Path { path in
                        for (index, dayData) in data.enumerated() {
                            if dayData.entryCount > 0 {
                                let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                                let y = geometry.size.height * (1 - CGFloat(dayData.averageHR - minHR) / CGFloat(range))

                                if index == 0 || data[index - 1].entryCount == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, dayData in
                        if dayData.entryCount > 0 {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                            let y = geometry.size.height * (1 - CGFloat(dayData.averageHR - minHR) / CGFloat(range))

                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 120)
            .padding()

            // Day labels
            HStack {
                ForEach(Array(data.enumerated()), id: \.offset) { index, dayData in
                    VStack(spacing: 4) {
                        Text(dayData.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if dayData.entryCount > 0 {
                            Text("\(dayData.averageHR)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        } else {
                            Text("--")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct MonthlyTrendChart: View {
    let data: [WeekTrendData]

    var body: some View {
        // DEBUG: Log what data the chart is receiving
        let _ = print("🎯 [CHART] MonthlyTrendChart received \(data.count) weeks of data")
        let _ = data.enumerated().forEach { index, weekData in
            print("🎯 [CHART] Week \(index): entryCount=\(weekData.entryCount), avgHR=\(weekData.averageHR)")
        }
        VStack(spacing: 12) {
            // Chart area
            GeometryReader { geometry in
                let maxHR = data.map { $0.maxHR }.max() ?? 100
                let minHR = data.map { $0.minHR }.filter { $0 > 0 }.min() ?? 60
                let range = max(maxHR - minHR, 20) // Minimum range of 20

                ZStack {
                    // Background grid
                    ForEach(0..<5) { i in
                        let y = geometry.size.height * CGFloat(i) / 4
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }

                    // Average line
                    Path { path in
                        for (index, weekData) in data.enumerated() {
                            if weekData.entryCount > 0 {
                                let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                                let y = geometry.size.height * (1 - CGFloat(weekData.averageHR - minHR) / CGFloat(range))

                                if index == 0 || data[index - 1].entryCount == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                    }
                    .stroke(Color.green, lineWidth: 2)

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, weekData in
                        if weekData.entryCount > 0 {
                            let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                            let y = geometry.size.height * (1 - CGFloat(weekData.averageHR - minHR) / CGFloat(range))

                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 120)
            .padding()

            // Week labels
            HStack {
                ForEach(Array(data.enumerated()), id: \.offset) { index, weekData in
                    VStack(spacing: 4) {
                        Text("Week \(4 - index)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if weekData.entryCount > 0 {
                            Text("\(weekData.averageHR)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("--")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct HeartRateHistoryRow: View {
    let entry: HeartRateEntry
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(healthManager.heartRateColor(for: entry.heartRate))
            
            Text("\(entry.heartRate) BPM")
                .font(.headline)
            
            // Posture context commented out for MVP2
            // if let context = entry.context {
            //     Text(context.contains("Standing") ? "Standing" : "Sitting")
            //         .font(.caption)
            //         .foregroundColor(.secondary)
            // }
            
            Spacer()
            
            Text(entry.formattedDateTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}