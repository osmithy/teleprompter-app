//
//  ContentView.swift
//  Teleprompter
//
//  Root view — owns the shared Settings and switches between the script editor and the
//  camera/prompter screen.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var settings = Settings()
    @State private var showingPrompter = false

    var body: some View {
        Group {
            if showingPrompter {
                PrompterView(settings: settings, onBack: { showingPrompter = false })
            } else {
                EditorView(settings: settings, onStart: { showingPrompter = true })
            }
        }
        .preferredColorScheme(.dark)
    }
}
