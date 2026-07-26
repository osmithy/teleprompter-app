//
//  EditorView.swift
//  Teleprompter
//
//  Script editor — paste/type a script (persists via Settings), open Settings, or start
//  the camera.
//

import SwiftUI

struct EditorView: View {
    @ObservedObject var settings: Settings
    var onStart: () -> Void
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 0) {
                    Text("Tele").foregroundStyle(.white)
                    Text("prompter").foregroundStyle(.red)
                }
                .font(.system(size: 22, weight: .semibold))
                Spacer()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            TextEditor(text: $settings.scriptText)
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))

            Button(action: onStart) {
                Label("Start camera", systemImage: "video.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.red, in: RoundedRectangle(cornerRadius: 14))
            }

            Text("Landscape (camera on the left → position **Left**) or portrait (camera at the top → position **Top**) both work, so the words scroll next to the lens. The text is never in the recording.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(settings: settings)
        }
    }
}
