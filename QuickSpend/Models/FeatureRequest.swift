import Foundation
import SwiftUI

/// Feature request submitted by users, stored in Firestore
struct FeatureRequest: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let category: RequestCategory
    let status: RequestStatus
    let createdAt: Date
    let updatedAt: Date
    let appVersion: String
    let language: String
    let adminResponse: String?
    /// Priority level: 0 = free user, 1 = premium user
    let priority: Int
}

/// Categories for feature requests
enum RequestCategory: String, Codable, CaseIterable {
    case newFeature = "new_feature"
    case improvement = "improvement"
    case bugReport = "bug_report"
    case other = "other"

    func displayName(language: String) -> String {
        switch self {
        case .newFeature: return L10n.tr("feature_request.category_new_feature", language)
        case .improvement: return L10n.tr("feature_request.category_improvement", language)
        case .bugReport: return L10n.tr("feature_request.category_bug_report", language)
        case .other: return L10n.tr("feature_request.category_other", language)
        }
    }

    var iconName: String {
        switch self {
        case .newFeature: return "lightbulb.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .bugReport: return "ladybug.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// Status of a feature request (managed server-side, read-only in app)
enum RequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case underReview = "under_review"
    case planned = "planned"
    case completed = "completed"
    case declined = "declined"

    func displayName(language: String) -> String {
        switch self {
        case .pending: return L10n.tr("feature_request.status_pending", language)
        case .underReview: return L10n.tr("feature_request.status_under_review", language)
        case .planned: return L10n.tr("feature_request.status_planned", language)
        case .completed: return L10n.tr("feature_request.status_completed", language)
        case .declined: return L10n.tr("feature_request.status_declined", language)
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .underReview: return AppTheme.accentOrange
        case .planned: return AppTheme.primaryLight
        case .completed: return AppTheme.success
        case .declined: return AppTheme.error
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .underReview: return "eye.fill"
        case .planned: return "calendar.badge.checkmark"
        case .completed: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        }
    }
}
