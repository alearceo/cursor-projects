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
    @State private var whoopClientIdDraft = ""
    @State private var whoopSecretDraft = ""
    @State private var whoopCredentialsConfigured = false
    @State private var whoopFooterNote: String?

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
                TextField("Client ID", text: $whoopClientIdDraft)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Client secret", text: $whoopSecretDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save credentials to Keychain") {
                    saveWhoopCredentials()
                }
                .disabled(
                    whoopClientIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || whoopSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                if KeychainCredentialStore.string(for: .whoopOAuthClientId) != nil,
                   KeychainCredentialStore.string(for: .whoopOAuthClientSecret) != nil {
                    Button("Remove Keychain credentials", role: .destructive) {
                        removeWhoopKeychainCredentials()
                    }
                }
                Group {
                    if whoopLink.isConnected {
                        Text("Connected to Whoop.")
                    } else if whoopCredentialsConfigured {
                        Text("Credentials are set. Tap Connect to sign in with Whoop.")
                    } else {
                        Text("Add your app’s Client ID and secret from developer.whoop.com (or supply them via build settings), then connect.")
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
                        .disabled(whoopLink.isBusy || !whoopCredentialsConfigured)
                    }
                }
            } header: {
                Text("Whoop")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let note = whoopFooterNote {
                        Text(note)
                            .font(.caption)
                    }
                    if let err = whoopLink.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Register the redirect URI in the Whoop developer console: \(StrideCheckSecrets.whoopRedirectURI). Keychain values override WhoopClientId / WhoopClientSecret from Info.plist when both are saved.")
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

            Section {
                NavigationLink {
                    MapDataSourcesView()
                } label: {
                    Label("Map data sources (Strava)", systemImage: "map")
                }
            } footer: {
                Text("Strava sign-in, API keys, and whether routes draw on the Route & 511 map.")
            }
        }
        .navigationTitle("Data sources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshHealthSummary()
        }
        .onChange(of: includeWhoop) { _, _ in
            ConditionsSnapshotReload.request()
        }
        .onChange(of: includeOura) { _, _ in
            ConditionsSnapshotReload.request()
        }
        .onAppear {
            whoopLink.refreshConnectionState()
            syncOuraConfigured()
            syncWhoopCredentialsConfigured()
        }
    }

    private func syncWhoopCredentialsConfigured() {
        whoopCredentialsConfigured = StrideCheckSecrets.whoopClientId != nil
            && StrideCheckSecrets.whoopClientSecret != nil
    }

    private func saveWhoopCredentials() {
        let id = whoopClientIdDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = whoopSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return }
        KeychainCredentialStore.set(id, for: .whoopOAuthClientId)
        KeychainCredentialStore.set(secret, for: .whoopOAuthClientSecret)
        whoopClientIdDraft = ""
        whoopSecretDraft = ""
        syncWhoopCredentialsConfigured()
        whoopFooterNote = "Saved to Keychain. Tap Connect Whoop to finish sign-in."
    }

    private func removeWhoopKeychainCredentials() {
        KeychainCredentialStore.delete(.whoopOAuthClientId)
        KeychainCredentialStore.delete(.whoopOAuthClientSecret)
        whoopLink.disconnect()
        syncWhoopCredentialsConfigured()
        whoopFooterNote = "Keychain credentials removed. Values from Info.plist still apply if your build defines them."
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
        ouraFooterNote = "Saved. Run index refreshes when location or zip is available."
        ConditionsSnapshotReload.request()
    }

    private func removeOuraToken() {
        KeychainCredentialStore.delete(.ouraPersonalAccessToken)
        ouraConfigured = StrideCheckSecrets.ouraPersonalAccessToken != nil
        includeOura = false
        ouraFooterNote = "Keychain token removed. A build-time token in Info.plist may still apply until cleared."
        ConditionsSnapshotReload.request()
    }

    private func refreshHealthSummary() async {
        healthSummary = await HealthKitReadinessFetcher.authorizationSummary()
    }
}
