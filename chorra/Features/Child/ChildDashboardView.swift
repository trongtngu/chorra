//
//  ChildDashboardView.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import PhotosUI
import SwiftUI
import UIKit

struct ChildDashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData

    @State private var selectedTab: ChildDashboardTab = .home
    @State private var rewardToRedeem: RewardItem?

    var body: some View {
        TabView(selection: $selectedTab) {
            ChildHomeTab(data: data)
                .environmentObject(appModel)
                .tag(ChildDashboardTab.home)
                .tabItem {
                    Label(ChildDashboardTab.home.title, systemImage: ChildDashboardTab.home.systemImage)
                }

            ChildRewardsTab(
                data: data,
                rewardToRedeem: $rewardToRedeem
            )
            .environmentObject(appModel)
            .tag(ChildDashboardTab.rewards)
            .tabItem {
                Label(ChildDashboardTab.rewards.title, systemImage: ChildDashboardTab.rewards.systemImage)
            }
        }
        .chorraTabBar()
        .background(Color.chorraBackground)
        .alert("Redeem reward?", isPresented: redeemConfirmationBinding, presenting: rewardToRedeem) { item in
            Button("Redeem for \(item.reward.pointCost) pts") {
                Task { await appModel.redeemReward(item.reward) }
            }
            .disabled(appModel.isWorking)

            Button("Cancel", role: .cancel) {
                rewardToRedeem = nil
            }
        } message: { item in
            Text(item.reward.name)
        }
    }

    private var redeemConfirmationBinding: Binding<Bool> {
        Binding {
            rewardToRedeem != nil
        } set: { isPresented in
            if !isPresented {
                rewardToRedeem = nil
            }
        }
    }
}

private enum ChildDashboardTab: Hashable, CaseIterable {
    case home
    case rewards

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .rewards:
            return "Rewards"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .rewards:
            return "gift.fill"
        }
    }
}

private struct ChildTabContainer<Content: View>: View {
    @EnvironmentObject private var appModel: AppViewModel

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ChorraScreen(title: title) {
                HStack(spacing: 8) {
                    Button {
                        Task { await appModel.refresh() }
                    } label: {
                        ChorraToolbarIcon(systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                    .disabled(appModel.isWorking)

                    Button {
                        Task { await appModel.signOut() }
                    } label: {
                        ChorraToolbarIcon(systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Sign out")
                    .disabled(appModel.isWorking)
                }
            } content: {
                content
            }
        }
    }
}

private struct ChildHomeTab: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData

    var body: some View {
        ChildTabContainer(title: "Home") {
            childSummaryCard

            ChorraSectionHeader(title: "Tasks")

            if data.tasks.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No tasks assigned", systemImage: "checklist")
                }
            } else {
                ForEach(data.tasks) { item in
                    ChorraCard {
                        if item.task.status == .assigned || item.task.status == .rejected {
                            NavigationLink {
                                ChildTaskDetailView(child: data.child, item: item)
                                    .environmentObject(appModel)
                            } label: {
                                ChildTaskRowView(item: item, showsDisclosure: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ChildTaskRowView(item: item, showsDisclosure: false)
                        }
                    }
                }
            }

            ChorraSectionHeader(title: "Earned")

            ChorraCard {
                if data.ledger.isEmpty {
                    ChorraEmptyState(title: "No points earned yet", systemImage: "star")
                } else {
                    ForEach(Array(data.ledger.enumerated()), id: \.element.id) { index, entry in
                        EarnedPointsRowView(entry: entry)

                        if index < data.ledger.count - 1 {
                            ChorraDivider()
                        }
                    }
                }
            }
        }
    }

    private var childSummaryCard: some View {
        ChorraCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.chorraPrimarySoft)

                    Text(String(data.child.displayName.prefix(1)).uppercased())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.chorraPrimary)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(data.child.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.chorraTextPrimary)

                    Text("@\(data.child.loginName)")
                        .font(.subheadline)
                        .foregroundStyle(Color.chorraTextSecondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                ChorraStatPill(
                    title: "points",
                    value: "\(data.balance?.points ?? 0)",
                    systemImage: "star.fill"
                )

                ChorraStatPill(
                    title: "tasks",
                    value: "\(openTaskCount)",
                    systemImage: "checklist"
                )
            }
        }
    }

    private var openTaskCount: Int {
        data.tasks.filter { $0.task.status == .assigned || $0.task.status == .rejected }.count
    }
}

private struct ChildRewardsTab: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData
    @Binding var rewardToRedeem: RewardItem?

    var body: some View {
        ChildTabContainer(title: "Rewards") {
            ChorraSectionHeader(title: "Rewards")

            if data.rewards.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No rewards available", systemImage: "gift")
                }
            } else {
                ForEach(data.rewards) { item in
                    ChorraCard {
                        ChildRewardRowView(
                            item: item,
                            balance: data.balance?.points ?? 0
                        ) {
                            rewardToRedeem = item
                        }
                        .disabled(appModel.isWorking)
                    }
                }
            }

            ChorraSectionHeader(title: "Reward history")

            ChorraCard {
                if data.redemptions.isEmpty {
                    ChorraEmptyState(title: "No rewards redeemed yet", systemImage: "clock")
                } else {
                    ForEach(Array(data.redemptions.enumerated()), id: \.element.id) { index, item in
                        RewardRedemptionRowView(item: item, showsChild: false)

                        if index < data.redemptions.count - 1 {
                            ChorraDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct ChildRewardRowView: View {
    let item: RewardItem
    let balance: Int
    let onRedeem: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RewardThumbnailView(url: item.signedImageURL, size: 64)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.reward.name)
                    .font(.headline)
                    .foregroundStyle(Color.chorraTextPrimary)

                if let description = item.reward.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Color.chorraTextSecondary)
                }

                HStack {
                    Text("\(item.reward.pointCost) pts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(canRedeem ? Color.chorraPrimary : Color.chorraTextSecondary)

                    if !canRedeem {
                        Text("\(item.reward.pointCost - balance) more needed")
                            .font(.caption)
                            .foregroundStyle(Color.chorraTextSecondary)
                    }
                }

                Button("Redeem") {
                    onRedeem()
                }
                .buttonStyle(ChorraSecondaryButtonStyle())
                .disabled(!canRedeem)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canRedeem: Bool {
        balance >= item.reward.pointCost
    }
}

private struct ChildTaskRowView: View {
    let item: ChildTaskItem
    let showsDisclosure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.task.title)
                        .font(.headline)
                        .foregroundStyle(Color.chorraTextPrimary)

                    if let description = item.task.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(Color.chorraTextSecondary)
                    }
                }

                Spacer()

                ChorraPill(title: item.task.status.label, color: statusColor)

                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chorraTextMuted)
                        .padding(.top, 5)
                }
            }

            HStack(spacing: 10) {
                Label("\(item.task.pointValue) pts", systemImage: "star.fill")

                if item.pointsEarned > 0 {
                    Label("Earned \(item.pointsEarned)", systemImage: "checkmark.circle.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.chorraTextSecondary)

            if let submission = item.latestSubmission, submission.status == .rejected {
                Text(submission.rejectionReason ?? "Needs more work")
                    .font(.caption)
                    .foregroundStyle(Color.chorraError)
            }
        }
    }

    private var statusColor: Color {
        switch item.task.status {
        case .created:
            return .chorraTextSecondary
        case .assigned:
            return .chorraPrimary
        case .submitted:
            return .chorraWarning
        case .rejected:
            return .chorraError
        case .completed:
            return .chorraSuccess
        }
    }
}

private struct EarnedPointsRowView: View {
    let entry: PointsLedgerEntry

    var body: some View {
        HStack {
            Label("+\(entry.amount) pts", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(Color.chorraSuccess)

            Spacer()

            Text(entry.createdAt)
                .font(.caption)
                .foregroundStyle(Color.chorraTextSecondary)
        }
        .padding(.vertical, 2)
    }
}

private struct ChildTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let child: Child
    let item: ChildTaskItem

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedJPEGData: Data?

    var body: some View {
        Form {
            Section("Task") {
                Text(item.task.title)
                    .font(.headline)

                if let description = item.task.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(Color.chorraTextSecondary)
                }

                Text("\(item.task.pointValue) pts")
            }

            if let submission = item.latestSubmission, submission.status == .rejected {
                Section("Needs work") {
                    Text(submission.rejectionReason ?? "Your parent asked you to try again.")
                        .foregroundStyle(Color.chorraError)
                }
            }

            Section("Photo") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose completion photo", systemImage: "photo")
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Section {
                Button("Submit for review") {
                    guard let selectedJPEGData else {
                        return
                    }

                    Task {
                        await appModel.submitTaskCompletion(
                            assignment: item.assignment,
                            child: child,
                            jpegData: selectedJPEGData
                        )

                        if appModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .disabled(appModel.isWorking || selectedJPEGData == nil)
            }
        }
        .chorraFormBackground()
        .navigationTitle("Complete")
        .chorraNavigationBar()
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadPhoto(from: newItem)
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82) else {
            selectedImage = nil
            selectedJPEGData = nil
            return
        }

        selectedImage = image
        selectedJPEGData = jpegData
    }
}

#Preview("Child Home") {
    ChildHomeTab(data: .preview)
        .environmentObject(AppViewModel())
}

#Preview("Child Rewards") {
    ChildRewardsTab(data: .preview, rewardToRedeem: .constant(nil))
        .environmentObject(AppViewModel())
}

#Preview("Child Shell") {
    ChildDashboardView(data: .preview)
        .environmentObject(AppViewModel())
}

private extension ChildDashboardData {
    static var preview: ChildDashboardData {
        let householdId = UUID()
        let child = Child(
            id: UUID(),
            householdId: householdId,
            authUserId: UUID(),
            displayName: "Ava",
            loginName: "ava",
            createdBy: UUID(),
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let task = ChorraTask(
            id: UUID(),
            householdId: householdId,
            createdBy: UUID(),
            title: "Tidy bedroom",
            description: "Make the bed and put clothes away.",
            pointValue: 10,
            status: .assigned,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let assignment = TaskAssignment(
            id: UUID(),
            householdId: householdId,
            taskId: task.id,
            childId: child.id,
            assignedBy: UUID(),
            assignedAt: "2026-05-29"
        )
        let reward = Reward(
            id: UUID(),
            householdId: householdId,
            createdBy: UUID(),
            name: "Extra screen time",
            description: "20 minutes after dinner.",
            pointCost: 25,
            imageStoragePath: nil,
            isArchived: false,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let redemption = RewardRedemption(
            id: UUID(),
            householdId: householdId,
            childId: child.id,
            rewardId: reward.id,
            redeemedBy: child.id,
            rewardName: "Sticker pack",
            rewardDescription: nil,
            rewardPointCost: 12,
            rewardImageStoragePath: nil,
            redeemedAt: "2026-05-29"
        )

        return ChildDashboardData(
            child: child,
            tasks: [
                ChildTaskItem(
                    task: task,
                    assignment: assignment,
                    latestSubmission: nil,
                    pointsEarned: 0
                )
            ],
            balance: ChildPointsBalance(
                childId: child.id,
                householdId: householdId,
                points: 18,
                lastEarnedAt: "2026-05-29"
            ),
            ledger: [
                PointsLedgerEntry(
                    id: UUID(),
                    householdId: householdId,
                    childId: child.id,
                    taskId: task.id,
                    submissionId: UUID(),
                    amount: 8,
                    reason: .taskApproved,
                    createdBy: UUID(),
                    createdAt: "2026-05-29"
                )
            ],
            rewards: [RewardItem(reward: reward, signedImageURL: nil)],
            redemptions: [RewardRedemptionItem(redemption: redemption, child: nil, signedImageURL: nil)]
        )
    }
}
