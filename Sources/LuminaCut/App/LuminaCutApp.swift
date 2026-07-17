import SwiftUI

@main
struct LuminaCutApp: App {
    @StateObject private var editor = EditorViewModel()
    @StateObject private var chat = ChatViewModel()
    @AppStorage("kimiAPIKey") private var kimiAPIKey = ""
    @AppStorage("kimiModel") private var kimiModel = "moonshot-v1-auto"
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("useOfflineFallback") private var useOfflineFallback = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(editor)
                .environmentObject(chat)
                .preferredColorScheme(appearance == "light" ? .light : .dark)
                .frame(minWidth: 1280, minHeight: 800)
                .onAppear {
                    chat.useOfflineFallback = useOfflineFallback
                    chat.kimiModel = kimiModel
                    chat.configure(apiKey: kimiAPIKey, editor: editor)
                }
                .onChange(of: kimiAPIKey) { _, v in chat.configure(apiKey: v, editor: editor) }
                .onChange(of: kimiModel) { _, v in
                    chat.kimiModel = v
                    chat.configure(apiKey: kimiAPIKey, editor: editor)
                }
                .onChange(of: useOfflineFallback) { _, v in chat.useOfflineFallback = v }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1500, height: 960)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") { editor.newProject() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Import Media…") { editor.importMedia() }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Export…") { editor.export() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .pasteboard) {
                Button("Undo") { editor.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { editor.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                Divider()
                Button("Split at Playhead") { editor.splitAtPlayhead() }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Delete Clip") { editor.deleteSelected() }
                    .keyboardShortcut(.delete, modifiers: [])
                Button("Duplicate Clip") { editor.duplicateSelected() }
                    .keyboardShortcut("d", modifiers: .command)
            }
            CommandMenu("Playback") {
                Button(editor.playback.isPlaying ? "Pause" : "Play") { editor.playback.toggle() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("Frame Back") { editor.playback.step(by: -1.0 / 30.0) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Frame Forward") { editor.playback.step(by: 1.0 / 30.0) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(chat)
        }
    }
}
