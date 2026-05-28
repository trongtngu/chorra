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
    let children: [Child]
    let balances: [ChildPointsBalance]
    let taskItems: [ParentTaskItem]
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

enum RewardImageUpdate: Hashable {
    case keep
    case remove
    case replace(Data)
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

    func createAssignedTask(childId: UUID, title: String, description: String, pointValue: Int) async throws -> ParentDashboardData {
        let _: TaskAssignment = try await client
            .rpc("create_assigned_task", params: CreateAssignedTaskParams(
                pChildId: childId,
                pTitle: title,
                pDescription: description,
                pPointValue: pointValue
            ))
            .execute()
            .value

        return try await loadCurrentParentDashboard()
    }

    func submitTaskCompletion(assignment: TaskAssignment, child: Child, jpegData: Data) async throws -> ChildDashboardData {
        let submissionId = UUID()
        let storagePath = "\(child.householdId.uuidString)/\(child.id.uuidString)/\(submissionId.uuidString)/completion.jpg"

        try await client.storage
            .from("task-photos")
            .upload(
                storagePath,
                data: jpegData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        let _: TaskSubmission = try await client
            .rpc("submit_task_completion", params: SubmitTaskCompletionParams(
                pAssignmentId: assignment.id,
                pStoragePath: storagePath,
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

    func createReward(name: String, description: String, pointCost: Int, jpegData: Data?) async throws -> ParentDashboardData {
        let profile = try await fetchCurrentProfile()
        guard profile.role == .parent else {
            throw ChorraServiceError.unexpectedRole
        }

        let rewardId = UUID()
        let imageStoragePath: String?

        if let jpegData {
            imageStoragePath = try await uploadRewardImage(
                householdId: profile.householdId,
                rewardId: rewardId,
                jpegData: jpegData
            )
        } else {
            imageStoragePath = nil
        }

        let _: Reward = try await client
            .rpc("create_reward", params: CreateRewardParams(
                pName: name,
                pDescription: description,
                pPointCost: pointCost,
                pImageStoragePath: imageStoragePath,
                pRewardId: rewardId
            ))
            .execute()
            .value

        return try await loadParentDashboard(profile: profile)
    }

    func updateReward(
        reward: Reward,
        name: String,
        description: String,
        pointCost: Int,
        imageUpdate: RewardImageUpdate
    ) async throws -> ParentDashboardData {
        let imageStoragePath: String?

        switch imageUpdate {
        case .keep:
            imageStoragePath = reward.imageStoragePath
        case .remove:
            imageStoragePath = nil
        case .replace(let jpegData):
            imageStoragePath = try await uploadRewardImage(
                householdId: reward.householdId,
                rewardId: reward.id,
                jpegData: jpegData
            )
        }

        let _: Reward = try await client
            .rpc("update_reward", params: UpdateRewardParams(
                pRewardId: reward.id,
                pName: name,
                pDescription: description,
                pPointCost: pointCost,
                pImageStoragePath: imageStoragePath
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

    func signedRewardImageURL(path: String) async throws -> URL {
        try await client.storage
            .from("reward-images")
            .createSignedURL(path: path, expiresIn: 60 * 10)
    }

    private func uploadRewardImage(householdId: UUID, rewardId: UUID, jpegData: Data) async throws -> String {
        let storagePath = "\(householdId.uuidString)/\(rewardId.uuidString)/\(UUID().uuidString).jpg"

        try await client.storage
            .from("reward-images")
            .upload(
                storagePath,
                data: jpegData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        return storagePath
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
            .execute()
            .value

        let assignments: [TaskAssignment] = try await client
            .from("task_assignments")
            .select()
            .eq("household_id", value: profile.householdId.uuidString)
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

        let taskItems = await buildParentTaskItems(
            tasks: tasks,
            assignments: assignments,
            children: children,
            submissions: submissions,
            images: images
        )
        let redemptionItems = buildRedemptionItems(redemptions: redemptions, children: children)

        return ParentDashboardData(
            profile: profile,
            household: household,
            children: children.sorted { $0.displayName < $1.displayName },
            balances: balances,
            taskItems: taskItems,
            rewards: buildRewardItems(rewards: rewards),
            redemptions: redemptionItems
        )
    }

    private func loadChildDashboard(child: Child) async throws -> ChildDashboardData {
        let tasks: [ChorraTask] = try await client
            .from("tasks")
            .select()
            .execute()
            .value

        let assignments: [TaskAssignment] = try await client
            .from("task_assignments")
            .select()
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
        let ledgerByTask = Dictionary(grouping: ledger, by: \.taskId)
        let tasksById = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        let childTasks = assignments.compactMap { assignment -> ChildTaskItem? in
            guard let task = tasksById[assignment.taskId] else {
                return nil
            }

            let latestSubmission = submissionsByAssignment[assignment.id]?.sorted { $0.createdAt > $1.createdAt }.first
            let pointsEarned = ledgerByTask[task.id]?.reduce(0) { $0 + $1.amount } ?? 0

            return ChildTaskItem(
                task: task,
                assignment: assignment,
                latestSubmission: latestSubmission,
                pointsEarned: pointsEarned
            )
        }
        .sorted { $0.task.createdAt > $1.task.createdAt }

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

    private func buildParentTaskItems(
        tasks: [ChorraTask],
        assignments: [TaskAssignment],
        children: [Child],
        submissions: [TaskSubmission],
        images: [TaskSubmissionImage]
    ) async -> [ParentTaskItem] {
        let assignmentsByTask = Dictionary(uniqueKeysWithValues: assignments.map { ($0.taskId, $0) })
        let childrenById = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })
        let submissionsByAssignment = Dictionary(grouping: submissions, by: \.assignmentId)
        let imagesBySubmission = Dictionary(uniqueKeysWithValues: images.map { ($0.submissionId, $0) })

        return tasks
            .map { task in
                let assignment = assignmentsByTask[task.id]
                let latestSubmission = assignment.flatMap { submissionsByAssignment[$0.id]?.sorted { $0.createdAt > $1.createdAt }.first }
                let image = latestSubmission.flatMap { imagesBySubmission[$0.id] }

                return ParentTaskItem(
                    task: task,
                    assignment: assignment,
                    child: assignment.flatMap { childrenById[$0.childId] },
                    latestSubmission: latestSubmission,
                    image: image,
                    signedImageURL: nil
                )
            }
            .sorted { $0.task.createdAt > $1.task.createdAt }
    }

    private func buildRewardItems(rewards: [Reward]) -> [RewardItem] {
        rewards
            .map { RewardItem(reward: $0, signedImageURL: nil) }
            .sorted { $0.reward.createdAt > $1.reward.createdAt }
    }

    private func buildRedemptionItems(redemptions: [RewardRedemption], children: [Child]) -> [RewardRedemptionItem] {
        let childrenById = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })

        return redemptions
            .map { redemption in
                RewardRedemptionItem(
                    redemption: redemption,
                    child: childrenById[redemption.childId],
                    signedImageURL: nil
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

private struct CreateAssignedTaskParams: Encodable {
    let pChildId: UUID
    let pTitle: String
    let pDescription: String
    let pPointValue: Int

    enum CodingKeys: String, CodingKey {
        case pChildId = "p_child_id"
        case pTitle = "p_title"
        case pDescription = "p_description"
        case pPointValue = "p_point_value"
    }
}

private struct SubmitTaskCompletionParams: Encodable {
    let pAssignmentId: UUID
    let pStoragePath: String
    let pSubmissionId: UUID

    enum CodingKeys: String, CodingKey {
        case pAssignmentId = "p_assignment_id"
        case pStoragePath = "p_storage_path"
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
    let pDescription: String
    let pPointCost: Int
    let pImageStoragePath: String?
    let pRewardId: UUID

    enum CodingKeys: String, CodingKey {
        case pName = "p_name"
        case pDescription = "p_description"
        case pPointCost = "p_point_cost"
        case pImageStoragePath = "p_image_storage_path"
        case pRewardId = "p_reward_id"
    }
}

private struct UpdateRewardParams: Encodable {
    let pRewardId: UUID
    let pName: String
    let pDescription: String
    let pPointCost: Int
    let pImageStoragePath: String?

    enum CodingKeys: String, CodingKey {
        case pRewardId = "p_reward_id"
        case pName = "p_name"
        case pDescription = "p_description"
        case pPointCost = "p_point_cost"
        case pImageStoragePath = "p_image_storage_path"
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
