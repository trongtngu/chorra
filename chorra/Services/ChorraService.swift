//
//  ChorraService.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import Foundation
import Supabase

struct ParentDashboardData: Hashable {
    let profile: Profile
    let household: Household
    let parents: [Profile]
    let children: [Child]
    let balances: [ChildPointsBalance]
    let childTaskItems: [ParentChildTaskItem]
    let taskItems: [ParentTaskItem]
    let reviewItems: [ParentTaskReviewItem]
    let rewards: [RewardItem]
    let redemptions: [RewardRedemptionItem]
}

struct ChildDashboardData: Hashable {
    let child: Child
    let tasks: [ChildTaskItem]
    let balance: ChildPointsBalance?
    let ledger: [PointsLedgerEntry]
    let rewards: [RewardItem]
    let redemptions: [RewardRedemptionItem]
}

final class ChorraService {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signUpParent(email: String, password: String, displayName: String, householdName: String) async throws -> ParentDashboardData {
        try await client.auth.signUp(email: email, password: password)
        let profile = try await bootstrapParent(displayName: displayName, householdName: householdName)
        return try await loadParentDashboard(profile: profile)
    }

    func signUpParentToHousehold(email: String, password: String, displayName: String, householdCode: String) async throws -> ParentDashboardData {
        do {
            try await client.auth.signUp(email: email, password: password)
        } catch let signUpError {
            do {
                _ = try await client.auth.user()
            } catch {
                throw signUpError
            }
        }

        let profile = try await joinParentHousehold(displayName: displayName, householdCode: householdCode)
        return try await loadParentDashboard(profile: profile)
    }

    func signInParent(email: String, password: String) async throws -> ParentDashboardData {
        try await client.auth.signIn(email: email, password: password)
        let profile = try await fetchCurrentProfile()
        guard profile.role == .parent else {
            throw ChorraServiceError.unexpectedRole
        }
        return try await loadParentDashboard(profile: profile)
    }

    func bootstrapParent(displayName: String, householdName: String) async throws -> Profile {
        let params = BootstrapParentParams(pDisplayName: displayName, pHouseholdName: householdName)
        return try await client
            .rpc("bootstrap_parent", params: params)
            .execute()
            .value
    }

    func joinParentHousehold(displayName: String, householdCode: String) async throws -> Profile {
        let params = JoinParentHouseholdParams(pDisplayName: displayName, pHouseholdCode: householdCode)
        return try await client
            .rpc("join_parent_household", params: params)
            .execute()
            .value
    }

    func claimChildSession(householdCode: String, loginName: String, pin: String) async throws -> ChildDashboardData {
        try? await client.auth.signOut()
        try await client.auth.signInAnonymously()

        let child: Child = try await client
            .rpc("claim_child_session", params: ClaimChildSessionParams(
                pHouseholdCode: householdCode,
                pLoginName: loginName,
                pPin: pin
            ))
            .execute()
            .value

        return try await loadChildDashboard(child: child)
    }

    func restoreSession() async throws -> AppSession {
        let profile = try await fetchCurrentProfile()

        switch profile.role {
        case .parent:
            return .parent(try await loadParentDashboard(profile: profile))
        case .child:
            let child: Child = try await client
                .from("children")
                .select()
                .single()
                .execute()
                .value
            return .child(try await loadChildDashboard(child: child))
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func addChild(displayName: String, loginName: String, pin: String) async throws -> ParentDashboardData {
        let _: Child = try await client
            .rpc("create_child", params: CreateChildParams(
                pDisplayName: displayName,
                pLoginName: loginName,
                pPin: pin
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func createTask(
        title: String,
        pointValue: Int,
        cardColorHex: String,
        iconName: String
    ) async throws -> ParentDashboardData {
        let _: ChorraTask = try await client
            .rpc("create_task", params: CreateTaskParams(
                pTitle: title,
                pPointValue: pointValue,
                pCardColorHex: cardColorHex,
                pIconName: ChorraIconCatalog.normalizedIconName(iconName)
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func updateTask(
        task: ChorraTask,
        title: String,
        pointValue: Int,
        cardColorHex: String,
        iconName: String
    ) async throws -> ParentDashboardData {
        let _: ChorraTask = try await client
            .rpc("update_task", params: UpdateTaskParams(
                pTaskId: task.id,
                pTitle: title,
                pPointValue: pointValue,
                pCardColorHex: cardColorHex,
                pIconName: ChorraIconCatalog.normalizedIconName(iconName)
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func archiveTask(_ task: ChorraTask) async throws -> ParentDashboardData {
        let _: ChorraTask = try await client
            .rpc("archive_task", params: ArchiveTaskParams(pTaskId: task.id))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func assignTask(_ task: ChorraTask, childId: UUID) async throws -> ParentDashboardData {
        let _: TaskAssignment = try await client
            .rpc("assign_task", params: AssignTaskParams(
                pTaskId: task.id,
                pChildId: childId
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func updateTaskAssignment(
        assignment: TaskAssignment,
        title: String,
        pointValue: Int,
        cardColorHex: String,
        iconName: String
    ) async throws -> ParentDashboardData {
        let _: TaskAssignment = try await client
            .rpc("update_task_assignment", params: UpdateTaskAssignmentParams(
                pAssignmentId: assignment.id,
                pTitle: title,
                pPointValue: pointValue,
                pCardColorHex: cardColorHex,
                pIconName: ChorraIconCatalog.normalizedIconName(iconName)
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func archiveTaskAssignment(_ assignment: TaskAssignment) async throws -> ParentDashboardData {
        let _: TaskAssignment = try await client
            .rpc("archive_task_assignment", params: ArchiveTaskAssignmentParams(pAssignmentId: assignment.id))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func submitTaskCompletion(
        assignment: TaskAssignment,
        child: Child,
        taskJPEGData: Data,
        faceJPEGData: Data
    ) async throws -> ChildDashboardData {
        let submissionId = UUID()
        let storagePathPrefix = "\(child.householdId.uuidString)/\(child.id.uuidString)/\(submissionId.uuidString)"
        let taskStoragePath = "\(storagePathPrefix)/task.jpg"
        let faceStoragePath = "\(storagePathPrefix)/face.jpg"

        try await client.storage
            .from("task-photos")
            .upload(
                taskStoragePath,
                data: taskJPEGData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        try await client.storage
            .from("task-photos")
            .upload(
                faceStoragePath,
                data: faceJPEGData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        let _: TaskSubmission = try await client
            .rpc("submit_task_completion", params: SubmitTaskCompletionParams(
                pAssignmentId: assignment.id,
                pTaskStoragePath: taskStoragePath,
                pFaceStoragePath: faceStoragePath,
                pSubmissionId: submissionId
            ))
            .execute()
            .value

        return try await loadChildDashboard(child: child)
    }

    func reviewSubmission(submissionId: UUID, decision: SubmissionStatus, rejectionReason: String?) async throws -> ParentDashboardData {
        let _: TaskSubmission = try await client
            .rpc("review_task_submission", params: ReviewTaskSubmissionParams(
                pSubmissionId: submissionId,
                pDecision: decision,
                pRejectionReason: rejectionReason
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func createReward(name: String, iconName: String, pointCost: Int, cardColorHex: String) async throws -> ParentDashboardData {
        let profile = try await fetchCurrentProfile()
        guard profile.role == .parent else {
            throw ChorraServiceError.unexpectedRole
        }

        let rewardId = UUID()

        let _: Reward = try await client
            .rpc("create_reward", params: CreateRewardParams(
                pName: name,
                pIconName: ChorraIconCatalog.normalizedIconName(iconName),
                pPointCost: pointCost,
                pCardColorHex: cardColorHex,
                pRewardId: rewardId
            ))
            .execute()
            .value

        return try await loadParentDashboard(profile: profile)
    }

    func updateReward(
        reward: Reward,
        name: String,
        iconName: String,
        pointCost: Int,
        cardColorHex: String
    ) async throws -> ParentDashboardData {
        let _: Reward = try await client
            .rpc("update_reward", params: UpdateRewardParams(
                pRewardId: reward.id,
                pName: name,
                pIconName: ChorraIconCatalog.normalizedIconName(iconName),
                pPointCost: pointCost,
                pCardColorHex: cardColorHex
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func archiveReward(_ reward: Reward) async throws -> ParentDashboardData {
        let _: Reward = try await client
            .rpc("archive_reward", params: ArchiveRewardParams(pRewardId: reward.id))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func redeemReward(_ reward: Reward, child: Child) async throws -> ChildDashboardData {
        let _: RewardRedemption = try await client
            .rpc("redeem_reward", params: RedeemRewardParams(pRewardId: reward.id))
            .execute()
            .value

        return try await loadChildDashboard(child: child)
    }

    func signedTaskPhotoURL(path: String) async throws -> URL {
        try await client.storage
            .from("task-photos")
            .createSignedURL(path: path, expiresIn: 60 * 10)
    }

    private func loadCurrentParentDashboard() async throws -> ParentDashboardData {
        let profile = try await fetchCurrentProfile()
        guard profile.role == .parent else {
            throw ChorraServiceError.unexpectedRole
        }
        return try await loadParentDashboard(profile: profile)
    }

    private func loadParentDashboard(profile: Profile) async throws -> ParentDashboardData {
        let household: Household = try await client
            .from("households")
            .select()
            .eq("id", value: profile.householdId.uuidString)
            .single()
            .execute()
            .value

        let children: [Child] = try await client
            .from("children")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .execute()
            .value

        let parents: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .eq("role", value: UserRole.parent.rawValue)
            .execute()
            .value

        let balances: [ChildPointsBalance] = try await client
            .from("child_points_balances")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .execute()
            .value

        let tasks: [ChorraTask] = try await client
            .from("tasks")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .eq("is_archived", value: false)
            .execute()
            .value

        let assignments: [TaskAssignment] = try await client
            .from("task_assignments")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .eq("is_archived", value: false)
            .execute()
            .value

        let submissions: [TaskSubmission] = try await client
            .from("task_submissions")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .execute()
            .value

        let images: [TaskSubmissionImage] = try await client
            .from("task_submission_images")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .execute()
            .value

        let rewards: [Reward] = try await client
            .from("rewards")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .eq("is_archived", value: false)
            .execute()
            .value

        let redemptions: [RewardRedemption] = try await client
            .from("reward_redemptions")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
            .execute()
            .value

        let taskItems = buildParentTaskItems(tasks: tasks)
        let reviewItems = buildParentTaskReviewItems(
            assignments: assignments,
            children: children,
            submissions: submissions,
            images: images
        )
        let childTaskItems = buildParentChildTaskItems(
            assignments: assignments,
            submissions: submissions
        )
        let redemptionItems = buildRedemptionItems(redemptions: redemptions, children: children)

        return ParentDashboardData(
            profile: profile,
            household: household,
            parents: parents.sorted { $0.displayName < $1.displayName },
            children: children.sorted { $0.displayName < $1.displayName },
            balances: balances,
            childTaskItems: childTaskItems,
            taskItems: taskItems,
            reviewItems: reviewItems,
            rewards: buildRewardItems(rewards: rewards),
            redemptions: redemptionItems
        )
    }

    private func loadChildDashboard(child: Child) async throws -> ChildDashboardData {
        let assignments: [TaskAssignment] = try await client
            .from("task_assignments")
            .select()
            .eq("is_archived", value: false)
            .execute()
            .value

        let submissions: [TaskSubmission] = try await client
            .from("task_submissions")
            .select()
            .execute()
            .value

        let balances: [ChildPointsBalance] = try await client
            .from("child_points_balances")
            .select()
            .execute()
            .value

        let ledger: [PointsLedgerEntry] = try await client
            .from("points_ledger")
            .select()
            .execute()
            .value

        let rewards: [Reward] = try await client
            .from("rewards")
            .select()
            .eq("is_archived", value: false)
            .execute()
            .value

        let redemptions: [RewardRedemption] = try await client
            .from("reward_redemptions")
            .select()
            .eq("child_id", value: child.id.uuidString)
            .execute()
            .value

        let submissionsByAssignment = Dictionary(grouping: submissions, by: \.assignmentId)
        let ledgerByAssignment = Dictionary(grouping: ledger, by: \.assignmentId)

        let childTasks = assignments.map { assignment -> ChildTaskItem in
            let latestSubmission = submissionsByAssignment[assignment.id]?.sorted { $0.createdAt > $1.createdAt }.first
            let pointsEarned = ledgerByAssignment[assignment.id]?.reduce(0) { $0 + $1.amount } ?? 0

            return ChildTaskItem(
                assignment: assignment,
                latestSubmission: latestSubmission,
                pointsEarned: pointsEarned
            )
        }
        .sorted { $0.assignment.assignedAt > $1.assignment.assignedAt }

        return ChildDashboardData(
            child: child,
            tasks: childTasks,
            balance: balances.first(where: { $0.childId == child.id }),
            ledger: ledger.sorted { $0.createdAt > $1.createdAt },
            rewards: buildRewardItems(rewards: rewards),
            redemptions: buildRedemptionItems(redemptions: redemptions, children: [child])
        )
    }

    private func fetchCurrentProfile() async throws -> Profile {
        let user = try await client.auth.user()

        return try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()
            .value
    }

    private func buildParentTaskItems(tasks: [ChorraTask]) -> [ParentTaskItem] {
        tasks
            .map { ParentTaskItem(task: $0) }
            .sorted { $0.task.createdAt > $1.task.createdAt }
    }

    private func buildParentChildTaskItems(
        assignments: [TaskAssignment],
        submissions: [TaskSubmission]
    ) -> [ParentChildTaskItem] {
        let activeStatuses: Set<TaskStatus> = [.assigned, .rejected, .submitted]
        let submissionsByAssignment = Dictionary(grouping: submissions, by: \.assignmentId)

        return assignments
            .filter { activeStatuses.contains($0.status) }
            .map { assignment in
                ParentChildTaskItem(
                    assignment: assignment,
                    latestSubmission: submissionsByAssignment[assignment.id]?.sorted { $0.createdAt > $1.createdAt }.first
                )
            }
            .sorted { $0.assignment.assignedAt > $1.assignment.assignedAt }
    }

    private func buildParentTaskReviewItems(
        assignments: [TaskAssignment],
        children: [Child],
        submissions: [TaskSubmission],
        images: [TaskSubmissionImage]
    ) -> [ParentTaskReviewItem] {
        let childrenById = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })
        let submissionsByAssignment = Dictionary(grouping: submissions, by: \.assignmentId)
        let imagesBySubmission = Dictionary(grouping: images, by: \.submissionId)

        return assignments
            .compactMap { assignment -> ParentTaskReviewItem? in
                let latestSubmission = submissionsByAssignment[assignment.id]?.sorted { $0.createdAt > $1.createdAt }.first

                guard latestSubmission?.status == .submitted else {
                    return nil
                }

                let submissionImages = latestSubmission.flatMap { imagesBySubmission[$0.id] } ?? []

                return ParentTaskReviewItem(
                    assignment: assignment,
                    child: childrenById[assignment.childId],
                    latestSubmission: latestSubmission,
                    taskImage: submissionImages.first(where: { $0.imageKind == .task }),
                    faceImage: submissionImages.first(where: { $0.imageKind == .face }),
                    signedTaskImageURL: nil,
                    signedFaceImageURL: nil
                )
            }
            .sorted {
                ($0.latestSubmission?.createdAt ?? $0.assignment.assignedAt) >
                    ($1.latestSubmission?.createdAt ?? $1.assignment.assignedAt)
            }
    }

    private func buildRewardItems(rewards: [Reward]) -> [RewardItem] {
        rewards
            .map { RewardItem(reward: $0) }
            .sorted { $0.reward.createdAt > $1.reward.createdAt }
    }

    private func buildRedemptionItems(redemptions: [RewardRedemption], children: [Child]) -> [RewardRedemptionItem] {
        let childrenById = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })

        return redemptions
            .map { redemption in
                RewardRedemptionItem(
                    redemption: redemption,
                    child: childrenById[redemption.childId]
                )
            }
            .sorted { $0.redemption.redeemedAt > $1.redemption.redeemedAt }
    }
}

enum ChorraServiceError: LocalizedError {
    case unexpectedRole

    var errorDescription: String? {
        switch self {
        case .unexpectedRole:
            return "This account is not allowed to use that Chorra flow."
        }
    }
}

enum AppSession: Hashable {
    case signedOut
    case parent(ParentDashboardData)
    case child(ChildDashboardData)
}

private struct BootstrapParentParams: Encodable {
    let pDisplayName: String
    let pHouseholdName: String

    enum CodingKeys: String, CodingKey {
        case pDisplayName = "p_display_name"
        case pHouseholdName = "p_household_name"
    }
}

private struct JoinParentHouseholdParams: Encodable {
    let pDisplayName: String
    let pHouseholdCode: String

    enum CodingKeys: String, CodingKey {
        case pDisplayName = "p_display_name"
        case pHouseholdCode = "p_household_code"
    }
}

private struct CreateChildParams: Encodable {
    let pDisplayName: String
    let pLoginName: String
    let pPin: String

    enum CodingKeys: String, CodingKey {
        case pDisplayName = "p_display_name"
        case pLoginName = "p_login_name"
        case pPin = "p_pin"
    }
}

private struct ClaimChildSessionParams: Encodable {
    let pHouseholdCode: String
    let pLoginName: String
    let pPin: String

    enum CodingKeys: String, CodingKey {
        case pHouseholdCode = "p_household_code"
        case pLoginName = "p_login_name"
        case pPin = "p_pin"
    }
}

private struct CreateTaskParams: Encodable {
    let pTitle: String
    let pPointValue: Int
    let pCardColorHex: String
    let pIconName: String

    enum CodingKeys: String, CodingKey {
        case pTitle = "p_title"
        case pPointValue = "p_point_value"
        case pCardColorHex = "p_card_color_hex"
        case pIconName = "p_icon_name"
    }
}

private struct AssignTaskParams: Encodable {
    let pTaskId: UUID
    let pChildId: UUID

    enum CodingKeys: String, CodingKey {
        case pTaskId = "p_task_id"
        case pChildId = "p_child_id"
    }
}

private struct UpdateTaskParams: Encodable {
    let pTaskId: UUID
    let pTitle: String
    let pPointValue: Int
    let pCardColorHex: String
    let pIconName: String

    enum CodingKeys: String, CodingKey {
        case pTaskId = "p_task_id"
        case pTitle = "p_title"
        case pPointValue = "p_point_value"
        case pCardColorHex = "p_card_color_hex"
        case pIconName = "p_icon_name"
    }
}

private struct ArchiveTaskParams: Encodable {
    let pTaskId: UUID

    enum CodingKeys: String, CodingKey {
        case pTaskId = "p_task_id"
    }
}

private struct UpdateTaskAssignmentParams: Encodable {
    let pAssignmentId: UUID
    let pTitle: String
    let pPointValue: Int
    let pCardColorHex: String
    let pIconName: String

    enum CodingKeys: String, CodingKey {
        case pAssignmentId = "p_assignment_id"
        case pTitle = "p_title"
        case pPointValue = "p_point_value"
        case pCardColorHex = "p_card_color_hex"
        case pIconName = "p_icon_name"
    }
}

private struct ArchiveTaskAssignmentParams: Encodable {
    let pAssignmentId: UUID

    enum CodingKeys: String, CodingKey {
        case pAssignmentId = "p_assignment_id"
    }
}

private struct SubmitTaskCompletionParams: Encodable {
    let pAssignmentId: UUID
    let pTaskStoragePath: String
    let pFaceStoragePath: String
    let pSubmissionId: UUID

    enum CodingKeys: String, CodingKey {
        case pAssignmentId = "p_assignment_id"
        case pTaskStoragePath = "p_task_storage_path"
        case pFaceStoragePath = "p_face_storage_path"
        case pSubmissionId = "p_submission_id"
    }
}

private struct ReviewTaskSubmissionParams: Encodable {
    let pSubmissionId: UUID
    let pDecision: SubmissionStatus
    let pRejectionReason: String?

    enum CodingKeys: String, CodingKey {
        case pSubmissionId = "p_submission_id"
        case pDecision = "p_decision"
        case pRejectionReason = "p_rejection_reason"
    }
}

private struct CreateRewardParams: Encodable {
    let pName: String
    let pIconName: String
    let pPointCost: Int
    let pCardColorHex: String
    let pRewardId: UUID

    enum CodingKeys: String, CodingKey {
        case pName = "p_name"
        case pIconName = "p_icon_name"
        case pPointCost = "p_point_cost"
        case pCardColorHex = "p_card_color_hex"
        case pRewardId = "p_reward_id"
    }
}

private struct UpdateRewardParams: Encodable {
    let pRewardId: UUID
    let pName: String
    let pIconName: String
    let pPointCost: Int
    let pCardColorHex: String

    enum CodingKeys: String, CodingKey {
        case pRewardId = "p_reward_id"
        case pName = "p_name"
        case pIconName = "p_icon_name"
        case pPointCost = "p_point_cost"
        case pCardColorHex = "p_card_color_hex"
    }
}

private struct ArchiveRewardParams: Encodable {
    let pRewardId: UUID

    enum CodingKeys: String, CodingKey {
        case pRewardId = "p_reward_id"
    }
}

private struct RedeemRewardParams: Encodable {
    let pRewardId: UUID

    enum CodingKeys: String, CodingKey {
        case pRewardId = "p_reward_id"
    }
}
