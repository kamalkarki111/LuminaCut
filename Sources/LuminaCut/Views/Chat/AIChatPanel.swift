import SwiftUI

struct AIChatPanel: View {
    @EnvironmentObject private var chat: ChatViewModel
    @EnvironmentObject private var editor: EditorViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CutTheme.accentGradient)
                        .frame(width: 30, height: 30)
                        .shadow(color: CutTheme.accent.opacity(0.4), radius: 8)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Assistant")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(CutTheme.textPrimary)
                    Text("Kimi · CapCut-style edits")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(CutTheme.accentViolet)
                }
                Spacer()
                Button { chat.clear() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(CutTheme.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(CutTheme.surfaceHover))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(CutTheme.surfaceElevated)

            Divider().overlay(CutTheme.border)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chat.messages) { msg in
                            ChatBubble(message: msg).id(msg.id)
                        }
                        if chat.isThinking {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Kimi is thinking…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(CutTheme.textTertiary)
                            }
                            .id("thinking")
                        }
                    }
                    .padding(12)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    withAnimation {
                        if chat.isThinking {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        } else if let last = chat.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chat.suggestions, id: \.self) { s in
                        Button { chat.sendSuggestion(s) } label: {
                            Text(s)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(CutTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(CutTheme.surfaceHover).overlay(Capsule().stroke(CutTheme.border, lineWidth: 1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            Divider().overlay(CutTheme.border)

            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Tell AI what to edit…", text: $chat.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .lineLimit(1...4)
                        .focused($focused)
                        .onSubmit { chat.send() }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(CutTheme.surfaceHover)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? CutTheme.accentPurple.opacity(0.5) : CutTheme.border, lineWidth: 1))
                        )

                    Button { chat.send() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                chat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isThinking
                                ? AnyShapeStyle(CutTheme.textTertiary)
                                : AnyShapeStyle(CutTheme.accentGradient)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(chat.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isThinking)
                    .keyboardShortcut(.return, modifiers: .command)
                }

                HStack {
                    Text("Playhead \(String(format: \"%.1fs\", editor.playback.currentTime))")
                        .font(.system(size: 9, design: .monospaced))
                    Spacer()
                    Text("⌘↵ send")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(CutTheme.textTertiary)
            }
            .padding(12)
        }
        .background(CutTheme.surface)
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 20) }
            if !isUser {
                Circle()
                    .fill(CutTheme.accentGradient)
                    .frame(width: 20, height: 20)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 8, weight: .bold)).foregroundStyle(.white))
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 12.5))
                    .foregroundStyle(isUser ? .white : CutTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isUser
                                  ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "5B8CFF"), Color(hex: "7C6AF5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                  : AnyShapeStyle(CutTheme.surfaceElevated))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isUser ? Color.clear : CutTheme.border, lineWidth: 1)
                            )
                    )
                if !message.appliedActions.isEmpty {
                    ForEach(message.appliedActions, id: \.self) { a in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundStyle(CutTheme.accentGreen)
                            Text(a).font(.system(size: 10)).foregroundStyle(CutTheme.textTertiary)
                        }
                    }
                }
            }
            if !isUser { Spacer(minLength: 12) }
        }
    }
}
