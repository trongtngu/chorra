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

    @State private var rewardToRedeem: RewardItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.child.displayName)
                                .font(.headline)
                            Text("@\(data.child.loginName)")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(data.balance?.points ?? 0) pts")
                            .font(.title3.weight(.bold))
                    }
                    .padding(.vertical, 4)
                }

                rewardsSection

                Section("Tasks") {
                    if data.tasks.isEmpty {
                        Text("No tasks assigned")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(data.tasks) { item in
                            if item.task.status == .assigned || item.task.status == .rejected {
                                NavigationLink {
                                    ChildTaskDetailView(child: data.child, item: item)
                                        .environmentObject(appModel)
                                } label: {
                                    ChildTaskRowView(item: item)
                                }
                            } else {
                                ChildTaskRowView(item: item)
                            }
                        }
                    }
                }

                redemptionsSection

                Section("Earned") {
                    if data.ledger.isEmpty {
                        Text("No points earned yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(data.ledger) { entry in
                            HStack {
                                Text("+\(entry.amount) pts")
                                    .font(.headline)
                                Spacer()
                                Text(entry.createdAt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Refresh") {
                        Task { await appModel.refresh() }
                    }
                    .disabled(appModel.isWorking)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        Task { await appModel.signOut() }
                    }
                    .disabled(appModel.isWorking)
                }
            }
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
    }

    private var rewardsSection: some View {
        Section("Rewards") {
            if data.rewards.isEmpty {
                Text("No rewards available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.rewards) { item in
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
    }

    private var redemptionsSection: some View {
        Section("Reward history") {
            if data.redemptions.isEmpty {
                Text("No rewards redeemed yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.redemptions) { item in
                    RewardRedemptionRowView(item: item, showsChild: false)
                }
            }
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

private struct ChildRewardRowView: View {
    let item: RewardItem
    let balance: Int
    let onRedeem: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RewardThumbnailView(url: item.signedImageURL, size: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.reward.name)
                    .font(.headline)

                if let description = item.reward.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("\(item.reward.pointCost) pts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(canRedeem ? Color.chorraPrimary : .secondary)

                    if !canRedeem {
                        Text("\(item.reward.pointCost - balance) more needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Redeem") {
                    onRedeem()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRedeem)
            }
        }
        .padding(.vertical, 6)
    }

    private var canRedeem: Bool {
        balance >= item.reward.pointCost
    }
}

private struct ChildTaskRowView: View {
    let item: ChildTaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.task.title)
                    .font(.headline)
                Spacer()
                Text(item.task.status.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            if let description = item.task.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("\(item.task.pointValue) pts")
                if item.pointsEarned > 0 {
                    Text("Earned \(item.pointsEarned)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let submission = item.latestSubmission, submission.status == .rejected {
                Text(submission.rejectionReason ?? "Needs more work")
                    .font(.caption)
                    .foregroundStyle(Color.chorraError)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch item.task.status {
        case .created:
            return .secondary
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
                        .foregroundStyle(.secondary)
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .navigationTitle("Complete")
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

#Preview {
    ChildDashboardView(data: ChildDashboardData(
        child: Child(
            id: UUID(),
            householdId: UUID(),
            authUserId: UUID(),
            displayName: "Ava",
            loginName: "ava",
            createdBy: UUID(),
            createdAt: "",
            updatedAt: ""
        ),
        tasks: [],
        balance: nil,
        ledger: [],
        rewards: [],
        redemptions: []
    ))
    .environmentObject(AppViewModel())
}
