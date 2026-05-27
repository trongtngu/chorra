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

    @State private var showingAddChild = false
    @State private var showingCreateTask = false

    var body: some View {
        NavigationStack {
            List {
                householdSection
                childrenSection
                tasksSection
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
        taskItems: []
    ))
    .environmentObject(AppViewModel())
}
