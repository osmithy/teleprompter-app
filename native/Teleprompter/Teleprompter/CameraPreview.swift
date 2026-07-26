//
//  CameraPreview.swift
//  Teleprompter
//
//  Hosts the AVCaptureVideoPreviewLayer (owned by CameraController) inside SwiftUI.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.attach(controller.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    /// A plain UIView that keeps the capture preview layer sized to its bounds.
    final class PreviewView: UIView {
        private weak var previewLayer: AVCaptureVideoPreviewLayer?

        func attach(_ layer: AVCaptureVideoPreviewLayer) {
            previewLayer?.removeFromSuperlayer()
            layer.frame = bounds
            self.layer.addSublayer(layer)
            previewLayer = layer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
