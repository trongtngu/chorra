//
//  ChildDashboardView.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct ChildDashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData

    @State private var selectedTab: ChildDashboardTab = .home
    @State private var rewardToUnlock: RewardItem?

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
                rewardToUnlock: $rewardToUnlock
            )
            .environmentObject(appModel)
            .tag(ChildDashboardTab.rewards)
            .tabItem {
                Label(ChildDashboardTab.rewards.title, systemImage: ChildDashboardTab.rewards.systemImage)
            }
        }
        .chorraTabBar()
        .background(Color.chorraBackground)
        .alert("Unlock reward?", isPresented: unlockConfirmationBinding, presenting: rewardToUnlock) { item in
            Button("Unlock for \(item.reward.pointCost) pts") {
                Task { await appModel.redeemReward(item.reward) }
            }
            .disabled(appModel.isWorking)

            Button("Cancel", role: .cancel) {
                rewardToUnlock = nil
            }
        } message: { item in
            Text(item.reward.name)
        }
    }

    private var unlockConfirmationBinding: Binding<Bool> {
        Binding {
            rewardToUnlock != nil
        } set: { isPresented in
            if !isPresented {
                rewardToUnlock = nil
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
            pointsHeroCard

            ChorraSectionHeader(title: "Tasks")

            if incompleteTasks.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No tasks assigned", systemImage: "checklist")
                }
            } else {
                ForEach(incompleteTasks) { item in
                    NavigationLink {
                        ChildTaskDetailView(child: data.child, item: item)
                            .environmentObject(appModel)
                    } label: {
                        ChildTaskCardView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pointsHeroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(data.balance?.points ?? 0)")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(Color.chorraSurface)

                Text((data.balance?.points ?? 0) == 1 ? "point" : "points")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.chorraSurface.opacity(0.88))
            }

            Text(tasksAssignedText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.chorraSurface.opacity(0.74))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.chorraPrimary, Color.chorraPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var incompleteTasks: [ChildTaskItem] {
        data.tasks.filter { $0.task.status == .assigned || $0.task.status == .rejected }
    }

    private var tasksAssignedText: String {
        let count = incompleteTasks.count
        return "\(count) \(count == 1 ? "task" : "tasks") assigned"
    }
}

private struct ChildRewardsTab: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData
    @Binding var rewardToUnlock: RewardItem?
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ChildTabContainer(title: "Rewards") {
            ChorraSectionHeader(title: "Rewards")

            if data.rewards.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No rewards available", systemImage: "gift")
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(data.rewards) { item in
                        ChildRewardCardView(
                            item: item,
                            balance: data.balance?.points ?? 0
                        ) {
                            rewardToUnlock = item
                        }
                        .disabled(appModel.isWorking)
                    }
                }
            }

            ChorraSectionHeader(title: "Reward history")

            ChorraCard {
                if data.redemptions.isEmpty {
                    ChorraEmptyState(title: "No rewards unlocked yet", systemImage: "clock")
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

private struct ChildRewardCardView: View {
    let item: RewardItem
    let balance: Int
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            RewardEmojiView(emoji: item.reward.emoji, size: 52)

            Text(item.reward.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.chorraTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            Text("\(item.reward.pointCost) pts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(canUnlock ? Color.chorraPrimary : Color.chorraTextSecondary)

            Button("Unlock") {
                onUnlock()
            }
            .buttonStyle(ChorraSecondaryButtonStyle())
            .disabled(!canUnlock)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.chorraSoftSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }

    private var canUnlock: Bool {
        balance >= item.reward.pointCost
    }
}

private struct ChildTaskCardView: View {
    let item: ChildTaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: style.systemImage)
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(style.iconColor)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.task.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .lineLimit(2)

                Text(pointValueText)
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

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.chorraTextPrimary.opacity(0.54))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelCardColor.color(from: item.task.cardColorHex))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var pointValueText: String {
        "\(item.task.pointValue) \(item.task.pointValue == 1 ? "point" : "points")"
    }

    private var rejectionText: String? {
        guard let submission = item.latestSubmission, submission.status == .rejected else {
            return nil
        }

        return submission.rejectionReason ?? "Needs more work"
    }

    private var style: ChildTaskCardStyle {
        let indexSeed = item.id.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }

        return ChildTaskCardStyle.all[indexSeed % ChildTaskCardStyle.all.count]
    }
}

private struct ChildTaskCardStyle {
    let systemImage: String
    let iconColor: Color

    static let all: [ChildTaskCardStyle] = [
        ChildTaskCardStyle(
            systemImage: "fork.knife",
            iconColor: Color(red: 0.36, green: 0.55, blue: 0.16)
        ),
        ChildTaskCardStyle(
            systemImage: "square.grid.2x2.fill",
            iconColor: Color(red: 0.17, green: 0.48, blue: 0.50)
        ),
        ChildTaskCardStyle(
            systemImage: "bed.double.fill",
            iconColor: Color(red: 0.37, green: 0.30, blue: 0.70)
        ),
        ChildTaskCardStyle(
            systemImage: "dollarsign.circle.fill",
            iconColor: Color(red: 0.73, green: 0.42, blue: 0.12)
        ),
        ChildTaskCardStyle(
            systemImage: "sparkles",
            iconColor: Color(red: 0.43, green: 0.30, blue: 0.78)
        ),
        ChildTaskCardStyle(
            systemImage: "star.fill",
            iconColor: Color(red: 0.86, green: 0.49, blue: 0.05)
        ),
        ChildTaskCardStyle(
            systemImage: "paintbrush.pointed.fill",
            iconColor: Color(red: 0.18, green: 0.39, blue: 0.70)
        )
    ]
}

private struct ChildTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let child: Child
    let item: ChildTaskItem

    @StateObject private var camera = TaskCameraModel()

    var body: some View {
        VStack(spacing: 22) {
            Text("Send an image of the task")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.chorraTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            cameraSurface

            if camera.capturedJPEGData == nil {
                captureButton
            } else {
                reviewActions
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.chorraSurface.ignoresSafeArea())
        .navigationTitle("Complete")
        .navigationBarTitleDisplayMode(.inline)
        .chorraNavigationBar()
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var cameraSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)

            if let capturedImage = camera.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                switch camera.cameraState {
                case .idle, .configuring:
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.chorraSurface)

                        Text("Starting camera")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chorraSurface.opacity(0.78))
                    }
                case .ready:
                    TaskCameraPreview(session: camera.session)
                case .unavailable(let message):
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)

                        Text(message)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Color.chorraSurface.opacity(0.82))
                    .padding(24)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: 430)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
        .clipped()
    }

    private var captureButton: some View {
        Button {
            camera.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.chorraTextPrimary.opacity(0.18), lineWidth: 5)
                    .frame(width: 78, height: 78)

                Circle()
                    .fill(canCapture ? Color.chorraPrimary : Color.chorraTextMuted)
                    .frame(width: 62, height: 62)

                Image(systemName: "camera.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.chorraSurface)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canCapture || appModel.isWorking)
        .accessibilityLabel("Take photo")
    }

    private var reviewActions: some View {
        HStack(spacing: 12) {
            Button("Retake") {
                camera.retake()
            }
            .buttonStyle(ChorraSecondaryButtonStyle())
            .disabled(appModel.isWorking)

            Button("Submit for review") {
                guard let jpegData = camera.capturedJPEGData else {
                    return
                }

                Task {
                    await appModel.submitTaskCompletion(
                        assignment: item.assignment,
                        child: child,
                        jpegData: jpegData
                    )

                    if appModel.errorMessage == nil {
                        dismiss()
                    }
                }
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
            .disabled(appModel.isWorking || camera.capturedJPEGData == nil)
        }
    }

    private var canCapture: Bool {
        camera.cameraState.isReady && camera.capturedJPEGData == nil
    }
}

private enum TaskCameraState {
    case idle
    case configuring
    case ready
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self {
            return true
        }

        return false
    }
}

private final class TaskCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var cameraState: TaskCameraState = .idle
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var capturedJPEGData: Data?

    private let sessionQueue = DispatchQueue(label: "com.trongpapaya.chorra.task-camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var photoDelegate: TaskPhotoCaptureDelegate?

    func start() {
        guard capturedJPEGData == nil else {
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            cameraState = .configuring
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
                DispatchQueue.main.async {
                    if isGranted {
                        self?.configureAndStart()
                    } else {
                        self?.cameraState = .unavailable("Camera access is off.")
                    }
                }
            }
        case .denied, .restricted:
            cameraState = .unavailable("Camera access is off.")
        @unknown default:
            cameraState = .unavailable("Camera is unavailable.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        guard cameraState.isReady, capturedJPEGData == nil else {
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced

        let delegate = TaskPhotoCaptureDelegate { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                switch result {
                case .success(let photo):
                    self.capturedImage = photo.image
                    self.capturedJPEGData = photo.jpegData
                    self.stop()
                case .failure:
                    self.cameraState = .unavailable("Could not take photo. Try again.")
                }

                self.photoDelegate = nil
            }
        }

        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func retake() {
        capturedImage = nil
        capturedJPEGData = nil
        start()
    }

    private func configureAndStart() {
        cameraState = .configuring

        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if !self.isConfigured {
                do {
                    try self.configureSession()
                } catch {
                    DispatchQueue.main.async {
                        self.cameraState = .unavailable("Camera is unavailable.")
                    }
                    return
                }
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.cameraState = .ready
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            throw TaskCameraError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)

        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw TaskCameraError.unavailable
        }

        session.addInput(input)
        session.addOutput(photoOutput)

        photoOutput.maxPhotoQualityPrioritization = .balanced
        isConfigured = true
    }
}

private final class TaskPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    struct CapturedPhoto {
        let image: UIImage
        let jpegData: Data
    }

    private let completion: (Result<CapturedPhoto, Error>) -> Void

    init(completion: @escaping (Result<CapturedPhoto, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82) else {
            completion(.failure(TaskCameraError.invalidPhoto))
            return
        }

        completion(.success(CapturedPhoto(image: image, jpegData: jpegData)))
    }
}

private enum TaskCameraError: Error {
    case unavailable
    case invalidPhoto
}

private struct TaskCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> TaskCameraPreviewView {
        let view = TaskCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: TaskCameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class TaskCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview("Child Home") {
    ChildHomeTab(data: .preview)
        .environmentObject(AppViewModel())
}

#Preview("Child Rewards") {
    ChildRewardsTab(data: .preview, rewardToUnlock: .constant(nil))
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
            cardColorHex: PastelCardColor.fallbackHex,
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
            emoji: "🎮",
            pointCost: 25,
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
            rewardEmoji: "⭐️",
            rewardPointCost: 12,
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
            rewards: [RewardItem(reward: reward)],
            redemptions: [RewardRedemptionItem(redemption: redemption, child: nil)]
        )
    }
}
