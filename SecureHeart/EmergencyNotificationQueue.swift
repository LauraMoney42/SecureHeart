//
//  EmergencyNotificationQueue.swift
//  SecureHeart
//
//  Emergency notification queue with offline support and retry logic
//

import Foundation
import Network
import UserNotifications

// MARK: - Notification Queue Entry
struct QueuedNotification: Codable, Identifiable {
    let id = UUID()
    let contactName: String
    let contactPhone: String
    let contactEmail: String?
    let message: String
    let heartRate: Int
    let timestamp: Date
    let emergencyID: String
    var attemptCount: Int = 0
    var lastAttempt: Date?
    var nextRetryAt: Date?
    var status: NotificationStatus = .pending
    let priority: NotificationPriority

    enum NotificationStatus: String, Codable {
        case pending
        case sending
        case sent
        case failed
        case expired
    }

    enum NotificationPriority: Int, Codable, Comparable {
        case critical = 3  // Life-threatening emergency
        case high = 2      // Urgent medical alert
        case normal = 1    // Standard notification

        static func < (lhs: NotificationPriority, rhs: NotificationPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Emergency Notification Queue Manager
class EmergencyNotificationQueue: ObservableObject {
    static let shared = EmergencyNotificationQueue()

    @Published var isOnline: Bool = true
    @Published var queueCount: Int = 0
    @Published var lastProcessedAt: Date?

    private var queue: [QueuedNotification] = []
    private var networkMonitor: NWPathMonitor
    private var networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var processingTimer: Timer?
    private let maxRetryAttempts = 5
    private let maxRetryInterval: TimeInterval = 300 // 5 minutes
    private let queueKey = "EmergencyNotificationQueue"

    private init() {
        networkMonitor = NWPathMonitor()
        setupNetworkMonitoring()
        loadQueue()
        startProcessingTimer()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    print("📶 Network connected - processing queued notifications")
                    self?.processQueue()
                } else {
                    print("📶 Network disconnected - notifications will be queued")
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Queue Management

    func enqueue(_ notification: QueuedNotification) {
        DispatchQueue.main.async {
            self.queue.append(notification)
            self.queueCount = self.queue.count
            self.saveQueue()

            print("📋 Queued emergency notification for \(notification.contactName) (Priority: \(notification.priority))")

            // Try to process immediately if online
            if self.isOnline {
                self.processQueue()
            }
        }
    }

    func enqueueEmergencyAlert(
        contactName: String,
        contactPhone: String,
        contactEmail: String? = nil,
        heartRate: Int,
        emergencyID: String,
        priority: QueuedNotification.NotificationPriority = .critical
    ) {
        let message = generateEmergencyMessage(heartRate: heartRate)

        let notification = QueuedNotification(
            contactName: contactName,
            contactPhone: contactPhone,
            contactEmail: contactEmail,
            message: message,
            heartRate: heartRate,
            timestamp: Date(),
            emergencyID: emergencyID,
            priority: priority
        )

        enqueue(notification)
    }

    private func generateEmergencyMessage(heartRate: Int) -> String {
        let severity = heartRate > 150 ? "CRITICAL" : heartRate < 40 ? "CRITICAL" : "HIGH"

        return """
        🚨 \(severity) EMERGENCY ALERT 🚨

        SecureHeart POTS Monitor Alert:
        Heart Rate: \(heartRate) BPM
        Time: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))

        Please check on your contact immediately.
        This is a life-critical alert from the SecureHeart app.

        Emergency ID: \(UUID().uuidString.prefix(8))
        """
    }

    // MARK: - Queue Processing

    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.processQueue()
        }
    }

    private func processQueue() {
        guard isOnline && !queue.isEmpty else { return }

        // Sort by priority and timestamp
        queue.sort { notification1, notification2 in
            if notification1.priority != notification2.priority {
                return notification1.priority > notification2.priority
            }
            return notification1.timestamp < notification2.timestamp
        }

        let pendingNotifications = queue.filter { notification in
            notification.status == .pending ||
            (notification.status == .failed && shouldRetry(notification))
        }

        for notification in pendingNotifications.prefix(3) { // Process max 3 at a time
            processNotification(notification)
        }

        // Clean up expired notifications
        cleanupExpiredNotifications()

        lastProcessedAt = Date()
    }

    private func shouldRetry(_ notification: QueuedNotification) -> Bool {
        guard notification.attemptCount < maxRetryAttempts else {
            return false
        }

        guard let nextRetry = notification.nextRetryAt else {
            return true // Never attempted, can retry
        }

        return Date() >= nextRetry
    }

    private func processNotification(_ notification: QueuedNotification) {
        guard let index = queue.firstIndex(where: { $0.id == notification.id }) else { return }

        queue[index].status = .sending
        queue[index].lastAttempt = Date()
        queue[index].attemptCount += 1

        print("📤 Attempting to send notification to \(notification.contactName) (Attempt \(queue[index].attemptCount))")

        // Simulate notification sending
        sendNotification(queue[index]) { [weak self] success in
            DispatchQueue.main.async {
                self?.handleNotificationResult(notificationId: notification.id, success: success)
            }
        }
    }

    private func sendNotification(_ notification: QueuedNotification, completion: @escaping (Bool) -> Void) {
        // In a real implementation, this would:
        // 1. Send push notification via UNUserNotificationCenter
        // 2. Send SMS via Twilio API
        // 3. Send email via email service

        // Simulate network call with random success/failure
        DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 1...3)) {
            let success = Double.random(in: 0...1) > 0.2 // 80% success rate for testing
            completion(success)
        }
    }

    private func handleNotificationResult(notificationId: UUID, success: Bool) {
        guard let index = queue.firstIndex(where: { $0.id == notificationId }) else { return }

        if success {
            queue[index].status = .sent
            print("✅ Successfully sent notification to \(queue[index].contactName)")

            // Remove successful notifications after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                self.removeNotification(id: notificationId)
            }
        } else {
            queue[index].status = .failed
            queue[index].nextRetryAt = calculateNextRetryTime(attemptCount: queue[index].attemptCount)

            print("❌ Failed to send notification to \(queue[index].contactName). Will retry at \(queue[index].nextRetryAt!)")

            if queue[index].attemptCount >= maxRetryAttempts {
                queue[index].status = .expired
                print("🚫 Notification to \(queue[index].contactName) expired after \(maxRetryAttempts) attempts")
            }
        }

        saveQueue()
        queueCount = queue.count
    }

    private func calculateNextRetryTime(attemptCount: Int) -> Date {
        // Exponential backoff with jitter: 2^attempt * 30 seconds + random jitter
        let baseDelay = min(pow(2.0, Double(attemptCount)) * 30, maxRetryInterval)
        let jitter = Double.random(in: 0...30) // Add up to 30 seconds of jitter
        let delay = baseDelay + jitter

        return Date().addingTimeInterval(delay)
    }

    // MARK: - Queue Persistence

    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(queue)
            UserDefaults.standard.set(data, forKey: queueKey)
        } catch {
            print("❌ Failed to save notification queue: \(error)")
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return }

        do {
            queue = try JSONDecoder().decode([QueuedNotification].self, from: data)
            queueCount = queue.count
            print("📋 Loaded \(queue.count) queued notifications")
        } catch {
            print("❌ Failed to load notification queue: \(error)")
            queue = []
        }
    }

    // MARK: - Queue Maintenance

    private func cleanupExpiredNotifications() {
        let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours
        let initialCount = queue.count

        queue.removeAll { notification in
            notification.status == .sent ||
            notification.status == .expired ||
            (notification.status == .failed && notification.timestamp < oneDayAgo)
        }

        if queue.count != initialCount {
            print("🧹 Cleaned up \(initialCount - queue.count) old notifications")
            saveQueue()
            queueCount = queue.count
        }
    }

    private func removeNotification(id: UUID) {
        queue.removeAll { $0.id == id }
        saveQueue()
        queueCount = queue.count
    }

    // MARK: - Queue Status

    func getQueueStatus() -> [String: Any] {
        let statusCounts = Dictionary(grouping: queue, by: { $0.status.rawValue })
            .mapValues { $0.count }

        return [
            "total": queue.count,
            "isOnline": isOnline,
            "lastProcessed": lastProcessedAt?.timeIntervalSince1970 ?? 0,
            "statusBreakdown": statusCounts
        ]
    }

    func clearQueue() {
        queue.removeAll()
        queueCount = 0
        saveQueue()
        print("🗑️ Emergency notification queue cleared")
    }

    deinit {
        processingTimer?.invalidate()
        networkMonitor.cancel()
    }
}