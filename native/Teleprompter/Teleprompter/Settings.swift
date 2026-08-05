//
//  Settings.swift
//  Teleprompter
//
//  Persisted user settings + the geometry of the scrolling text box per position.
//  Defaults mirror the tuned web version.
//

import SwiftUI
import Combine

enum TextPosition: String, CaseIterable, Identifiable {
    case top, left, center, right

    var id: String { rawValue }
    var label: String {
        switch self {
        case .top:    return "Top"
        case .left:   return "Left"
        case .center: return "Center"
        case .right:  return "Right"
        }
    }

    /// A wide band across the top vs. a side column — they use different default widths.
    var isBand: Bool { self == .top }
}

/// Geometry of the scrolling text box for a position, as percentages of the screen, plus
/// the reading-line focus fraction (0 = box top, 1 = box bottom) and text alignment.
struct TextBox {
    var xPct: Double
    var yPct: Double
    var wPct: Double
    var hPct: Double
    var focus: Double
    var alignment: TextAlignment
    var frameAlignment: Alignment

    func rect(in size: CGSize) -> CGRect {
        CGRect(x: xPct / 100 * size.width,
               y: yPct / 100 * size.height,
               width: wPct / 100 * size.width,
               height: hPct / 100 * size.height)
    }
}

final class Settings: ObservableObject {
    @Published var speed: Double = 65 { didSet { persist() } }          // pt/s
    @Published var font: Double = 38 { didSet { persist() } }           // pt
    @Published var columnWidth: Double = 46 { didSet { persist() } }    // % of width (side columns)
    @Published var bandWidth: Double = 92 { didSet { persist() } }      // % of width (top band)
    @Published var dim: Double = 35 { didSet { persist() } }            // 0…85 %
    @Published var position: TextPosition = .left { didSet { persist() } }
    @Published var mirror: Bool = true { didSet { persist() } }
    @Published var countdown: Int = 3 { didSet { persist() } }          // 0 / 3 / 5
    @Published var cropGuide: Bool = false { didSet { persist() } }     // 9:16 portrait-crop guide
    @Published var scriptText: String = Settings.sampleScript { didSet { persist() } }

    private var loaded = false

    /// The width slider edits column-width or band-width depending on the current position.
    var currentWidth: Double {
        get { position.isBand ? bandWidth : columnWidth }
        set { if position.isBand { bandWidth = newValue } else { columnWidth = newValue } }
    }

    func box() -> TextBox {
        let w = currentWidth
        switch position {
        case .right:
            return TextBox(xPct: 100 - w, yPct: 0, wPct: w, hPct: 100, focus: 0.5,
                           alignment: .trailing, frameAlignment: .trailing)
        case .center:
            return TextBox(xPct: (100 - w) / 2, yPct: 0, wPct: w, hPct: 100, focus: 0.5,
                           alignment: .center, frameAlignment: .center)
        case .top:
            return TextBox(xPct: (100 - w) / 2, yPct: 4, wPct: w, hPct: 46, focus: 0.28,
                           alignment: .center, frameAlignment: .center)
        case .left:
            return TextBox(xPct: 0, yPct: 0, wPct: w, hPct: 100, focus: 0.5,
                           alignment: .leading, frameAlignment: .leading)
        }
    }

    init() {
        let d = UserDefaults.standard
        if let v = d.object(forKey: Keys.speed) as? Double { speed = v }
        if let v = d.object(forKey: Keys.font) as? Double { font = v }
        if let v = d.object(forKey: Keys.columnWidth) as? Double { columnWidth = v }
        if let v = d.object(forKey: Keys.bandWidth) as? Double { bandWidth = v }
        if let v = d.object(forKey: Keys.dim) as? Double { dim = v }
        if let v = d.string(forKey: Keys.position), let p = TextPosition(rawValue: v) { position = p }
        if let v = d.object(forKey: Keys.mirror) as? Bool { mirror = v }
        if let v = d.object(forKey: Keys.countdown) as? Int { countdown = v }
        if let v = d.object(forKey: Keys.cropGuide) as? Bool { cropGuide = v }
        if let v = d.string(forKey: Keys.script) { scriptText = v }
        loaded = true
    }

    private func persist() {
        guard loaded else { return }
        let d = UserDefaults.standard
        d.set(speed, forKey: Keys.speed)
        d.set(font, forKey: Keys.font)
        d.set(columnWidth, forKey: Keys.columnWidth)
        d.set(bandWidth, forKey: Keys.bandWidth)
        d.set(dim, forKey: Keys.dim)
        d.set(position.rawValue, forKey: Keys.position)
        d.set(mirror, forKey: Keys.mirror)
        d.set(countdown, forKey: Keys.countdown)
        d.set(cropGuide, forKey: Keys.cropGuide)
        d.set(scriptText, forKey: Keys.script)
    }

    private enum Keys {
        static let speed = "tp.speed"
        static let font = "tp.font"
        static let columnWidth = "tp.colW"
        static let bandWidth = "tp.bandW"
        static let dim = "tp.dim"
        static let position = "tp.pos"
        static let mirror = "tp.mirror"
        static let countdown = "tp.count"
        static let cropGuide = "tp.cropGuide"
        static let script = "tp.script"
    }

    static let sampleScript = """
    Welcome! This is your teleprompter.

    Paste your own script here, then tap Start camera. Landscape or portrait both work — in Settings, set the text position next to your lens (Left for landscape, Top for portrait) so the words scroll right beside it.

    Use the round buttons to record, play, and restart, and adjust speed and text size in Settings.

    You've got this.
    """
}
