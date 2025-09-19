//
//  TestDataSettingsView.swift
//  SecureHeart
//
//  Settings UI for managing test data generation
//  Only visible in debug builds or when developer mode is enabled
//

import SwiftUI

struct TestDataSettingsView: View {
    @StateObject private var testDataManager = TestDataManager.shared
    @State private var showingClearConfirmation = false
    @State private var showingGenerateConfirmation = false

    var body: some View {
        List {
            // Master Control Section
            Section {
                HStack {
                    Image(systemName: "switch.2")
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    Toggle("Enable Test Data", isOn: .constant(testDataManager.isTestDataEnabled))
                        .disabled(true) // Automatically determined by environment

                    if testDataManager.isTestDataEnabled {
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text("Test data is \(testDataManager.isTestDataEnabled ? "enabled" : "disabled") in \(isSimulator ? "simulator" : "device") mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Master Control")
            }

            // Feature Toggles Section
            if testDataManager.isTestDataEnabled {
                Section {
                    ForEach(TestDataFeature.allCases, id: \.self) { feature in
                        TestDataToggleRow(
                            feature: feature,
                            testDataManager: testDataManager
                        )
                    }
                } header: {
                    Text("Feature Toggles")
                } footer: {
                    Text("Control which types of test data are generated")
                }

                // Configuration Section
                Section {
                    HStack {
                        Label("Historical Days", systemImage: "calendar")
                        Spacer()
                        Text("\(testDataManager.historicalDataDays) days")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Base Heart Rate", systemImage: "heart")
                        Spacer()
                        Text("\(testDataManager.baseHeartRate) BPM")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Variation Range", systemImage: "plusminus")
                        Spacer()
                        Text("±\(testDataManager.heartRateVariation) BPM")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Daily Events", systemImage: "figure.stand")
                        Spacer()
                        Text("\(testDataManager.orthostaticEventsPerDay) events")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Test Data Configuration")
                }

                // Actions Section
                Section {
                    Button(action: {
                        showingGenerateConfirmation = true
                    }) {
                        Label("Generate Test Data Now", systemImage: "wand.and.stars")
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        Label("Clear All Test Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }

                    Button(action: {
                        testDataManager.logConfiguration()
                    }) {
                        Label("Log Current Configuration", systemImage: "doc.text.magnifyingglass")
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Actions")
                }
            }

            // Information Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Test Data Usage", systemImage: "info.circle")
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text("• Test data is automatically generated in simulator")
                        .font(.caption)
                    Text("• Real devices use actual HealthKit data")
                        .font(.caption)
                    Text("• Export fallback generates sample data when empty")
                        .font(.caption)
                    Text("• Daily graphs use test data as fallback")
                        .font(.caption)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Version 1.0 - Test Data Manager")
                    .font(.caption2)
            }
        }
        .navigationTitle("Test Data Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Generate Test Data", isPresented: $showingGenerateConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Generate", role: .destructive) {
                generateAllTestData()
            }
        } message: {
            Text("This will generate comprehensive test data for all enabled features. Continue?")
        }
        .alert("Clear Test Data", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                testDataManager.clearAllTestData()
            }
        } message: {
            Text("This will permanently delete all test data. This action cannot be undone.")
        }
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func generateAllTestData() {
        // This would call the existing test data generation functions
        // based on which features are enabled
        print("🎯 [TestDataSettings] Generating test data for enabled features...")

        if testDataManager.shouldGenerateTestData(for: .heartRateHistory) {
            // Call generateRealisticMedicalTestData() from HealthManager
            print("  ✅ Generating heart rate history")
        }

        if testDataManager.shouldGenerateTestData(for: .orthostaticEvents) {
            // Generate orthostatic events
            print("  ✅ Generating orthostatic events")
        }

        // ... etc for other features
    }
}

// MARK: - Toggle Row Component

struct TestDataToggleRow: View {
    let feature: TestDataFeature
    @ObservedObject var testDataManager: TestDataManager

    var isEnabled: Binding<Bool> {
        Binding(
            get: {
                switch feature {
                case .heartRateHistory:
                    return testDataManager.generateHeartRateHistory
                case .orthostaticEvents:
                    return testDataManager.generateOrthostaticEvents
                case .dailyPatterns:
                    return testDataManager.generateDailyPatterns
                case .exportSamples:
                    return testDataManager.generateExportSamples
                case .liveUpdates:
                    return testDataManager.generateLiveUpdates
                }
            },
            set: { _ in
                testDataManager.toggle(feature)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isEnabled) {
                HStack {
                    Image(systemName: feature.icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.rawValue)
                            .font(.body)
                        Text(feature.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
struct TestDataSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TestDataSettingsView()
        }
    }
}
#endif