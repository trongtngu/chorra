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
                    iconName: ChorraIconCatalog.pointIconName
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

            ChorraPointAmountLabel(amount: points, iconSize: 15)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.chorraPrimary)
        }
        .padding(.vertical, 2)
    }
}

private struct ParentTasksTab: View {
    let data: ParentDashboardData
    let onCreateTask: () -> Void

    @State private var reviewingTask: ParentTaskItem?

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
                    if item.isAwaitingReview {
                        Button {
                            reviewingTask = item
                        } label: {
                            ParentTaskCardView(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ParentTaskCardView(item: item)
                    }
                }
            }
        }
        .sheet(item: $reviewingTask) { item in
            ParentTaskReviewSheet(item: item)
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

        }
    }
}

private struct ParentTaskCardView: View {
    let item: ParentTaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ChildAvatarView(child: item.child, size: 28)

                Text(childName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 8)

                ChorraPill(title: item.task.status.label, color: statusColor)
            }

            HStack(spacing: 12) {
                ChorraIconView(
                    iconName: item.task.iconName,
                    size: 46,
                    background: .clear,
                    padding: 7
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.task.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.chorraTextPrimary)
                        .lineLimit(2)

                    ChorraPointAmountLabel(amount: item.task.pointValue, iconSize: 15)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.chorraTextPrimary.opacity(0.82))

                    if let rejectionText {
                        Text(rejectionText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.chorraError)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelCardColor.color(from: item.task.cardColorHex))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var childName: String {
        item.child?.displayName ?? "Unassigned"
    }

    private var rejectionText: String? {
        guard let submission = item.latestSubmission, submission.status == .rejected else {
            return nil
        }

        return submission.rejectionReason ?? "Needs more work"
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

private struct ParentTaskReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let item: ParentTaskItem

    @State private var rejectionReason = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ParentTaskCardView(item: item)

                    ChorraCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photo proof")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.chorraTextPrimary)

                            proofImage
                        }
                    }

                    ChorraCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Review")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.chorraTextPrimary)

                            TextField("Reason if rejecting", text: $rejectionReason, axis: .vertical)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 12) {
                                Button("Approve") {
                                    approve()
                                }
                                .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraSuccess))
                                .disabled(appModel.isWorking || submission == nil)

                                Button("Reject") {
                                    reject()
                                }
                                .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraError))
                                .disabled(appModel.isWorking || submission == nil)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.chorraSurface)
            .navigationTitle("Review task")
            .navigationBarTitleDisplayMode(.inline)
            .chorraNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(.chorraSurface)
                }
            }
        }
    }

    @ViewBuilder
    private var proofImage: some View {
        if let url = item.signedImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 220)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 300)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                case .failure:
                    Text("Photo unavailable")
                        .font(.subheadline)
                        .foregroundStyle(Color.chorraTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            ChorraEmptyState(title: "Photo unavailable", systemImage: "photo")
        }
    }

    private var submission: TaskSubmission? {
        guard let submission = item.latestSubmission, submission.status == .submitted else {
            return nil
        }

        return submission
    }

    private func approve() {
        guard let submission else {
            return
        }

        Task {
            await appModel.approveSubmission(submission)
            if appModel.errorMessage == nil {
                dismiss()
            }
        }
    }

    private func reject() {
        guard let submission else {
            return
        }

        Task {
            await appModel.rejectSubmission(
                submission,
                reason: rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if appModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}

private struct ChildAvatarView: View {
    let child: Child?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.chorraSurface.opacity(0.72))

            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Color.chorraPrimary)
        }
        .frame(width: size, height: size)
    }

    private var initial: String {
        guard let child else {
            return "?"
        }

        return String(child.displayName.prefix(1)).uppercased()
    }
}

private extension ParentTaskItem {
    var isAwaitingReview: Bool {
        latestSubmission?.status == .submitted
    }
}

private struct ParentRewardCardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let item: RewardItem
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)

                ChorraIconView(iconName: item.reward.iconName, size: 58)

                Text(item.reward.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)

                ChorraPointAmountLabel(amount: item.reward.pointCost, iconSize: 12)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chorraPrimary)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(PastelCardColor.color(from: item.reward.cardColorHex))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.chorraBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(appModel.isWorking)
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
    @State private var cardColorHex = PastelCardColor.defaultHex
    @State private var iconName = ChorraIconCatalog.defaultIconName

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    CardColorPalettePicker(selectedHex: $cardColorHex)
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                    Stepper(value: $pointValue, in: 1...500) {
                        ChorraPointAmountLabel(amount: pointValue, iconSize: 16)
                    }
                }

                Section("Icon") {
                    IconPickerPanel(selectedIconName: $iconName)
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
                                cardColorHex: cardColorHex,
                                iconName: iconName
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
    @State private var iconName: String
    @State private var pointCost: Int
    @State private var cardColorHex: String
    @State private var showingArchiveConfirmation = false

    init(item: RewardItem?) {
        reward = item?.reward
        _name = State(initialValue: item?.reward.name ?? "")
        _iconName = State(
            initialValue: ChorraIconCatalog.normalizedSelectableIconName(
                item?.reward.iconName ?? ChorraIconCatalog.defaultIconName
            )
        )
        _pointCost = State(initialValue: item?.reward.pointCost ?? 25)
        _cardColorHex = State(
            initialValue: PastelCardColor.normalizedPaletteHex(
                item?.reward.cardColorHex ?? PastelCardColor.defaultHex
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reward") {
                    TextField("Name", text: $name)
                    Stepper(value: $pointCost, in: 1...100000) {
                        ChorraPointAmountLabel(amount: pointCost, iconSize: 16)
                    }
                }

                Section("Icon") {
                    IconPickerPanel(selectedIconName: $iconName)
                }

                Section("Colour") {
                    CardColorPalettePicker(selectedHex: $cardColorHex)
                }

                if reward != nil {
                    Section {
                        Button(role: .destructive) {
                            showingArchiveConfirmation = true
                        } label: {
                            Label("Archive reward", systemImage: "archivebox")
                        }
                        .disabled(appModel.isWorking)
                    }
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
        .alert("Archive reward?", isPresented: $showingArchiveConfirmation) {
            Button("Archive", role: .destructive) {
                if let reward {
                    Task {
                        await appModel.archiveReward(reward)
                        if appModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the reward from the active reward list.")
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        if let reward {
            await appModel.updateReward(
                reward: reward,
                name: name,
                iconName: iconName,
                pointCost: pointCost,
                cardColorHex: cardColorHex
            )
        } else {
            await appModel.createReward(
                name: name,
                iconName: iconName,
                pointCost: pointCost,
                cardColorHex: cardColorHex
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
            iconName: ChorraIconCatalog.defaultIconName,
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
            iconName: "Icon_Film",
            pointCost: 30,
            cardColorHex: PastelCardColor.allowedHexes[1],
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
            rewardIconName: reward.iconName,
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
