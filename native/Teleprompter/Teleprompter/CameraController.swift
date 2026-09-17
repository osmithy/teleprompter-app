//
//  CameraController.swift
//  Teleprompter
//
//  Milestone 1 — the capture engine.
//  Front camera at 1080p, clean external-mic audio, record a full-quality .mov, and
//  save it straight to Photos. The teleprompter overlay, settings, and review flow arrive
//  in later milestones; this file only owns capture + recording.
//
//  Threading model: the project default isolation is `nonisolated`, so this is a plain
//  class. All AVCaptureSession work happens on `sessionQueue`; every @Published change is
//  pushed back to the main thread via `onMain`. AVFoundation delegate callbacks arrive on
//  an arbitrary queue and are handled the same way.
//

import AVFoundation
import Combine
import CoreMedia
import Photos
import UIKit

final class CameraController: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {

    // MARK: - Published UI state (only ever mutated on the main thread)
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var resolutionText = ""
    @Published var statusMessage = "Starting camera…"
    @Published var errorMessage: String?
    @Published var toast: String?
    /// Native capture aspect (width / height, e.g. 1920/1080). Framing guides use this so they
    /// line up with the real frame rather than the whole screen when the preview is letterboxed.
    @Published var captureAspect: CGFloat = 16.0 / 9.0
    /// A frame from the most recent take, shown on the Photos shortcut button.
    @Published var lastThumbnail: UIImage?

    // MARK: - Capture objects
    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let sessionQueue = DispatchQueue(label: "TeleprompterCameraSession")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewAngleObservation: NSKeyValueObservation?
    private var captureAngleObservation: NSKeyValueObservation?
    private var recordingStart: Date?
    private var recordingTimer: Timer?

    override init() {
        super.init()
        previewLayer.session = session
        // .resizeAspect (fit) rather than .resizeAspectFill so the preview always shows the
        // ENTIRE captured frame, letterboxed when the screen's shape differs from the camera's.
        // Filling would crop the preview and hide parts of the shot that still land in the file.
        previewLayer.videoGravity = .resizeAspect
        loadPersistedThumbnail()
    }

    // MARK: - Start / stop

    func start() {
        requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.onMain {
                    self.errorMessage = "Camera and microphone access are needed. Turn them on in Settings › Teleprompter, then reopen the app."
                }
                return
            }
            self.sessionQueue.async { self.configureSession() }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
            self.onMain { self.isSessionRunning = false }
        }
    }

    // MARK: - Permissions

    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            guard videoGranted else { completion(false); return }
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                completion(audioGranted)
            }
        }
    }

    // MARK: - Session configuration (runs on sessionQueue)

    private func configureSession() {
        // Own the audio session ourselves so the mic is captured clean (see configureAudioSession).
        session.automaticallyConfiguresApplicationAudioSession = false
        configureAudioSession()

        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080   // 1080p; the SE 2 front camera runs this at 30 fps

        // Front wide-angle camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            session.commitConfiguration()
            onMain { self.errorMessage = "No front camera was found on this device." }
            return
        }
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) { session.addInput(videoInput) }
        } catch {
            session.commitConfiguration()
            onMain { self.errorMessage = "Couldn't open the front camera: \(error.localizedDescription)" }
            return
        }

        // Microphone — the default audio device follows the current route, so the external
        // Lightning mic is used automatically whenever it's plugged in.
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        // Full-quality .mov output
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        // Record un-mirrored (how others see you). The preview is mirrored separately, below.
        if let movieConnection = movieOutput.connection(with: .video),
           movieConnection.isVideoMirroringSupported {
            movieConnection.automaticallyAdjustsVideoMirroring = false
            movieConnection.isVideoMirrored = false
        }

        session.commitConfiguration()
        session.startRunning()

        onMain {
            self.isSessionRunning = self.session.isRunning
            self.statusMessage = ""
            self.updateResolutionText(for: camera)
            self.setupPreviewMirroringAndRotation(for: camera)
        }
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // .videoRecording mode captures the mic with no voice-processing DSP (echo
            // cancellation / noise suppression / auto-gain). That DSP is exactly what muddied
            // the external mic in the web version — this keeps a good external mic clean.
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [])
            try audioSession.setActive(true)
        } catch {
            onMain { self.showToast("Audio setup warning: \(error.localizedDescription)") }
        }
    }

    // MARK: - Preview mirroring + rotation (main thread — touches the preview layer)

    private func setupPreviewMirroringAndRotation(for camera: AVCaptureDevice) {
        if let previewConnection = previewLayer.connection,
           previewConnection.isVideoMirroringSupported {
            previewConnection.automaticallyAdjustsVideoMirroring = false
            previewConnection.isVideoMirrored = true   // mirror preview for on-camera comfort
        }

        // The RotationCoordinator tracks the physical device orientation and publishes the
        // angles that keep the preview and the recording upright. Observe those angles with
        // KVO and apply each change as it happens — polling device-orientation notifications
        // reads a stale angle and leaves the preview sideways after a rotation.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: previewLayer)
        rotationCoordinator = coordinator

        previewAngleObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            self?.applyPreviewAngle(coordinator.videoRotationAngleForHorizonLevelPreview)
        }
        captureAngleObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            self?.applyCaptureAngle(coordinator.videoRotationAngleForHorizonLevelCapture)
        }
    }

    private func applyPreviewAngle(_ angle: CGFloat) {
        onMain {
            if let connection = self.previewLayer.connection,
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    private func applyCaptureAngle(_ angle: CGFloat) {
        sessionQueue.async {
            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    /// Mirror (or un-mirror) the on-screen preview. Recording stays un-mirrored regardless.
    func setPreviewMirrored(_ mirrored: Bool) {
        onMain {
            guard let connection = self.previewLayer.connection,
                  connection.isVideoMirroringSupported else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        sessionQueue.async {
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            } else {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("teleprompter-\(Self.timestamp()).mov")
                self.movieOutput.startRecording(to: url, recordingDelegate: self)
            }
        }
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate (called on an arbitrary queue)

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        onMain {
            self.isRecording = true
            self.recordingStart = Date()
            self.elapsed = 0
            self.recordingTimer?.invalidate()
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStart else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        onMain {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }

        // AVCaptureMovieFileOutput can report a non-nil error even when the file is fine —
        // trust AVErrorRecordingSuccessfullyFinishedKey.
        if let error = error as NSError? {
            let finishedOK = (error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
            if !finishedOK {
                onMain { self.errorMessage = "Recording failed: \(error.localizedDescription)" }
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
        }
        // Grab the thumbnail first — saveToPhotos deletes the temp file when it finishes.
        makeThumbnail(from: outputFileURL) { [weak self] in
            self?.saveToPhotos(outputFileURL)
        }
    }

    // MARK: - Last-take thumbnail (powers the Photos shortcut)

    /// Pull a frame from the finished take for the library button. Reading our own local file
    /// means this needs no read access to the photo library — the app stays add-only.
    private func makeThumbnail(from url: URL, completion: @escaping () -> Void) {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true   // honour the recorded rotation
        generator.maximumSize = CGSize(width: 240, height: 240)
        generator.generateCGImageAsynchronously(
            for: CMTime(seconds: 0.1, preferredTimescale: 600)
        ) { [weak self] cgImage, _, _ in
            defer { completion() }                        // always save, thumbnail or not
            guard let self, let cgImage else { return }
            let image = UIImage(cgImage: cgImage)
            self.onMain { self.lastThumbnail = image }
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: Self.thumbnailURL)
            }
        }
    }

    private static var thumbnailURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("last-take.jpg")
    }

    /// Restore the last take's thumbnail so the button survives a relaunch.
    private func loadPersistedThumbnail() {
        if let data = try? Data(contentsOf: Self.thumbnailURL), let image = UIImage(data: data) {
            lastThumbnail = image
        }
    }

    // MARK: - Save to Photos (add-only)

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] authStatus in
            guard let self else { return }
            guard authStatus == .authorized || authStatus == .limited else {
                self.onMain { self.showToast("Couldn't save — Photos access was denied.") }
                try? FileManager.default.removeItem(at: url)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            } completionHandler: { success, error in
                self.onMain {
                    self.showToast(success ? "Saved to Photos ✓"
                                           : "Save failed: \(error?.localizedDescription ?? "unknown error")")
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Helpers

    private func updateResolutionText(for camera: AVCaptureDevice) {
        let dims = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription)
        let fps = camera.activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0
        resolutionText = "\(dims.width)×\(dims.height)" + (fps > 0 ? " · \(Int(fps.rounded())) fps" : "")
        if dims.width > 0 && dims.height > 0 {
            captureAspect = CGFloat(dims.width) / CGFloat(dims.height)
        }
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.toast == message { self?.toast = nil }
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    deinit {
        previewAngleObservation?.invalidate()
        captureAngleObservation?.invalidate()
    }
}
