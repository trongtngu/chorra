//
//  ParentDashboardView.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import SwiftUI

struct ParentDashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ParentDashboardData

    @State private var selectedTab: ParentDashboardTab = .home
    @State private var showingAddChild = false
    @State private var showingCreateTask = false
    @State private var showingCreateReward = false
    @State private var editingReward: RewardItem?

    var body: some View {
        TabView(selection: $selectedTab) {
            ParentHomeTab(data: data) {
                showingAddChild = true
            }
            .tag(ParentDashboardTab.home)
            .tabItem {
                Label(ParentDashboardTab.home.title, systemImage: ParentDashboardTab.home.systemImage)
            }

            ParentTasksTab(data: data) {
                showingCreateTask = true
            }
            .environmentObject(appModel)
            .tag(ParentDashboardTab.tasks)
            .tabItem {
                Label(ParentDashboardTab.tasks.title, systemImage: ParentDashboardTab.tasks.systemImage)
            }

            ParentRewardsTab(data: data) {
                showingCreateReward = true
            } onEditReward: { item in
                editingReward = item
            }
            .environmentObject(appModel)
            .tag(ParentDashboardTab.rewards)
            .tabItem {
                Label(ParentDashboardTab.rewards.title, systemImage: ParentDashboardTab.rewards.systemImage)
            }
        }
        .chorraTabBar()
        .background(Color.chorraBackground)
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

private enum ParentDashboardTab: Hashable, CaseIterable {
    case home
    case tasks
    case rewards

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .tasks:
            return "Tasks"
        case .rewards:
            return "Rewards"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .tasks:
            return "checklist"
        case .rewards:
            return "gift.fill"
        }
    }
}

private struct ParentTabContainer<Content: View>: View {
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

private struct ParentHomeTab: View {
    let data: ParentDashboardData
    let onAddChild: () -> Void

    var body: some View {
        ParentTabContainer(title: "Home") {
            householdCard

            ChorraSectionHeader(
                title: "Children",
                actionTitle: "Add",
                systemImage: "person.badge.plus",
                action: onAddChild
            )

            if data.children.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No children yet", systemImage: "person.2")
                }
            } else {
                ChorraCard {
                    ForEach(Array(data.children.enumerated()), id: \.element.id) { index, child in
                        ChildSummaryRow(child: child, points: points(for: child))

                        if index < data.children.count - 1 {
                            ChorraDivider()
                        }
                    }
                }
            }
        }
    }

    private var householdCard: some View {
        ChorraCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.household.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)

                Text(data.profile.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.chorraTextSecondary)
            }

            HStack(spacing: 10) {
                ChorraStatPill(
                    title: "children",
                    value: "\(data.children.count)",
                    systemImage: "person.2.fill"
                )

                ChorraStatPill(
                    title: "points",
                    value: "\(totalPoints)",
                    systemImage: "star.fill"
                )
            }

            ChorraDivider()

            HStack {
                Label("Child code", systemImage: "key.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.chorraTextSecondary)

                Spacer()

                Text(data.household.loginCode)
                    .font(.system(.headline, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.chorraPrimarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var totalPoints: Int {
        data.balances.reduce(0) { $0 + $1.points }
    }

    private func points(for child: Child) -> Int {
        data.balances.first(where: { $0.childId == child.id })?.points ?? 0
    }
}

private struct ChildSummaryRow: View {
    let child: Child
    let points: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.chorraPrimarySoft)

                Text(String(child.displayName.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chorraPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(child.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.chorraTextPrimary)

                Text("@\(child.loginName)")
                    .font(.caption)
                    .foregroundStyle(Color.chorraTextSecondary)
            }

            Spacer()

            Text("\(points) pts")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.chorraPrimary)
        }
        .padding(.vertical, 2)
    }
}

private struct ParentTasksTab: View {
    let data: ParentDashboardData
    let onCreateTask: () -> Void

    var body: some View {
        ParentTabContainer(title: "Tasks") {
            ChorraSectionHeader(
                title: "Tasks",
                actionTitle: "Create",
                systemImage: "plus",
                isDisabled: data.children.isEmpty,
                action: onCreateTask
            )

            if data.children.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "Add a child before creating tasks", systemImage: "person.badge.plus")
                }
            } else if data.taskItems.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No tasks yet", systemImage: "checklist")
                }
            } else {
                ForEach(data.taskItems) { item in
                    ChorraCard {
                        ParentTaskRowView(item: item)
                    }
                }
            }
        }
    }
}

private struct ParentRewardsTab: View {
    let data: ParentDashboardData
    let onCreateReward: () -> Void
    let onEditReward: (RewardItem) -> Void
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ParentTabContainer(title: "Rewards") {
            ChorraSectionHeader(
                title: "Rewards",
                actionTitle: "Create",
                systemImage: "plus",
                action: onCreateReward
            )

            if data.rewards.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No rewards yet", systemImage: "gift")
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(data.rewards) { item in
                        ParentRewardCardView(item: item) {
                            onEditReward(item)
                        }
                    }
                }
            }

            ChorraSectionHeader(title: "Reward history")

            ChorraCard {
                if data.redemptions.isEmpty {
                    ChorraEmptyState(title: "No rewards unlocked yet", systemImage: "clock")
                } else {
                    ForEach(Array(data.redemptions.enumerated()), id: \.element.id) { index, item in
                        RewardRedemptionRowView(item: item, showsChild: true)

                        if index < data.redemptions.count - 1 {
                            ChorraDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct ParentTaskRowView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let item: ParentTaskItem

    @State private var rejectionReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.task.title)
                        .font(.headline)
                        .foregroundStyle(Color.chorraTextPrimary)

                    if let description = item.task.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(Color.chorraTextSecondary)
                    }

                    Label(taskMeta, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.chorraTextSecondary)
                }

                Spacer()

                ChorraPill(title: item.task.status.label, color: statusColor)
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
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    case .failure:
                        Text("Photo unavailable")
                            .font(.subheadline)
                            .foregroundStyle(Color.chorraTextSecondary)
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
                    .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraSuccess))
                    .disabled(appModel.isWorking)

                    Button("Reject") {
                        Task {
                            await appModel.rejectSubmission(
                                submission,
                                reason: rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    }
                    .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraError))
                    .disabled(appModel.isWorking)
                }
            } else if let submission = item.latestSubmission, submission.status == .rejected {
                Text(submission.rejectionReason ?? "Rejected for resubmission")
                    .font(.caption)
                    .foregroundStyle(Color.chorraTextSecondary)
            }
        }
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

private struct ParentRewardCardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let item: RewardItem
    let onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)

                RewardEmojiView(emoji: item.reward.emoji, size: 50)

                Text(item.reward.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)

                Text("\(item.reward.pointCost) pts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chorraPrimary)

                Spacer(minLength: 0)
            }
            .padding(12)

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    Task { await appModel.archiveReward(item.reward) }
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.chorraTextSecondary)
            }
            .disabled(appModel.isWorking)
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.chorraSoftSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }
}

struct RewardRedemptionRowView: View {
    let item: RewardRedemptionItem
    let showsChild: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RewardEmojiView(emoji: item.redemption.rewardEmoji, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.redemption.rewardName)
                    .font(.headline)
                    .foregroundStyle(Color.chorraTextPrimary)

                if showsChild, let child = item.child {
                    Text(child.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Color.chorraTextSecondary)
                }

                HStack {
                    Text("-\(item.redemption.rewardPointCost) pts")
                    Text(item.redemption.redeemedAt)
                }
                .font(.caption)
                .foregroundStyle(Color.chorraTextSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RewardEmojiView: View {
    let emoji: String
    let size: CGFloat

    var body: some View {
        Text(displayEmoji)
            .font(.system(size: size))
            .frame(width: size * 1.7, height: size * 1.7)
            .background(Color.chorraSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var displayEmoji: String {
        emoji.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "🎁"
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
            .chorraFormBackground()
            .navigationTitle("Add child")
            .chorraNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.chorraSurface)
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
                    .tint(.chorraSurface)
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
    @State private var cardColorHex = PastelCardColor.randomHex()

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
            .chorraFormBackground()
            .navigationTitle("Create task")
            .chorraNavigationBar()
            .onAppear {
                selectedChildId = selectedChildId ?? children.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.chorraSurface)
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
                                pointValue: pointValue,
                                cardColorHex: cardColorHex
                            )
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .tint(.chorraSurface)
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

    @State private var name: String
    @State private var emoji: String
    @State private var pointCost: Int

    init(item: RewardItem?) {
        reward = item?.reward
        _name = State(initialValue: item?.reward.name ?? "")
        _emoji = State(initialValue: item?.reward.emoji ?? "🎁")
        _pointCost = State(initialValue: item?.reward.pointCost ?? 25)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reward") {
                    TextField("Emoji", text: $emoji)
                        .font(.title2)
                    TextField("Name", text: $name)
                    Stepper("\(pointCost) pts", value: $pointCost, in: 1...100000)
                }
            }
            .chorraFormBackground()
            .navigationTitle(reward == nil ? "Create reward" : "Edit reward")
            .chorraNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.chorraSurface)
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
                    .tint(.chorraSurface)
                    .disabled(appModel.isWorking || !canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var normalizedEmoji: String {
        emoji.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "🎁"
    }

    private func save() async {
        if let reward {
            await appModel.updateReward(
                reward: reward,
                name: name,
                emoji: normalizedEmoji,
                pointCost: pointCost
            )
        } else {
            await appModel.createReward(
                name: name,
                emoji: normalizedEmoji,
                pointCost: pointCost
            )
        }
    }
}

#Preview("Parent Home") {
    ParentDashboardView(data: .preview)
        .environmentObject(AppViewModel())
}

#Preview("Parent Tasks") {
    ParentTasksTab(data: .preview) {}
        .environmentObject(AppViewModel())
}

#Preview("Parent Rewards") {
    ParentRewardsTab(data: .preview) {} onEditReward: { _ in }
        .environmentObject(AppViewModel())
}

private extension ParentDashboardData {
    static var preview: ParentDashboardData {
        let householdId = UUID()
        let parentId = UUID()
        let child = Child(
            id: UUID(),
            householdId: householdId,
            authUserId: UUID(),
            displayName: "Ava",
            loginName: "ava",
            createdBy: parentId,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let task = ChorraTask(
            id: UUID(),
            householdId: householdId,
            createdBy: parentId,
            title: "Pack school bag",
            description: "Put lunchbox, reader, and hat in your bag.",
            pointValue: 8,
            cardColorHex: PastelCardColor.fallbackHex,
            status: .submitted,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let assignment = TaskAssignment(
            id: UUID(),
            householdId: householdId,
            taskId: task.id,
            childId: child.id,
            assignedBy: parentId,
            assignedAt: "2026-05-29"
        )
        let submission = TaskSubmission(
            id: UUID(),
            householdId: householdId,
            assignmentId: assignment.id,
            childId: child.id,
            submittedBy: child.id,
            status: .submitted,
            rejectionReason: nil,
            reviewedBy: nil,
            reviewedAt: nil,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let reward = Reward(
            id: UUID(),
            householdId: householdId,
            createdBy: parentId,
            name: "Movie night",
            emoji: "🎬",
            pointCost: 30,
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
            rewardName: reward.name,
            rewardEmoji: reward.emoji,
            rewardPointCost: reward.pointCost,
            redeemedAt: "2026-05-29"
        )

        return ParentDashboardData(
            profile: Profile(
                id: parentId,
                householdId: householdId,
                role: .parent,
                displayName: "Tommy",
                createdAt: "2026-05-29",
                updatedAt: "2026-05-29"
            ),
            household: Household(
                id: householdId,
                name: "Nguyen Household",
                loginCode: "ABC12345",
                createdBy: parentId,
                createdAt: "2026-05-29",
                updatedAt: "2026-05-29"
            ),
            children: [child],
            balances: [
                ChildPointsBalance(
                    childId: child.id,
                    householdId: householdId,
                    points: 18,
                    lastEarnedAt: "2026-05-29"
                )
            ],
            taskItems: [
                ParentTaskItem(
                    task: task,
                    assignment: assignment,
                    child: child,
                    latestSubmission: submission,
                    image: nil,
                    signedImageURL: nil
                )
            ],
            rewards: [RewardItem(reward: reward)],
            redemptions: [RewardRedemptionItem(redemption: redemption, child: child)]
        )
    }
}
