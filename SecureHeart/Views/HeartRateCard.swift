//
//  HeartRateCard.swift
//  Secure Heart
//
//  Heart rate display card for dashboard
//

import SwiftUI

struct HeartRateCard: View {
    @ObservedObject var healthManager: HealthManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with centered title
            Text("Heart Rate")
                .font(.headline)
                .frame(maxWidth: .infinity)
            
            // Main horizontal layout: Heart Icon | BPM | Status
            HStack(alignment: .center, spacing: 20) {
                // Pulsing heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(healthManager.heartRateColor(for: healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate))
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
                
                // BPM display
                HStack(alignment: .bottom, spacing: 4) {
                    let heartRate = healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate
                    
                    if heartRate == 0 {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(heartRate)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Text("BPM")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                // Status (Heart Rate Zone) - Posture display commented out for MVP2
                VStack(alignment: .leading, spacing: 4) {
                    // if let recentEntry = healthManager.heartRateHistory.first,
                    //    let context = recentEntry.context {
                    //     Text(context.contains("Standing") ? "Standing" : "Sitting")
                    //         .font(.subheadline)
                    //         .fontWeight(.medium)
                    //         .foregroundColor(.primary)
                    // } else {
                        Text(getZoneText())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(getZoneColor())
                    // }
                    
                    
                    // Live indicator if applicable
                    if healthManager.isWatchConnected && healthManager.liveHeartRate > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Last Updated or No Data message - centered
            HStack {
                Spacer()
                
                let heartRate = healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate
                
                if heartRate == 0 {
                    Text("No data yet - connect your Apple Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(healthManager.lastUpdated)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            isAnimating = true
        }
    }
    
    private func getZoneText() -> String {
        let heartRate = healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate
        switch heartRate {
        case 0..<60:
            return "Low"
        case 60..<100:
            return "Normal"
        case 100..<140:
            return "Elevated"
        case 140..<170:
            return "High"
        default:
            return "Maximum"
        }
    }
    
    private func getZoneColor() -> Color {
        let heartRate = healthManager.liveHeartRate > 0 ? healthManager.liveHeartRate : healthManager.currentHeartRate
        switch heartRate {
        case 0..<60:
            return .blue
        case 60..<100:
            return .green
        case 100..<140:
            return .orange
        case 140..<170:
            return .red
        default:
            return .purple
        }
    }
}