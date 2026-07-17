import Foundation

actor KimiVideoAIService {
    static let shared = KimiVideoAIService()

    private var apiKey: String = ""
    private let baseURL = URL(string: "https://api.moonshot.ai/v1/chat/completions")!
    private var preferredModel: String = "moonshot-v1-auto"

    func configure(apiKey: String, model: String? = nil) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if let model, !model.isEmpty { preferredModel = model }
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    static let systemPrompt = """
    You are LuminaCut AI, an expert video editor assistant inside a CapCut/VN-class macOS video editor.
    Users describe timeline edits in natural language. Return STRICT JSON only (no markdown fences).

    Schema:
    {
      "reply": "Short friendly explanation (1-3 sentences)",
      "open_tool": "select|cut|trim|speed|volume|transform|color|looks|transitions|effects|text|audio|canvas|export|null",
      "actions": [
        {
          "type": "ACTION_TYPE",
          "clip_id": "selected|first|null",
          "track": "video|overlay|text|audio|music|null",
          "value": 0.0,
          "string_value": "optional",
          "values": { "brightness": 0.1 },
          "string_values": { "look_id": "cinematic", "transition": "crossDissolve", "text": "Hello" }
        }
      ]
    }

    ACTION_TYPE values:
    - split_at_playhead
    - delete_selected
    - set_speed (value: 0.25...4)
    - set_volume (value: 0...1)
    - set_opacity (value: 0...1)
    - set_scale (value: 0.1...3)
    - mute_toggle
    - apply_color (values: brightness, contrast, saturation, warmth, vignette, fade, blackAndWhite 0/1)
    - apply_look (string_values.look_id: cinematic|vivid|noir|warm_film|cool|vintage|drama|pastel|teal_orange|matte|bright|moody)
    - set_transition_out (string_values.transition: none|crossDissolve|fadeToBlack|fadeToWhite|wipeLeft|wipeRight|slideUp|zoomIn|flash, value=duration)
    - set_transition_in (same)
    - add_text (string_values.text, value=duration seconds)
    - set_canvas (string_values.aspect: landscape16x9|portrait9x16|square1x1|landscape4x3|portrait4x5|cinematic21x9)
    - duplicate_clip
    - reverse_hint (reply only — reverse needs re-import)
    - trim_start (value: seconds to trim from start)
    - trim_end (value: seconds to trim from end)
    - fade_audio (values: fadeIn, fadeOut)
    - reset_color
    - zoom_to_fill (set scale for cover)
    - export_hint (reply with export guidance)

    Rules:
    - Prefer operating on "selected" clip; if none, use "first" on main video track.
    - Only include actions you want executed.
    - Be tasteful. Multiple actions allowed in one response.
    - Raw JSON only.
    """

    struct APIResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
        struct Err: Decodable { let message: String? }
        let error: Err?
    }

    enum AIError: LocalizedError {
        case notConfigured, invalidResponse, api(String), decode(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Add your Kimi API key in Settings."
            case .invalidResponse: return "Invalid response from Kimi."
            case .api(let m): return m
            case .decode(let m): return "Parse error: \(m)"
            }
        }
    }

    func analyze(prompt: String, projectSummary: String) async throws -> AIVideoCommand {
        guard isConfigured else { throw AIError.notConfigured }

        let messages: [[String: String]] = [
            ["role": "system", "content": Self.systemPrompt],
            ["role": "system", "content": projectSummary],
            ["role": "user", "content": prompt]
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": preferredModel,
            "messages": messages,
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        if let err = decoded.error?.message { throw AIError.api(err) }
        if http.statusCode >= 400 {
            throw AIError.api(String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)")
        }
        guard let content = decoded.choices.first?.message.content else { throw AIError.invalidResponse }
        return try parse(content)
    }

    nonisolated func offlineHeuristic(prompt: String) -> AIVideoCommand {
        let l = prompt.lowercased()
        var actions: [AIVideoCommand.AIAction] = []
        var tool: String? = nil
        var reply = "Applied offline video edits."

        if l.contains("split") || l.contains("cut here") || l.contains("cut at") {
            actions.append(.init(type: "split_at_playhead"))
            tool = "cut"
            reply = "Split the selected clip at the playhead."
        }
        if l.contains("delete") || l.contains("remove clip") {
            actions.append(.init(type: "delete_selected"))
            reply = "Deleted the selected clip."
        }
        if l.contains("slow") || l.contains("slow motion") {
            actions.append(.init(type: "set_speed", value: 0.5))
            tool = "speed"
            reply = "Set speed to 0.5× slow motion."
        } else if l.contains("fast") || l.contains("speed up") || l.contains("2x") {
            actions.append(.init(type: "set_speed", value: 2.0))
            tool = "speed"
            reply = "Set speed to 2×."
        }
        if l.contains("mute") {
            actions.append(.init(type: "mute_toggle"))
            tool = "volume"
            reply = "Toggled mute on the clip."
        }
        if l.contains("quiet") || l.contains("lower volume") || l.contains("softer audio") {
            actions.append(.init(type: "set_volume", value: 0.3))
            tool = "volume"
        }
        if l.contains("louder") || l.contains("boost audio") {
            actions.append(.init(type: "set_volume", value: 1.0))
            tool = "volume"
        }
        if l.contains("cinematic") {
            actions.append(.init(type: "apply_look", stringValues: ["look_id": "cinematic"]))
            tool = "looks"
            reply = "Applied cinematic look."
        }
        if l.contains("noir") || l.contains("black and white") || l.contains("b&w") {
            actions.append(.init(type: "apply_look", stringValues: ["look_id": "noir"]))
            tool = "looks"
            reply = "Applied noir black & white look."
        }
        if l.contains("vivid") || l.contains("colorful") {
            actions.append(.init(type: "apply_look", stringValues: ["look_id": "vivid"]))
            tool = "looks"
        }
        if l.contains("vintage") || l.contains("retro") {
            actions.append(.init(type: "apply_look", stringValues: ["look_id": "vintage"]))
            tool = "looks"
        }
        if l.contains("warm") {
            actions.append(.init(type: "apply_color", values: ["warmth": 0.35, "brightness": 0.05]))
            tool = "color"
            reply = "Warmed up the clip colors."
        }
        if l.contains("cool") {
            actions.append(.init(type: "apply_color", values: ["warmth": -0.3]))
            tool = "color"
        }
        if l.contains("bright") {
            actions.append(.init(type: "apply_color", values: ["brightness": 0.2]))
            tool = "color"
        }
        if l.contains("contrast") {
            actions.append(.init(type: "apply_color", values: ["contrast": 0.25]))
            tool = "color"
        }
        if l.contains("vignette") {
            actions.append(.init(type: "apply_color", values: ["vignette": 0.4]))
            tool = "color"
        }
        if l.contains("dissolve") || l.contains("transition") {
            actions.append(.init(type: "set_transition_out", value: 0.5, stringValues: ["transition": "crossDissolve"]))
            tool = "transitions"
            reply = "Added cross-dissolve transition out."
        }
        if l.contains("fade to black") || l.contains("fade black") {
            actions.append(.init(type: "set_transition_out", value: 0.6, stringValues: ["transition": "fadeToBlack"]))
            tool = "transitions"
        }
        if l.contains("text") || l.contains("title") || l.contains("caption") {
            let text = extractQuoted(l) ?? "Your Title"
            actions.append(.init(type: "add_text", value: 3, stringValues: ["text": text]))
            tool = "text"
            reply = "Added text clip: \(text)"
        }
        if l.contains("9:16") || l.contains("reel") || l.contains("tiktok") || l.contains("shorts") {
            actions.append(.init(type: "set_canvas", stringValues: ["aspect": "portrait9x16"]))
            tool = "canvas"
            reply = "Set canvas to 9:16 vertical."
        }
        if l.contains("16:9") || l.contains("youtube") || l.contains("landscape") {
            actions.append(.init(type: "set_canvas", stringValues: ["aspect": "landscape16x9"]))
            tool = "canvas"
        }
        if l.contains("square") || l.contains("1:1") {
            actions.append(.init(type: "set_canvas", stringValues: ["aspect": "square1x1"]))
            tool = "canvas"
        }
        if l.contains("duplicate") {
            actions.append(.init(type: "duplicate_clip"))
            reply = "Duplicated the selected clip."
        }
        if l.contains("reset color") || l.contains("reset grade") {
            actions.append(.init(type: "reset_color"))
            tool = "color"
        }
        if l.contains("zoom") || l.contains("fill") {
            actions.append(.init(type: "zoom_to_fill"))
            tool = "transform"
        }
        if l.contains("export") {
            actions.append(.init(type: "export_hint"))
            tool = "export"
            reply = "Use Export in the toolbar or Project → Export to save MP4. Choose 1080p High for best quality."
        }

        if actions.isEmpty {
            reply = """
            Offline mode understood "\(prompt)". Try: "split at playhead", "slow motion", \
            "cinematic look", "add text Hello", "9:16 canvas", "add dissolve". \
            Add a Kimi API key in Settings for richer understanding.
            """
        } else if reply == "Applied offline video edits." {
            reply = "Offline AI: " + actions.map(\.type).joined(separator: ", ")
        }

        return AIVideoCommand(reply: reply, actions: actions, openTool: tool)
    }

    private nonisolated func extractQuoted(_ s: String) -> String? {
        if let r = s.range(of: #""([^"]+)""#, options: .regularExpression) {
            return String(s[r]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        if let r = s.range(of: #"'([^']+)'"#, options: .regularExpression) {
            return String(s[r]).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
        }
        return nil
    }

    private func parse(_ content: String) throws -> AIVideoCommand {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") {
            text = String(text[s...e])
        }
        guard let data = text.data(using: .utf8) else { throw AIError.decode("empty") }
        do {
            return try JSONDecoder().decode(AIVideoCommand.self, from: data)
        } catch {
            throw AIError.decode(error.localizedDescription)
        }
    }
}
