//
//  ScrollDriver.swift
//  Teleprompter
//
//  A CADisplayLink-driven vertical scroll offset — smooth at the display's refresh rate.
//  The view keeps `speed` (pt/s) in sync with Settings and `maxOffset` with the measured
//  text height; scrolling stops when it reaches the end.
//

import Combine
import UIKit

final class ScrollDriver: NSObject, ObservableObject {
    @Published var offset: CGFloat = 0
    @Published private(set) var isRunning = false

    var speed: CGFloat = 65      // points per second
    var maxOffset: CGFloat = 0   // scrollable text height

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func play() {
        guard !isRunning, maxOffset > 0 else { return }
        if offset >= maxOffset { offset = 0 }   // restart if parked at the end
        isRunning = true
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func pause() {
        isRunning = false
        link?.invalidate()
        link = nil
    }

    func toggle() { isRunning ? pause() : play() }

    func reset() {
        pause()
        offset = 0
    }

    @objc private func step(_ link: CADisplayLink) {
        guard lastTimestamp != 0 else { lastTimestamp = link.timestamp; return }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        offset += speed * CGFloat(dt)
        if offset >= maxOffset {
            offset = maxOffset
            pause()
        }
    }

    deinit { link?.invalidate() }
}
