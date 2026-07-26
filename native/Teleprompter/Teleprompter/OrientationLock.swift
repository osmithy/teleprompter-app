//
//  OrientationLock.swift
//  Teleprompter
//
//  SwiftUI has no built-in way to lock interface orientation, so a minimal app delegate
//  reports the currently-allowed orientations and `OrientationLock` flips them. We pin the
//  UI to its current orientation while recording (the recording's orientation is fixed at
//  record-start) and release it when recording stops.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The orientations the app currently permits. Default: portrait + both landscapes.
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.mask
    }
}

@MainActor
enum OrientationLock {
    /// Pin the interface to whatever orientation it's in right now (used while recording).
    static func lockToCurrent() {
        guard let orientation = activeScene()?.effectiveGeometry.interfaceOrientation else {
            apply(.allButUpsideDown)
            return
        }
        let mask: UIInterfaceOrientationMask
        switch orientation {
        case .portrait:           mask = .portrait
        case .portraitUpsideDown: mask = .portraitUpsideDown
        case .landscapeLeft:      mask = .landscapeLeft
        case .landscapeRight:     mask = .landscapeRight
        default:                  mask = .allButUpsideDown
        }
        apply(mask)
    }

    /// Allow portrait + both landscapes again (used when recording stops).
    static func unlock() {
        apply(.allButUpsideDown)
    }

    private static func apply(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.mask = mask
        activeScene()?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
