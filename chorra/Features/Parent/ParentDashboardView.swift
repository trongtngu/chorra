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

            ParentSettingsTab(data: data)
                .environmentObject(appModel)
                .tag(ParentDashboardTab.settings)
                .tabItem {
                    Label(ParentDashboardTab.settings.title, systemImage: ParentDashboardTab.settings.systemImage)
                }
        }
        .chorraTabBar()
        .background(Color.chorraBackground)
        .sheet(isPresented: $showingAddChild) {
            AddChildView()
                .environmentObject(appModel)
        }
        .sheet(isPresented: $showingCreateTask) {
            TaskFormView(item: nil)
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
    case settings

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .tasks:
            return "Tasks"
        case .rewards:
            return "Rewards"
        case .settings:
            return "Settings"
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
        case .settings:
            return "gearshape.fill"
        }
    }
}

private struct ParentTabContainer<HeaderAccessory: View, Content: View>: View {
    @EnvironmentObject private var appModel: AppViewModel

    let title: String
    let headerAccessory: HeaderAccessory
    let content: Content

    init(
        title: String,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ChorraScreen(title: title) {
                HStack(spacing: 8) {
                    headerAccessory

                    Button {
                        Task { await appModel.refresh() }
                    } label: {
                        ChorraToolbarIcon(systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                    .disabled(appModel.isWorking)
                }
            } content: {
                content
            }
        }
    }
}

private extension ParentTabContainer where HeaderAccessory == EmptyView {
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, headerAccessory: { EmptyView() }, content: content)
    }
}

private struct ParentHomeTab: View {
    @EnvironmentObject private var appModel: AppViewModel

    let data: ParentDashboardData
    let onAddChild: () -> Void

    @State private var expandedChildIds: Set<UUID> = []
    @State private var selectedAssignedTask: ParentChildTaskItem?
    @State private var editingAssignedTask: ParentChildTaskItem?
    @State private var deletingAssignedTask: ParentChildTaskItem?

    var body: some View {
        ParentTabContainer(title: "Home") {
            VStack(alignment: .leading, spacing: 0) {
                tasksLeftHero

                ChorraSectionHeader(
                    title: "Children",
                    actionTitle: "Add",
                    systemImage: "person.badge.plus",
                    action: onAddChild
                )
                .padding(.top, -4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if data.children.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No children yet", systemImage: "person.2")
                }
            } else {
                ForEach(data.children) { child in
                    CollapsibleChildCard(
                        child: child,
                        points: points(for: child),
                        tasks: tasks(for: child),
                        isExpanded: expandedChildIds.contains(child.id)
                    ) {
                        toggleChild(child)
                    } onTaskActions: { item in
                        guard !appModel.isWorking else {
                            return
                        }

                        selectedAssignedTask = item
                    }
                }
            }
        }
        .confirmationDialog(
            selectedAssignedTask?.assignment.title ?? "Task actions",
            isPresented: Binding(
                get: { selectedAssignedTask != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedAssignedTask = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: selectedAssignedTask
        ) { item in
            Button("Edit") {
                editingAssignedTask = item
                selectedAssignedTask = nil
            }
            .disabled(appModel.isWorking)

            Button("Delete", role: .destructive) {
                deletingAssignedTask = item
                selectedAssignedTask = nil
            }
            .disabled(appModel.isWorking)

            Button("Cancel", role: .cancel) {
                selectedAssignedTask = nil
            }
        } message: { item in
            Text("Manage \(item.assignment.title)")
        }
        .sheet(item: $editingAssignedTask) { item in
            AssignedTaskFormView(item: item)
                .environmentObject(appModel)
        }
        .alert(
            "Delete assigned task?",
            isPresented: Binding(
                get: { deletingAssignedTask != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingAssignedTask = nil
                    }
                }
            ),
            presenting: deletingAssignedTask
        ) { item in
            Button("Delete", role: .destructive) {
                deletingAssignedTask = nil
                Task {
                    await appModel.archiveTaskAssignment(item.assignment)
                }
            }

            Button("Cancel", role: .cancel) {
                deletingAssignedTask = nil
            }
        } message: { _ in
            Text("This hides the assigned copy from parent and child task lists. Submission history and photos are preserved.")
        }
    }

    private var tasksLeftHero: some View {
        VStack(spacing: 2) {
            Text("\(tasksLeftCount)")
                .font(.system(size: 58, weight: .black, design: .rounded))
                .foregroundStyle(Color.chorraTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("tasks left")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.chorraTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 22)
        .accessibilityLabel("\(tasksLeftCount) tasks left")
    }

    private var tasksLeftCount: Int {
        data.childTaskItems.count
    }

    private func points(for child: Child) -> Int {
        data.balances.first(where: { $0.childId == child.id })?.points ?? 0
    }

    private func tasks(for child: Child) -> [ParentChildTaskItem] {
        data.childTaskItems.filter { $0.assignment.childId == child.id }
    }

    private func toggleChild(_ child: Child) {
        if expandedChildIds.contains(child.id) {
            expandedChildIds.remove(child.id)
        } else {
            expandedChildIds.insert(child.id)
        }
    }
}

private struct ParentSettingsTab: View {
    @EnvironmentObject private var appModel: AppViewModel

    let data: ParentDashboardData

    var body: some View {
        ParentTabContainer(title: "Settings") {
            ChorraSectionHeader(title: "Home code")

            ChorraCard {
                HouseholdCodeCardValue(code: data.household.loginCode)
            }

            ChorraSectionHeader(title: "Parents")

            if data.parents.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No parents yet", systemImage: "person.2")
                }
            } else {
                ChorraCard {
                    ForEach(Array(data.parents.enumerated()), id: \.element.id) { index, parent in
                        ParentSummaryRow(
                            profile: parent,
                            isCurrentUser: parent.id == data.profile.id
                        )

                        if index < data.parents.count - 1 {
                            ChorraDivider()
                        }
                    }
                }
            }

            ChorraSectionHeader(title: "Account")

            Button {
                Task { await appModel.signOut() }
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraError))
            .disabled(appModel.isWorking)
            .accessibilityLabel("Log out")
        }
    }
}

private struct HouseholdCodeCardValue: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(size: 32, weight: .black, design: .monospaced))
            .foregroundStyle(Color.chorraPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Home code \(code)")
    }
}

private struct ParentSummaryRow: View {
    let profile: Profile
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.chorraPrimarySoft)

                Text(String(profile.displayName.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chorraPrimary)
            }
            .frame(width: 44, height: 44)

            Text(profile.displayName)
                .font(.headline)
                .foregroundStyle(Color.chorraTextPrimary)
                .lineLimit(1)

            Spacer()

            if isCurrentUser {
                ChorraPill(title: "You", color: .chorraPrimary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct CollapsibleChildCard: View {
    let child: Child
    let points: Int
    let tasks: [ParentChildTaskItem]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onTaskActions: (ParentChildTaskItem) -> Void

    var body: some View {
        ChorraCard {
            Button(action: onToggle) {
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
                            .lineLimit(1)

                        Text(taskCountText)
                            .font(.caption)
                            .foregroundStyle(Color.chorraTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    ChorraPointAmountLabel(amount: points, iconSize: 15)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.chorraPrimary)

                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.chorraTextSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(child.displayName)" : "Expand \(child.displayName)")

            if isExpanded {
                ChorraDivider()

                if tasks.isEmpty {
                    ChorraEmptyState(title: "No active tasks", systemImage: "checklist")
                        .padding(.vertical, -2)
                } else {
                    VStack(spacing: 10) {
                        ForEach(tasks) { item in
                            ParentHomeChildTaskCardView(item: item) {
                                onTaskActions(item)
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private var taskCountText: String {
        let count = tasks.count
        return count == 1 ? "1 task" : "\(count) tasks"
    }
}

private struct ParentHomeChildTaskCardView: View {
    let item: ParentChildTaskItem
    let onActions: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ChorraIconView(
                iconName: item.assignment.iconName,
                size: 46,
                background: .clear,
                padding: 7
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.assignment.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .lineLimit(2)

                ChorraPointAmountLabel(amount: item.assignment.pointValue, iconSize: 15)
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

            ChorraPill(
                title: item.assignment.status.label,
                color: statusColor,
                isFilled: item.assignment.status == .submitted
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelCardColor.color(from: item.assignment.cardColorHex))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onLongPressGesture(perform: onActions)
        .accessibilityAction(named: Text("Show task actions"), onActions)
    }

    private var rejectionText: String? {
        guard let submission = item.latestSubmission, submission.status == .rejected else {
            return nil
        }

        return submission.rejectionReason ?? "Needs more work"
    }

    private var statusColor: Color {
        switch item.assignment.status {
        case .created:
            return .chorraTextSecondary
        case .assigned:
            return .chorraPrimary
        case .submitted:
            return .chorraPrimary
        case .rejected:
            return .chorraError
        case .completed:
            return .chorraSuccess
        }
    }
}

private struct ParentTasksTab: View {
    @EnvironmentObject private var appModel: AppViewModel

    let data: ParentDashboardData
    let onCreateTask: () -> Void

    @State private var reviewingTask: ParentTaskReviewItem?
    @State private var assigningTask: ParentTaskItem?
    @State private var editingTask: ParentTaskItem?

    var body: some View {
        ParentTabContainer(title: "Tasks") {
            if !data.reviewItems.isEmpty {
                ChorraSectionHeader(title: "Needs review")

                ForEach(data.reviewItems) { item in
                    Button {
                        reviewingTask = item
                    } label: {
                        ParentTaskReviewCardView(item: item)
                    }
                    .buttonStyle(.plain)
                    .disabled(appModel.isWorking)
                }
            }

            ChorraSectionHeader(
                title: "Tasks",
                actionTitle: "Create",
                systemImage: "plus",
                action: onCreateTask
            )

            if data.taskItems.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No tasks yet", systemImage: "checklist")
                }
            } else {
                ForEach(data.taskItems) { item in
                    ParentTaskCardView(
                        item: item,
                        canAssign: !data.children.isEmpty && !appModel.isWorking
                    ) {
                        editingTask = item
                    } onAssign: {
                        assigningTask = item
                    }
                }

                if data.children.isEmpty {
                    ChorraCard {
                        ChorraEmptyState(title: "Add a child to assign tasks", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        .sheet(item: $reviewingTask) { item in
            ParentTaskReviewSheet(item: item)
        }
        .sheet(item: $editingTask) { item in
            TaskFormView(item: item)
                .environmentObject(appModel)
        }
        .overlay {
            if let assigningTask {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    AssignTaskDialog(
                        children: data.children,
                        isWorking: appModel.isWorking
                    ) {
                        self.assigningTask = nil
                    } onAssign: { childId in
                        Task {
                            await appModel.assignTask(assigningTask.task, childId: childId)
                            if appModel.errorMessage == nil {
                                self.assigningTask = nil
                            }
                        }
                    }
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: assigningTask?.id)
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
            if !data.redemptions.isEmpty {
                ChorraSectionHeader(title: "Reward history")

                RewardHistoryCarouselView(
                    items: data.redemptions
                )
            }

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
    let canAssign: Bool
    let onEdit: () -> Void
    let onAssign: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onEdit) {
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 16)
                .padding(.trailing, 72)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PastelCardColor.color(from: item.task.cardColorHex))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit task \(item.task.title)")

            Button(action: onAssign) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canAssign ? Color.chorraPrimary : Color.chorraTextMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canAssign)
            .accessibilityLabel("Assign task")
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ParentTaskReviewCardView: View {
    let item: ParentTaskReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ChildAvatarView(child: item.child, size: 28)

                Text(childName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 8)

                ChorraPill(
                    title: item.assignment.status.label,
                    color: statusColor,
                    isFilled: item.assignment.status == .submitted
                )
            }

            HStack(spacing: 12) {
                ChorraIconView(
                    iconName: item.assignment.iconName,
                    size: 46,
                    background: .clear,
                    padding: 7
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.assignment.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.chorraTextPrimary)
                        .lineLimit(2)

                    ChorraPointAmountLabel(amount: item.assignment.pointValue, iconSize: 15)
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
        .background(PastelCardColor.color(from: item.assignment.cardColorHex))
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
        switch item.assignment.status {
        case .created:
            return .chorraTextSecondary
        case .assigned:
            return .chorraPrimary
        case .submitted:
            return .chorraPrimary
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

    let item: ParentTaskReviewItem

    @State private var rejectionReason = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ParentTaskReviewCardView(item: item)

                    RewardGroupedSection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photo proof")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.chorraTextPrimary)

                            proofImage
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chorraSoftSurface.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                reviewControls
            }
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

    private var reviewControls: some View {
        VStack(spacing: 12) {
            TextField("Reason if rejecting", text: $rejectionReason, axis: .vertical)
                .font(.body)
                .lineLimit(2...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.chorraSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.chorraBorder, lineWidth: 1)
                }
                .disabled(appModel.isWorking || submission == nil)

            HStack(spacing: 12) {
                Button {
                    approve()
                } label: {
                    Text("Approve")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraPrimaryButtonStyle())
                .disabled(appModel.isWorking || submission == nil)

                Button {
                    reject()
                } label: {
                    Text("Reject")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraError))
                .disabled(appModel.isWorking || submission == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.chorraSoftSurface)
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

private struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let task: ChorraTask?
    private let initialTitle: String
    private let initialPointValue: Int
    private let initialCardColorHex: String
    private let initialIconName: String

    @State private var title: String
    @State private var pointValue: Int
    @State private var cardColorHex: String
    @State private var iconName: String
    @State private var showingArchiveConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingPointValueDialog = false

    init(item: ParentTaskItem?) {
        let startingTitle = item?.task.title ?? ""
        let startingPointValue = item?.task.pointValue ?? 5
        let startingCardColorHex = PastelCardColor.normalizedPaletteHex(
            item?.task.cardColorHex ?? PastelCardColor.defaultHex
        )
        let startingIconName = ChorraIconCatalog.normalizedSelectableIconName(
            item?.task.iconName ?? ChorraIconCatalog.defaultIconName
        )

        task = item?.task
        initialTitle = startingTitle
        initialPointValue = startingPointValue
        initialCardColorHex = startingCardColorHex
        initialIconName = startingIconName
        _title = State(initialValue: startingTitle)
        _pointValue = State(initialValue: startingPointValue)
        _cardColorHex = State(initialValue: startingCardColorHex)
        _iconName = State(initialValue: startingIconName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    FormIconToolbar(
                        saveTitle: task == nil ? "Create" : "Save",
                        canSave: canSave,
                        isWorking: appModel.isWorking
                    ) {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    } onSave: {
                        Task {
                            await save()
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }

                    TextField("Task title", text: $title, axis: .vertical)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.chorraTextPrimary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    RewardColorPickerRow(selectedHex: $cardColorHex)

                    RewardGroupedSection {
                        Button {
                            showingPointValueDialog = true
                        } label: {
                            RewardListRow(
                                iconName: ChorraIconCatalog.pointIconName,
                                title: "Points",
                                value: "\(pointValue)",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Points")
                        .accessibilityValue("\(pointValue) points")
                    }

                    RewardGroupedSection {
                        IconPickerPanel(selectedIconName: $iconName)
                            .padding(.vertical, 4)
                    }

                    if task != nil {
                        RewardGroupedSection {
                            Button(role: .destructive) {
                                showingArchiveConfirmation = true
                            } label: {
                                RewardListRow(
                                    systemImage: "archivebox.fill",
                                    title: "Archive task",
                                    value: nil,
                                    titleColor: .chorraError,
                                    iconColor: .chorraError
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(appModel.isWorking)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chorraSoftSurface.ignoresSafeArea())
            .tint(.chorraPrimary)
        }
        .overlay {
            if showingPointValueDialog {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    TaskPointValueDialog(pointValue: $pointValue) {
                        showingPointValueDialog = false
                    }
                    .padding(24)
                }
                .transition(.opacity)
            } else if showingDiscardConfirmation {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    RewardDiscardChangesDialog {
                        showingDiscardConfirmation = false
                    } onDiscard: {
                        dismiss()
                    }
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showingPointValueDialog)
        .animation(.easeInOut(duration: 0.18), value: showingDiscardConfirmation)
        .alert("Archive task?", isPresented: $showingArchiveConfirmation) {
            Button("Archive", role: .destructive) {
                if let task {
                    Task {
                        await appModel.archiveTask(task)
                        if appModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the task from the parent task list. Existing assigned copies stay unchanged.")
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUnsavedChanges: Bool {
        title != initialTitle
            || pointValue != initialPointValue
            || PastelCardColor.normalizedPaletteHex(cardColorHex) != initialCardColorHex
            || ChorraIconCatalog.normalizedSelectableIconName(iconName) != initialIconName
    }

    private func save() async {
        if let task {
            await appModel.updateTask(
                task: task,
                title: title,
                pointValue: pointValue,
                cardColorHex: cardColorHex,
                iconName: iconName
            )
        } else {
            await appModel.createTask(
                title: title,
                pointValue: pointValue,
                cardColorHex: cardColorHex,
                iconName: iconName
            )
        }
    }
}

private struct AssignedTaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let item: ParentChildTaskItem
    private let initialTitle: String
    private let initialPointValue: Int
    private let initialCardColorHex: String
    private let initialIconName: String

    @State private var title: String
    @State private var pointValue: Int
    @State private var cardColorHex: String
    @State private var iconName: String
    @State private var showingDiscardConfirmation = false
    @State private var showingPointValueDialog = false

    init(item: ParentChildTaskItem) {
        let startingTitle = item.assignment.title
        let startingPointValue = item.assignment.pointValue
        let startingCardColorHex = PastelCardColor.normalizedPaletteHex(item.assignment.cardColorHex)
        let startingIconName = ChorraIconCatalog.normalizedSelectableIconName(item.assignment.iconName)

        self.item = item
        initialTitle = startingTitle
        initialPointValue = startingPointValue
        initialCardColorHex = startingCardColorHex
        initialIconName = startingIconName
        _title = State(initialValue: startingTitle)
        _pointValue = State(initialValue: startingPointValue)
        _cardColorHex = State(initialValue: startingCardColorHex)
        _iconName = State(initialValue: startingIconName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    FormIconToolbar(
                        saveTitle: "Save",
                        canSave: canSave,
                        isWorking: appModel.isWorking
                    ) {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    } onSave: {
                        Task {
                            await save()
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }

                    TextField("Task title", text: $title, axis: .vertical)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.chorraTextPrimary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    RewardColorPickerRow(selectedHex: $cardColorHex)

                    RewardGroupedSection {
                        Button {
                            showingPointValueDialog = true
                        } label: {
                            RewardListRow(
                                iconName: ChorraIconCatalog.pointIconName,
                                title: "Points",
                                value: "\(pointValue)",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Points")
                        .accessibilityValue("\(pointValue) points")
                    }

                    RewardGroupedSection {
                        IconPickerPanel(selectedIconName: $iconName)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chorraSoftSurface.ignoresSafeArea())
            .tint(.chorraPrimary)
        }
        .overlay {
            if showingPointValueDialog {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    TaskPointValueDialog(pointValue: $pointValue) {
                        showingPointValueDialog = false
                    }
                    .padding(24)
                }
                .transition(.opacity)
            } else if showingDiscardConfirmation {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    RewardDiscardChangesDialog {
                        showingDiscardConfirmation = false
                    } onDiscard: {
                        dismiss()
                    }
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showingPointValueDialog)
        .animation(.easeInOut(duration: 0.18), value: showingDiscardConfirmation)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUnsavedChanges: Bool {
        title != initialTitle
            || pointValue != initialPointValue
            || PastelCardColor.normalizedPaletteHex(cardColorHex) != initialCardColorHex
            || ChorraIconCatalog.normalizedSelectableIconName(iconName) != initialIconName
    }

    private func save() async {
        await appModel.updateTaskAssignment(
            assignment: item.assignment,
            title: title,
            pointValue: pointValue,
            cardColorHex: cardColorHex,
            iconName: iconName
        )
    }
}

private struct AssignTaskDialog: View {
    let children: [Child]
    let isWorking: Bool
    let onCancel: () -> Void
    let onAssign: (UUID) -> Void

    @State private var selectedChildId: UUID?

    init(
        children: [Child],
        isWorking: Bool,
        onCancel: @escaping () -> Void,
        onAssign: @escaping (UUID) -> Void
    ) {
        self.children = children
        self.isWorking = isWorking
        self.onCancel = onCancel
        self.onAssign = onAssign
        _selectedChildId = State(initialValue: children.first?.id)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                Text("Assign to")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.chorraTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.chorraSoftSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityLabel("Close")
            }

            Picker("Child", selection: Binding(
                get: { selectedChildId ?? children.first?.id },
                set: { selectedChildId = $0 }
            )) {
                ForEach(children) { child in
                    Text(child.displayName).tag(Optional(child.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.chorraSoftSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.chorraBorder, lineWidth: 1)
            }
            .disabled(isWorking || children.isEmpty)

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraSecondaryButtonStyle())
                .disabled(isWorking)

                Button {
                    guard let childId = selectedChildId ?? children.first?.id else {
                        return
                    }

                    onAssign(childId)
                } label: {
                    Text("Assign")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraPrimaryButtonStyle())
                .disabled(isWorking || !canAssign)
            }
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }

    private var canAssign: Bool {
        (selectedChildId ?? children.first?.id) != nil
    }
}

private struct FormIconToolbar: View {
    let saveTitle: String
    let canSave: Bool
    let isWorking: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button(action: onCancel) {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.chorraPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Button(action: onSave) {
                Text(saveTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(saveColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isWorking || !canSave)
            .accessibilityLabel(saveTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var saveColor: Color {
        isWorking || !canSave ? .chorraTextMuted : .chorraPrimary
    }
}

private struct RewardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let reward: Reward?
    private let initialName: String
    private let initialIconName: String
    private let initialPointCost: Int
    private let initialCardColorHex: String

    @State private var name: String
    @State private var iconName: String
    @State private var pointCost: Int
    @State private var cardColorHex: String
    @State private var showingArchiveConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingPointCostDialog = false

    init(item: RewardItem?) {
        let startingName = item?.reward.name ?? ""
        let startingIconName = ChorraIconCatalog.normalizedSelectableIconName(
            item?.reward.iconName ?? ChorraIconCatalog.defaultIconName
        )
        let startingPointCost = item?.reward.pointCost ?? 25
        let startingCardColorHex = PastelCardColor.normalizedPaletteHex(
            item?.reward.cardColorHex ?? PastelCardColor.defaultHex
        )

        reward = item?.reward
        initialName = startingName
        initialIconName = startingIconName
        initialPointCost = startingPointCost
        initialCardColorHex = startingCardColorHex
        _name = State(initialValue: startingName)
        _iconName = State(initialValue: startingIconName)
        _pointCost = State(initialValue: startingPointCost)
        _cardColorHex = State(initialValue: startingCardColorHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    FormIconToolbar(
                        saveTitle: reward == nil ? "Create" : "Save",
                        canSave: canSave,
                        isWorking: appModel.isWorking
                    ) {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    } onSave: {
                        Task {
                            await save()
                            if appModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }

                    TextField("Reward name", text: $name, axis: .vertical)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.chorraTextPrimary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    RewardColorPickerRow(selectedHex: $cardColorHex)

                    RewardGroupedSection {
                        Button {
                            showingPointCostDialog = true
                        } label: {
                            RewardListRow(
                                iconName: ChorraIconCatalog.pointIconName,
                                title: "Points",
                                value: "\(pointCost)",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Points")
                        .accessibilityValue("\(pointCost) points")
                    }

                    RewardGroupedSection {
                        IconPickerPanel(selectedIconName: $iconName)
                            .padding(.vertical, 4)
                    }

                    if reward != nil {
                        RewardGroupedSection {
                            Button(role: .destructive) {
                                showingArchiveConfirmation = true
                            } label: {
                                RewardListRow(
                                    systemImage: "archivebox.fill",
                                    title: "Archive reward",
                                    value: nil,
                                    titleColor: .chorraError,
                                    iconColor: .chorraError
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(appModel.isWorking)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chorraSoftSurface.ignoresSafeArea())
            .tint(.chorraPrimary)
        }
        .overlay {
            if showingPointCostDialog {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    RewardPointCostDialog(pointCost: $pointCost) {
                        showingPointCostDialog = false
                    }
                    .padding(24)
                }
                .transition(.opacity)
            } else if showingDiscardConfirmation {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    RewardDiscardChangesDialog {
                        showingDiscardConfirmation = false
                    } onDiscard: {
                        dismiss()
                    }
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showingPointCostDialog)
        .animation(.easeInOut(duration: 0.18), value: showingDiscardConfirmation)
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

    private var hasUnsavedChanges: Bool {
        name != initialName
            || ChorraIconCatalog.normalizedSelectableIconName(iconName) != initialIconName
            || pointCost != initialPointCost
            || PastelCardColor.normalizedPaletteHex(cardColorHex) != initialCardColorHex
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

private struct RewardGroupedSection<Content: View>: View {
    private let cornerRadius: CGFloat = 18

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.chorraBorder.opacity(0.36), lineWidth: 1)
        }
    }
}

private struct RewardColorPickerRow: View {
    @Binding var selectedHex: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PastelCardColor.allowedHexes, id: \.self) { hex in
                Button {
                    selectedHex = hex
                } label: {
                    Circle()
                        .fill(PastelCardColor.color(from: hex))
                        .overlay {
                            Circle()
                                .stroke(Color.chorraSurface, lineWidth: 3)
                        }
                        .overlay {
                            if isSelected(hex) {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(Color.chorraTextPrimary)
                            }
                        }
                        .shadow(color: Color.chorraPrimary.opacity(0.16), radius: 2, x: 0, y: 1)
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected(hex) ? Color.chorraPrimary : Color.chorraBorder,
                                    lineWidth: isSelected(hex) ? 2 : 1
                                )
                        }
                        .frame(width: 40, height: 40)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .accessibilityLabel("Card colour \(hex)")
                .accessibilityValue(isSelected(hex) ? "Selected" : "Not selected")
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            selectedHex = PastelCardColor.normalizedPaletteHex(selectedHex)
        }
    }

    private func isSelected(_ hex: String) -> Bool {
        PastelCardColor.normalizedPaletteHex(selectedHex) == hex
    }
}

private struct RewardListRow: View {
    var systemImage: String? = nil
    var iconName: String? = nil
    let title: String
    let value: String?
    var titleColor: Color = .chorraTextPrimary
    var iconColor: Color = .chorraPrimary
    var showsChevron = false

    var body: some View {
        HStack(spacing: 14) {
            icon
                .frame(width: 28)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleColor)

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary.opacity(0.62))
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        if let iconName {
            ChorraIconView(iconName: iconName, size: 28, padding: 0)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
        }
    }
}

private struct RewardDiscardChangesDialog: View {
    let onKeepEditing: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Discard changes?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Changes won't be saved.")
                    .font(.subheadline)
                    .foregroundStyle(Color.chorraTextSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button(action: onDiscard) {
                    Text("Discard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraSecondaryButtonStyle(tint: .chorraError))

                Button(action: onKeepEditing) {
                    Text("Keep editing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraPrimaryButtonStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }
}

private struct RewardPointCostDialog: View {
    @Binding var pointCost: Int
    let onClose: () -> Void

    private let pointCostRange: ClosedRange<Int> = 1...100000

    var body: some View {
        VStack(spacing: 20) {
            Text("Price")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.chorraTextPrimary)

            HStack(spacing: 20) {
                Button {
                    pointCost = max(pointCost - 1, pointCostRange.lowerBound)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.chorraPrimary)
                .background(Color.chorraPrimarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(pointCost <= pointCostRange.lowerBound)
                .accessibilityLabel("Decrease price")

                Text("\(pointCost)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.chorraPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 96)

                Button {
                    pointCost = min(pointCost + 1, pointCostRange.upperBound)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.chorraPrimary)
                .background(Color.chorraPrimarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(pointCost >= pointCostRange.upperBound)
                .accessibilityLabel("Increase price")
            }

            Button(action: onClose) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }
}

private struct TaskPointValueDialog: View {
    @Binding var pointValue: Int
    let onClose: () -> Void

    private let pointValueRange: ClosedRange<Int> = 1...500

    var body: some View {
        VStack(spacing: 20) {
            Text("Points")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.chorraTextPrimary)

            HStack(spacing: 20) {
                Button {
                    pointValue = max(pointValue - 1, pointValueRange.lowerBound)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.chorraPrimary)
                .background(Color.chorraPrimarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(pointValue <= pointValueRange.lowerBound)
                .accessibilityLabel("Decrease points")

                Text("\(pointValue)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.chorraPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 96)

                Button {
                    pointValue = min(pointValue + 1, pointValueRange.upperBound)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.chorraPrimary)
                .background(Color.chorraPrimarySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(pointValue >= pointValueRange.upperBound)
                .accessibilityLabel("Increase points")
            }

            Button(action: onClose) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
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

#Preview("Parent Settings") {
    ParentSettingsTab(data: .preview)
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
            pointValue: 8,
            cardColorHex: PastelCardColor.fallbackHex,
            iconName: ChorraIconCatalog.defaultIconName,
            isArchived: false,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let assignment = TaskAssignment(
            id: UUID(),
            householdId: householdId,
            taskId: task.id,
            childId: child.id,
            assignedBy: parentId,
            title: task.title,
            pointValue: task.pointValue,
            cardColorHex: task.cardColorHex,
            iconName: task.iconName,
            status: .submitted,
            isArchived: false,
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
            rewardCardColorHex: reward.cardColorHex,
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
            parents: [
                Profile(
                    id: parentId,
                    householdId: householdId,
                    role: .parent,
                    displayName: "Tommy",
                    createdAt: "2026-05-29",
                    updatedAt: "2026-05-29"
                ),
                Profile(
                    id: UUID(),
                    householdId: householdId,
                    role: .parent,
                    displayName: "Mia",
                    createdAt: "2026-05-29",
                    updatedAt: "2026-05-29"
                )
            ],
            children: [child],
            balances: [
                ChildPointsBalance(
                    childId: child.id,
                    householdId: householdId,
                    points: 18,
                    lastEarnedAt: "2026-05-29"
                )
            ],
            childTaskItems: [
                ParentChildTaskItem(
                    assignment: assignment,
                    latestSubmission: submission
                )
            ],
            taskItems: [
                ParentTaskItem(task: task)
            ],
            reviewItems: [
                ParentTaskReviewItem(
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
