import Foundation
import CloudKit
import CoreData
import SwiftData
import Combine

/// Monitors iCloud account status and CloudKit sync events.
/// Provides observable state for the UI to display sync status.
@Observable
final class CloudSyncService {
    private(set) var iCloudStatus: ICloudStatus = .unknown
    private(set) var lastSyncDate: Date?
    private(set) var isSyncing: Bool = false
    private(set) var lastError: String?

    /// True once the first CloudKit import event has completed (or we determined no import is needed).
    /// Used by ContentView to wait before deciding whether to show onboarding.
    private(set) var hasCompletedInitialImport: Bool = false

    /// True once the iCloud account status check has finished (regardless of result).
    private(set) var hasCheckedAccountStatus: Bool = false

    private var eventSubscription: AnyCancellable?
    private var importTimeoutTask: Task<Void, Never>?

    enum ICloudStatus: String {
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unknown
    }

    init() {
        checkAccountStatus()
        observeSyncEvents()
    }

    /// Check the current iCloud account status
    func checkAccountStatus() {
        Task {
            do {
                let status = try await CKContainer(
                    identifier: "iCloud.com.randomtech.quickSpend"
                ).accountStatus()

                await MainActor.run {
                    switch status {
                    case .available:
                        self.iCloudStatus = .available
                        // Start a timeout — if no import event arrives within 5 seconds,
                        // treat as "no remote data to import" (fresh iCloud or already synced)
                        self.startImportTimeout()
                    case .noAccount:
                        self.iCloudStatus = .noAccount
                        self.markInitialImportComplete()
                    case .restricted:
                        self.iCloudStatus = .restricted
                        self.markInitialImportComplete()
                    case .temporarilyUnavailable:
                        self.iCloudStatus = .temporarilyUnavailable
                        self.markInitialImportComplete()
                    @unknown default:
                        self.iCloudStatus = .unknown
                        self.markInitialImportComplete()
                    }
                    self.lastError = nil
                    self.hasCheckedAccountStatus = true
                }
            } catch {
                await MainActor.run {
                    self.iCloudStatus = .unknown
                    self.lastError = error.localizedDescription
                    self.hasCheckedAccountStatus = true
                    self.markInitialImportComplete()
                }
            }
        }
    }

    /// Listen for CloudKit sync lifecycle events via NSPersistentCloudKitContainer notifications
    private func observeSyncEvents() {
        eventSubscription = NotificationCenter.default.publisher(
            for: NSPersistentCloudKitContainer.eventChangedNotification
        )
        .compactMap { notification -> NSPersistentCloudKitContainer.Event? in
            notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] event in
            guard let self else { return }
            if event.endDate == nil {
                // Event started
                self.isSyncing = true
            } else {
                // Event finished
                self.isSyncing = false
                if let error = event.error {
                    self.lastError = error.localizedDescription
                } else {
                    self.lastError = nil
                    self.lastSyncDate = event.endDate
                }
                // An import event finished — the initial data pull is done
                if event.type == .import {
                    self.markInitialImportComplete()
                }
            }
        }
    }

    // MARK: - Initial Import Tracking

    private func markInitialImportComplete() {
        guard !hasCompletedInitialImport else { return }
        hasCompletedInitialImport = true
        importTimeoutTask?.cancel()
        importTimeoutTask = nil
    }

    /// Safety net: if iCloud is available but no import event arrives within 5 seconds,
    /// assume there's nothing to import (e.g., empty iCloud container or data already local).
    private func startImportTimeout() {
        importTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.markInitialImportComplete()
        }
    }

    /// Human-readable status description
    var statusDescription: String {
        switch iCloudStatus {
        case .available:
            if isSyncing {
                return "syncing"
            } else if let lastSync = lastSyncDate {
                return "last_synced_\(Self.relativeTimeString(from: lastSync))"
            } else {
                return "connected"
            }
        case .noAccount:
            return "no_account"
        case .restricted:
            return "restricted"
        case .temporarilyUnavailable:
            return "temporarily_unavailable"
        case .unknown:
            return "unknown"
        }
    }

    /// Whether iCloud sync is enabled and functional
    var isEnabled: Bool {
        iCloudStatus == .available
    }

    // MARK: - Helpers

    private static func relativeTimeString(from date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        if interval < 60 {
            return "just_now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m_ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h_ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d_ago"
        }
    }
}
