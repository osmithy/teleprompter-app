//
//  CameraPreview.swift
//  Teleprompter
//
//  Hosts the AVCaptureVideoPreviewLayer (owned by CameraController) inside SwiftUI, and
//  carries the hardware capture-button interaction (volume keys / Bluetooth shutters).
//

import SwiftUI
import AVFoundation
import AVKit

struct CameraPreview: UIViewRepresentable {
    let controller: CameraController
    /// Fired when a hardware capture button is pressed — the volume keys, or a Bluetooth
    /// shutter remote (they work by simulating a volume-up press). Same action as tapping record.
    var onCaptureButton: (() -> Void)? = nil

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.attach(controller.previewLayer)
        view.setCaptureButtonHandler(onCaptureButton)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Refresh the closure each update so it always sees current view state.
        uiView.setCaptureButtonHandler(onCaptureButton)
    }

    /// A plain UIView that keeps the preview layer sized to its bounds and hosts the
    /// AVCaptureEventInteraction that receives hardware shutter presses.
    final class PreviewView: UIView {
        private weak var previewLayer: AVCaptureVideoPreviewLayer?
        private var captureButtonHandler: (() -> Void)?
        private var captureInteraction: AVCaptureEventInteraction?

        func attach(_ layer: AVCaptureVideoPreviewLayer) {
            previewLayer?.removeFromSuperlayer()
            layer.frame = bounds
            self.layer.addSublayer(layer)
            previewLayer = layer
        }

        /// Routes the volume buttons to us instead of changing system volume. This is Apple's
        /// sanctioned path for camera apps (iOS 17.2+), and it's what Bluetooth shutter remotes
        /// drive, since they just simulate a volume-up press.
        func setCaptureButtonHandler(_ handler: (() -> Void)?) {
            captureButtonHandler = handler
            guard captureInteraction == nil else { return }
            let interaction = AVCaptureEventInteraction { [weak self] event in
                // Act on release so one press is exactly one trigger.
                guard event.phase == .ended else { return }
                self?.captureButtonHandler?()
            }
            addInteraction(interaction)
            captureInteraction = interaction
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
