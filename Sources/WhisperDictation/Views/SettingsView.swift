import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            HotkeySettingsView()
                .tabItem { Label("Hotkey", systemImage: "keyboard") }

            TranscriptionSettingsView()
                .tabItem { Label("Transkription", systemImage: "waveform") }

            VocabularySettingsView()
                .tabItem { Label("Wörterbuch", systemImage: "character.book.closed") }

            LLMPromptsSettingsView()
                .tabItem { Label("LLM Prompts", systemImage: "sparkles") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .padding()
    }
}
