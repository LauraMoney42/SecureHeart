//
//  HistoryView.swift
//  Secure Heart
//
//  Heart rate history and orthostatic events display
//

import SwiftUI

enum HistorySortOption: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case heartRateHigh = "Heart Rate (High to Low)"
    case heartRateLow = "Heart Rate (Low to High)"
    case standingOnly = "Standing Only"
    case sittingOnly = "Sitting Only"
}

struct HistoryTabView: View {
    @ObservedObject var healthManager: HealthManager
    @State private var sortOption: HistorySortOption = .newestFirst
    @State private var showingSortMenu = false
    @State private var showingShareSheet = false
    
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
            Group {
                if sortedHistory.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Heart Rate Data Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Connect your Apple Watch to start tracking heart rate data. It will appear here once you begin monitoring.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemGroupedBackground))
                } else {
                    List {
                        // Heart Rate History Section Only - Simplified
                        ForEach(sortedHistory) { entry in
                            HeartRateHistoryRow(entry: entry, healthManager: healthManager)
                        }
                    }
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