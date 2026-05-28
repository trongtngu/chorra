//
//  ParentDashboardView.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import PhotosUI
import SwiftUI
import UIKit

struct ParentDashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ParentDashboardData

    @State private var showingAddChild = false
    @State private var showingCreateTask = false
    @State private var showingCreateReward = false
    @State private var editingReward: RewardItem?

    var body: some View {
        NavigationStack {
            List {
                householdSection
                childrenSection
                tasksSection
                rewardsSection
                redemptionsSection
            }
            .navigationTitle("Parent")
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
            .sheet(isPresented: $showingAddChild) {
                AddChildView()
                    .environmentObject(appModel)
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskView(children: data.children)
                    .environmentObject(appModel)
            }
            .sheet(isPresented: $showingCreateReward) {
                RewardFormView(item: nil)
                    .environmentObject(appModel)
            }
            .sheet(item: $editingReward) { item in
                RewardFormView(item: item)
                    .environmentObject(appModel)
            }
        }
    }

    private var householdSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(data.household.name)
                    .font(.headline)

                HStack {
                    Text("Child code")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(data.household.loginCode)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var childrenSection: some View {
        Section {
            if data.children.isEmpty {
                Text("No children yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.children) { child in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(child.displayName)
                            Text("@\(child.loginName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(points(for: child)) pts")
                            .font(.headline)
                    }
                }
            }

            Button("Add child") {
                showingAddChild = true
            }
        } header: {
            Text("Children")
        }
    }

    private var tasksSection: some View {
        Section {
            if data.taskItems.isEmpty {
                Text("No tasks yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.taskItems) { item in
                    ParentTaskRowView(item: item)
                        .environmentObject(appModel)
                }
            }

            Button("Create task") {
                showingCreateTask = true
            }
            .disabled(data.children.isEmpty)
        } header: {
            Text("Tasks")
        }
    }

    private var rewardsSection: some View {
        Section {
            if data.rewards.isEmpty {
                Text("No rewards yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.rewards) { item in
                    ParentRewardRowView(item: item) {
                        editingReward = item
                    }
                    .environmentObject(appModel)
                }
            }

            Button("Create reward") {
                showingCreateReward = true
            }
        } header: {
            Text("Rewards")
        }
    }

    private var redemptionsSection: some View {
        Section {
            if data.redemptions.isEmpty {
                Text("No rewards redeemed yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data.redemptions) { item in
                    RewardRedemptionRowView(item: item, showsChild: true)
                }
            }
        } header: {
            Text("Reward history")
        }
    }

    private func points(for child: Child) -> Int {
        data.balances.first(where: { $0.childId == child.id })?.points ?? 0
    }
}

private struct ParentTaskRowView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let item: ParentTaskItem

    @State private var rejectionReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.task.title)
                        .font(.headline)

                    if let description = item.task.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(taskMeta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.task.status.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            if let url = item.signedImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        Text("Photo unavailable")
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            if let submission = item.latestSubmission, submission.status == .submitted {
                TextField("Reason if rejecting", text: $rejectionReason)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Approve") {
                        Task { await appModel.approveSubmission(submission) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.chorraSuccess)
                    .disabled(appModel.isWorking)

                    Button("Reject") {
                        Task {
                            await appModel.rejectSubmission(
                                submission,
                                reason: rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.chorraError)
                    .disabled(appModel.isWorking)
                }
            } else if let submission = item.latestSubmission, submission.status == .rejected {
                Text(submission.rejectionReason ?? "Rejected for resubmission")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var taskMeta: String {
        let childName = item.child?.displayName ?? "Unassigned"
        return "\(childName) · \(item.task.pointValue) pts"
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

private struct ParentRewardRowView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let item: RewardItem
    let onEdit: () -> Void

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

                Text("\(item.reward.pointCost) pts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chorraPrimary)

                HStack {
                    Button("Edit") {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    .disabled(appModel.isWorking)

                    Button("Archive") {
                        Task { await appModel.archiveReward(item.reward) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.chorraError)
                    .disabled(appModel.isWorking)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct RewardRedemptionRowView: View {
    let item: RewardRedemptionItem
    let showsChild: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RewardThumbnailView(url: item.signedImageURL, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.redemption.rewardName)
                    .font(.headline)

                if showsChild, let child = item.child {
                    Text(child.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("-\(item.redemption.rewardPointCost) pts")
                    Text(item.redemption.redeemedAt)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RewardThumbnailView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.chorraSoftSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
    }

    private var placeholder: some View {
        Image(systemName: "gift.fill")
            .font(.title3)
            .foregroundStyle(Color.chorraPrimary)
    }
}

private struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    @State private var displayName = ""
    @State private var loginName = ""
    @State private var pin = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Child") {
                    TextField("Display name", text: $displayName)
                    TextField("Login name", text: $loginName)
                        .textInputAutocapitalization(.never)
                    SecureField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add child")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await appModel.addChild(
                                displayName: displayName,
                                loginName: loginName,
                                pin: pin
                            )
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(appModel.isWorking || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !loginName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && pin.count >= 4
    }
}

private struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let children: [Child]

    @State private var selectedChildId: UUID?
    @State private var title = ""
    @State private var description = ""
    @State private var pointValue = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                    Stepper("\(pointValue) pts", value: $pointValue, in: 1...500)
                }

                Section("Assign to") {
                    Picker("Child", selection: Binding(
                        get: { selectedChildId ?? children.first?.id },
                        set: { selectedChildId = $0 }
                    )) {
                        ForEach(children) { child in
                            Text(child.displayName).tag(Optional(child.id))
                        }
                    }
                }
            }
            .navigationTitle("Create task")
            .onAppear {
                selectedChildId = selectedChildId ?? children.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let childId = selectedChildId ?? children.first?.id else {
                            return
                        }

                        Task {
                            await appModel.createAssignedTask(
                                childId: childId,
                                title: title,
                                description: description,
                                pointValue: pointValue
                            )
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(appModel.isWorking || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (selectedChildId ?? children.first?.id) != nil
    }
}

private struct RewardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let reward: Reward?
    let existingImageURL: URL?

    @State private var name: String
    @State private var description: String
    @State private var pointCost: Int
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedJPEGData: Data?
    @State private var imageRemoved = false

    init(item: RewardItem?) {
        reward = item?.reward
        existingImageURL = item?.signedImageURL
        _name = State(initialValue: item?.reward.name ?? "")
        _description = State(initialValue: item?.reward.description ?? "")
        _pointCost = State(initialValue: item?.reward.pointCost ?? 25)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reward") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                    Stepper("\(pointCost) pts", value: $pointCost, in: 1...100000)
                }

                Section("Image") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose image", systemImage: "photo")
                    }

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if !imageRemoved, let existingImageURL {
                        AsyncImage(url: existingImageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 180)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                Text("Image unavailable")
                                    .foregroundStyle(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    if selectedImage != nil || (!imageRemoved && existingImageURL != nil) {
                        Button("Remove image", role: .destructive) {
                            selectedPhotoItem = nil
                            selectedImage = nil
                            selectedJPEGData = nil
                            imageRemoved = true
                        }
                    }
                }
            }
            .navigationTitle(reward == nil ? "Create reward" : "Edit reward")
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadPhoto(from: newItem)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(appModel.isWorking || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        if let reward {
            let imageUpdate: RewardImageUpdate

            if let selectedJPEGData {
                imageUpdate = .replace(selectedJPEGData)
            } else if imageRemoved {
                imageUpdate = .remove
            } else {
                imageUpdate = .keep
            }

            await appModel.updateReward(
                reward: reward,
                name: name,
                description: description,
                pointCost: pointCost,
                imageUpdate: imageUpdate
            )
        } else {
            await appModel.createReward(
                name: name,
                description: description,
                pointCost: pointCost,
                jpegData: selectedJPEGData
            )
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
        imageRemoved = false
    }
}

#Preview {
    ParentDashboardView(data: ParentDashboardData(
        profile: Profile(
            id: UUID(),
            householdId: UUID(),
            role: .parent,
            displayName: "Parent",
            createdAt: "",
            updatedAt: ""
        ),
        household: Household(
            id: UUID(),
            name: "Nguyen Household",
            loginCode: "ABC12345",
            createdBy: UUID(),
            createdAt: "",
            updatedAt: ""
        ),
        children: [],
        balances: [],
        taskItems: [],
        rewards: [],
        redemptions: []
    ))
    .environmentObject(AppViewModel())
}
