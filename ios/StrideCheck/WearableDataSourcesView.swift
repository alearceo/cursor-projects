import SwiftUI

/// Central screen (Option C): Apple Health status, Whoop / Oura connection, and **Use for run index** toggles.
struct WearableDataSourcesView: View {
    @EnvironmentObject private var whoopLink: WhoopLinkViewModel
    @AppStorage("stridecheck.includeWhoopInRunIndex") private var includeWhoop = false
    @AppStorage("stridecheck.includeOuraInRunIndex") private var includeOura = false

    @State private var healthSummary = "Checking Health access…"
    @State private var ouraDraft = ""
    @State private var ouraFooterNote: String?
    @State private var ouraConfigured = false

    var body: some View {
        List {
            Section {
                Text(healthSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Used whenever read access is granted. This is the baseline for the run index when third-party APIs are turned off below.")
            }

            Section {
                Toggle("Use for run index", isOn: $includeWhoop)
                    .disabled(!whoopLink.isConnected)
                Group {
                    if whoopLink.isConnected {
                        Text("Connected to Whoop.")
                    } else {
                        Text("Connect so StrideCheck can read recovery, strain, and sleep from Whoop’s API.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    if whoopLink.isConnected {
                        Button("Disconnect") {
                            whoopLink.disconnect()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            Task { await whoopLink.connect() }
                        } label: {
                            if whoopLink.isBusy {
                                ProgressView()
                            } else {
                                Text("Connect Whoop")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(whoopLink.isBusy)
                    }
                }
            } header: {
                Text("Whoop")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let err = whoopLink.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Requires `WhoopClientId` and `WhoopClientSecret` in your build configuration (see README).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Use for run index", isOn: $includeOura)
                    .disabled(!ouraConfigured)
                SecureField("Personal access token", text: $ouraDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save token to Keychain") {
                    saveOuraToken()
                }
                .disabled(ouraDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if ouraConfigured {
                    Button("Remove Oura token", role: .destructive) {
                        removeOuraToken()
                    }
                }
            } header: {
                Text("Oura")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let note = ouraFooterNote {
                        Text(note)
                            .font(.caption)
                    }
                    Text("Create a token at cloud.ouraring.com/personal-access-tokens. It is stored only in the Keychain on this device (Keychain overrides any build-time token).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Data sources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshHealthSummary()
        }
        .onAppear {
            whoopLink.refreshConnectionState()
            syncOuraConfigured()
        }
    }

    private func syncOuraConfigured() {
        ouraConfigured = StrideCheckSecrets.ouraPersonalAccessToken != nil
    }

    private func saveOuraToken() {
        let t = ouraDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        KeychainCredentialStore.set(t, for: .ouraPersonalAccessToken)
        ouraDraft = ""
        ouraConfigured = true
        includeOura = true
        ouraFooterNote = "Saved. Pull to refresh on Conditions to apply."
    }

    private func removeOuraToken() {
        KeychainCredentialStore.delete(.ouraPersonalAccessToken)
        ouraConfigured = StrideCheckSecrets.ouraPersonalAccessToken != nil
        includeOura = false
        ouraFooterNote = "Keychain token removed. A build-time token in Info.plist may still apply until cleared."
    }

    private func refreshHealthSummary() async {
        healthSummary = await HealthKitReadinessFetcher.authorizationSummary()
    }
}
