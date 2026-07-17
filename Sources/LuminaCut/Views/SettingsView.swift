import SwiftUI

struct SettingsView: View {
    @AppStorage("kimiAPIKey") private var kimiAPIKey = ""
    @AppStorage("kimiModel") private var kimiModel = "moonshot-v1-auto"
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("useOfflineFallback") private var useOfflineFallback = true

    var body: some View {
        TabView {
            Form {
                Section {
                    SecureField("Moonshot / Kimi API Key", text: $kimiAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Get a key at platform.kimi.ai — stored only on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Model", selection: $kimiModel) {
                        Text("Auto").tag("moonshot-v1-auto")
                        Text("moonshot-v1-8k").tag("moonshot-v1-8k")
                        Text("moonshot-v1-32k").tag("moonshot-v1-32k")
                        Text("moonshot-v1-128k").tag("moonshot-v1-128k")
                        Text("kimi-k2.5").tag("kimi-k2.5")
                    }
                    Toggle("Offline fallback when API unavailable", isOn: $useOfflineFallback)
                } header: {
                    Text("Kimi AI")
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    LabeledContent("App", value: "LuminaCut")
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Engine", value: "AVFoundation")
                    LabeledContent("AI", value: "Moonshot Kimi")
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
            .padding()
            .frame(width: 480, height: 380)
            .tabItem { Label("General", systemImage: "gearshape") }
        }
    }
}
