//
//  ChorraModels.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import Foundation

enum UserRole: String, Codable, Hashable {
    case parent
    case child
}

enum TaskStatus: String, Codable, Hashable, CaseIterable {
    case created
    case assigned
    case submitted
    case rejected
    case completed

    var label: String {
        switch self {
        case .created:
            return "Created"
        case .assigned:
            return "Assigned"
        case .submitted:
            return "Submitted"
        case .rejected:
            return "Needs work"
        case .completed:
            return "Complete"
        }
    }
}

enum SubmissionStatus: String, Codable, Hashable {
    case submitted
    case approved
    case rejected
}

enum LedgerReason: String, Codable, Hashable {
    case taskApproved = "task_approved"
}

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let role: UserRole
    let displayName: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case role
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Household: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let loginCode: String
    let createdBy: UUID
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case loginCode = "login_code"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Child: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let authUserId: UUID?
    let displayName: String
    let loginName: String
    let createdBy: UUID
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case authUserId = "auth_user_id"
        case displayName = "display_name"
        case loginName = "login_name"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChorraTask: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let createdBy: UUID
    let title: String
    let description: String?
    let pointValue: Int
    let cardColorHex: String
    let status: TaskStatus
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case createdBy = "created_by"
        case title
        case description
        case pointValue = "point_value"
        case cardColorHex = "card_color_hex"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TaskAssignment: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let taskId: UUID
    let childId: UUID
    let assignedBy: UUID
    let assignedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case taskId = "task_id"
        case childId = "child_id"
        case assignedBy = "assigned_by"
        case assignedAt = "assigned_at"
    }
}

struct TaskSubmission: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let assignmentId: UUID
    let childId: UUID
    let submittedBy: UUID
    let status: SubmissionStatus
    let rejectionReason: String?
    let reviewedBy: UUID?
    let reviewedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case assignmentId = "assignment_id"
        case childId = "child_id"
        case submittedBy = "submitted_by"
        case status
        case rejectionReason = "rejection_reason"
        case reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TaskSubmissionImage: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let submissionId: UUID
    let childId: UUID
    let storagePath: String
    let uploadedBy: UUID
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case submissionId = "submission_id"
        case childId = "child_id"
        case storagePath = "storage_path"
        case uploadedBy = "uploaded_by"
        case createdAt = "created_at"
    }
}

struct PointsLedgerEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let childId: UUID
    let taskId: UUID
    let submissionId: UUID
    let amount: Int
    let reason: LedgerReason
    let createdBy: UUID
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case childId = "child_id"
        case taskId = "task_id"
        case submissionId = "submission_id"
        case amount
        case reason
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct ChildPointsBalance: Codable, Identifiable, Hashable {
    let childId: UUID
    let householdId: UUID
    let points: Int
    let lastEarnedAt: String?

    var id: UUID { childId }

    enum CodingKeys: String, CodingKey {
        case childId = "child_id"
        case householdId = "household_id"
        case points
        case lastEarnedAt = "last_earned_at"
    }
}

struct Reward: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let createdBy: UUID
    let name: String
    let emoji: String
    let pointCost: Int
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case createdBy = "created_by"
        case name
        case emoji
        case pointCost = "point_cost"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RewardRedemption: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let childId: UUID
    let rewardId: UUID
    let redeemedBy: UUID
    let rewardName: String
    let rewardEmoji: String
    let rewardPointCost: Int
    let redeemedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case childId = "child_id"
        case rewardId = "reward_id"
        case redeemedBy = "redeemed_by"
        case rewardName = "reward_name"
        case rewardEmoji = "reward_emoji"
        case rewardPointCost = "reward_point_cost"
        case redeemedAt = "redeemed_at"
    }
}

struct ParentTaskItem: Identifiable, Hashable {
    let task: ChorraTask
    let assignment: TaskAssignment?
    let child: Child?
    let latestSubmission: TaskSubmission?
    let image: TaskSubmissionImage?
    var signedImageURL: URL?

    var id: UUID { task.id }
}

struct ChildTaskItem: Identifiable, Hashable {
    let task: ChorraTask
    let assignment: TaskAssignment
    let latestSubmission: TaskSubmission?
    let pointsEarned: Int

    var id: UUID { assignment.id }
}

struct RewardItem: Identifiable, Hashable {
    let reward: Reward

    var id: UUID { reward.id }
}

struct RewardRedemptionItem: Identifiable, Hashable {
    let redemption: RewardRedemption
    let child: Child?

    var id: UUID { redemption.id }
}
