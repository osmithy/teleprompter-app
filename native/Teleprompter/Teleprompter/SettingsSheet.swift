//
//  SettingsSheet.swift
//  Teleprompter
//
//  The persisted settings UI: speed, font, width, dimming, position, mirror, countdown.
//

import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    sliderRow("Scroll speed", value: $settings.speed, range: 10...220, step: 5, suffix: " pt/s")
                    sliderRow("Font size", value: $settings.font, range: 16...86, step: 1, suffix: " pt")
                    sliderRow("Text width",
                              value: Binding(get: { settings.currentWidth },
                                             set: { settings.currentWidth = $0 }),
                              range: 25...100, step: 1, suffix: "%")
                    if settings.position == .top {
                        sliderRow("Text height", value: $settings.bandHeight,
                                  range: 20...85, step: 1, suffix: "%")
                    }
                    sliderRow("Text dimming", value: $settings.dim, range: 0...85, step: 5, suffix: "%")
                }

                Section("Text position") {
                    Picker("Position", selection: $settings.position) {
                        ForEach(TextPosition.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Toggle("Mirror preview", isOn: $settings.mirror)
                    Picker("Countdown", selection: $settings.countdown) {
                        Text("Off").tag(0)
                        Text("3s").tag(3)
                        Text("5s").tag(5)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Portrait crop guide", isOn: $settings.cropGuide)
                    Toggle("Rule of thirds", isOn: $settings.thirds)
                } footer: {
                    Text("Framing guides — never recorded. The crop guide (landscape only) marks a centered 9:16 portrait crop; rule of thirds shows a 3×3 grid.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
