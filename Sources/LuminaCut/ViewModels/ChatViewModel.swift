import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isThinking = false
    @Published var useOfflineFallback = true
    @Published var kimiModel = "moonshot-v1-auto"

    private weak var editor: EditorViewModel?
    private let kimi = KimiVideoAIService.shared

    let suggestions = [
        "Split at playhead",
        "Slow motion 0.5x",
        "Apply cinematic look",
        "Add dissolve transition",
        "Add text \"My Story\"",
        "Set canvas to 9:16",
        "Warm up colors",
        "Mute this clip"
    ]

    init() {
        messages = [
            ChatMessage(
                role: .assistant,
                content: """
                Hi — I'm LuminaCut AI (Kimi). Import clips, then tell me what to do.

                Try: "split at playhead", "cinematic look", "slow motion", "add text Hello", "9:16 for Reels".
                """
            )
        ]
    }

    func configure(apiKey: String, editor: EditorViewModel) {
        self.editor = editor
        let model = kimiModel
        Task { await kimi.configure(apiKey: apiKey, model: model) }
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        isThinking = true
        Task { await process(text) }
    }

    func sendSuggestion(_ s: String) {
        inputText = s
        send()
    }

    private func process(_ prompt: String) async {
        guard let editor else { isThinking = false; return }

        do {
            let command: AIVideoCommand
            if await kimi.isConfigured {
                command = try await kimi.analyze(prompt: prompt, projectSummary: editor.projectSummaryForAI())
            } else if useOfflineFallback {
                command = kimi.offlineHeuristic(prompt: prompt)
            } else {
                throw KimiVideoAIService.AIError.notConfigured
            }

            editor.applyAICommand(command)
            messages.append(ChatMessage(role: .assistant, content: command.reply, appliedActions: command.actions.map(\.type)))
        } catch {
            if useOfflineFallback {
                let fallback = kimi.offlineHeuristic(prompt: prompt)
                editor.applyAICommand(fallback)
                messages.append(ChatMessage(
                    role: .assistant,
                    content: "\(fallback.reply)\n\n(\(error.localizedDescription))",
                    appliedActions: fallback.actions.map(\.type)
                ))
            } else {
                messages.append(ChatMessage(
                    role: .assistant,
                    content: "Couldn't reach Kimi: \(error.localizedDescription)\nAdd your API key in Settings."
                ))
            }
        }
        isThinking = false
    }

    func clear() {
        messages = [ChatMessage(role: .assistant, content: "Chat cleared. What should we edit next?")]
    }
}
