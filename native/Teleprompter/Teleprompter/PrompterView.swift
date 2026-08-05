//
//  PrompterView.swift
//  Teleprompter
//
//  The camera + teleprompter screen: fullscreen preview, the scrolling script overlay
//  beside the lens (never in the recording), reading-line, controls, and countdown.
//

import SwiftUI
import UIKit

struct PrompterView: View {
    @ObservedObject var settings: Settings
    var onBack: () -> Void

    @StateObject private var camera = CameraController()
    @StateObject private var scroll = ScrollDriver()
    @State private var textHeight: CGFloat = 0
    @State private var showingSettings = false
    @State private var countdownValue: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var scrubStartOffset: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let box = settings.box()
            let rect = box.rect(in: geo.size)

            ZStack {
                Color.black
                CameraPreview(controller: camera)

                if settings.cropGuide && geo.size.width > geo.size.height {
                    cropGuideOverlay(in: geo.size)
                }

                TeleprompterBox(settings: settings, scroll: scroll, box: box,
                                size: rect.size, textHeight: $textHeight)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                // Drag anywhere over the text box to scrub the script (pauses auto-scroll).
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .gesture(scrubGesture)

                controlsLayer
                topBarLayer

                if camera.isRecording { recordingIndicator }
                if let value = countdownValue { countdownOverlay(value) }
                if let toast = camera.toast { toastView(toast) }
                if let error = camera.errorMessage { errorView(error) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            camera.start()
            UIApplication.shared.isIdleTimerDisabled = true
            scroll.speed = CGFloat(settings.speed)
        }
        .onDisappear {
            countdownTask?.cancel()
            camera.stop()
            scroll.pause()
            OrientationLock.unlock()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: camera.isRecording) { _, recording in
            if recording { OrientationLock.lockToCurrent() } else { OrientationLock.unlock() }
        }
        .onChange(of: settings.speed) { _, value in scroll.speed = CGFloat(value) }
        .onChange(of: textHeight) { _, value in scroll.maxOffset = value }
        .onChange(of: settings.mirror) { _, value in camera.setPreviewMirrored(value) }
        .onChange(of: camera.isSessionRunning) { _, running in
            if running { camera.setPreviewMirrored(settings.mirror) }
        }
        .sheet(isPresented: $showingSettings) { SettingsSheet(settings: settings) }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsLayer: some View {
        if settings.position == .top {
            HStack(spacing: 22) { restartButton; recordButton; playButton }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 30)
        } else {
            VStack(spacing: 18) { restartButton; recordButton; playButton }
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: settings.position == .right ? .leading : .trailing)
                .padding(.horizontal, 18)
        }
    }

    private var restartButton: some View {
        circleButton(system: "arrow.counterclockwise", diameter: 50) { scroll.reset() }
    }

    private var recordButton: some View {
        Button(action: onRecordTapped) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 74, height: 74)
                RoundedRectangle(cornerRadius: camera.isRecording ? 6 : 29, style: .continuous)
                    .fill(.red)
                    .frame(width: camera.isRecording ? 30 : 58, height: camera.isRecording ? 30 : 58)
            }
        }
        .disabled(!camera.isSessionRunning)
        .opacity(camera.isSessionRunning ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: camera.isRecording)
    }

    private var playButton: some View {
        circleButton(system: scroll.isRunning ? "pause.fill" : "play.fill", diameter: 60) { scroll.toggle() }
            .disabled(!camera.isSessionRunning)
    }

    private func circleButton(system: String, diameter: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(.black.opacity(0.5), in: Circle())
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBarLayer: some View {
        let atBottom = settings.position == .top
        HStack(spacing: 8) {
            Button(action: leaveTake) {
                Label("Script", systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
            }
            .tint(.white)

            if !camera.resolutionText.isEmpty {
                Text(camera.resolutionText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5), in: Circle())
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: atBottom ? .bottom : .top)
        .padding(.top, atBottom ? 0 : 12)
        .padding(.bottom, atBottom ? 96 : 0)
    }

    // MARK: - Overlays

    private func countdownOverlay(_ value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 120, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.35))
    }

    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 10, height: 10)
            Text(timeString(camera.elapsed)).font(.system(size: 14, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
    }

    private func toastView(_ toast: String) -> some View {
        Text(toast)
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.black.opacity(0.75), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 44)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash").font(.system(size: 40)).foregroundStyle(.white.opacity(0.85))
            Text("Camera problem").font(.headline).foregroundStyle(.white)
            Text(error).font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("Back to script", action: onBack).tint(.white).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
    }

    // MARK: - Actions

    private func onRecordTapped() {
        if camera.isRecording {
            camera.toggleRecording()
            scroll.pause()
        } else if countdownValue != nil {
            countdownTask?.cancel()
            countdownValue = nil
            scroll.reset()
        } else {
            startTake()
        }
    }

    private func startTake() {
        scroll.reset()
        guard settings.countdown > 0 else { beginRecording(); return }
        countdownTask = Task { @MainActor in
            for n in stride(from: settings.countdown, through: 1, by: -1) {
                countdownValue = n
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { countdownValue = nil; return }
            }
            countdownValue = nil
            beginRecording()
        }
    }

    private func beginRecording() {
        camera.toggleRecording()
        scroll.play()
    }

    private func leaveTake() {
        countdownTask?.cancel()
        countdownValue = nil
        onBack()
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Scrub (drag the script to reposition)

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if scrubStartOffset == nil {
                    scrubStartOffset = scroll.offset
                    scroll.pause()   // stop auto-scroll while the user drags
                }
                let start = scrubStartOffset ?? scroll.offset
                // Drag up → advance (offset grows); drag down → rewind. Clamp to the script.
                scroll.offset = min(scroll.maxOffset, max(0, start - value.translation.height))
            }
            .onEnded { _ in
                scrubStartOffset = nil
            }
    }

    // MARK: - Portrait crop guide

    /// Two vertical lines marking where a centered 9:16 portrait crop of the (16:9) landscape
    /// frame would land. Overlay only — never part of the recording.
    private func cropGuideOverlay(in size: CGSize) -> some View {
        let cropWidth = size.height * (9.0 / 16.0)   // full height, 9:16 width
        let inset = max(0, (size.width - cropWidth) / 2)
        let line = Color.yellow.opacity(0.85)
        return ZStack(alignment: .top) {
            Rectangle().fill(line).frame(width: 2, height: size.height)
                .position(x: inset, y: size.height / 2)
            Rectangle().fill(line).frame(width: 2, height: size.height)
                .position(x: size.width - inset, y: size.height / 2)
            Text("Portrait 9:16 crop")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(line)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                .padding(.top, 10)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Scrolling text box

struct TeleprompterBox: View {
    @ObservedObject var settings: Settings
    @ObservedObject var scroll: ScrollDriver
    let box: TextBox
    let size: CGSize
    @Binding var textHeight: CGFloat

    var body: some View {
        let padTop = box.focus * size.height
        let padBot = (1 - box.focus) * size.height

        ZStack(alignment: .top) {
            Color.black.opacity(settings.dim / 100)

            Text(displayScript)
                .font(.system(size: settings.font, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(box.alignment)
                .lineSpacing(settings.font * 0.35)
                .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
                .frame(width: max(0, size.width - 44), alignment: box.frameAlignment)
                .fixedSize(horizontal: false, vertical: true)   // claim full multi-line height
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: TextHeightKey.self, value: proxy.size.height)
                    }
                )
                .padding(.top, padTop)
                .padding(.bottom, padBot)
                .frame(width: size.width)
                .offset(y: -scroll.offset)

            Rectangle()
                .fill(Color.red.opacity(0.55))
                .frame(width: size.width, height: 2)
                .shadow(color: .red.opacity(0.4), radius: 4)
                .offset(y: box.focus * size.height)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        )
        .onPreferenceChange(TextHeightKey.self) { textHeight = $0 }
    }

    private var displayScript: String {
        let trimmed = settings.scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(no script)" : trimmed
    }
}

struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
