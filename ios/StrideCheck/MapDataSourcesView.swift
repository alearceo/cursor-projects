import SwiftUI

/// Map-only data sources: Strava OAuth and opt-in route polylines on the Route & 511 tab.
struct MapDataSourcesView: View {
    @EnvironmentObject private var stravaLink: StravaLinkViewModel
    @AppStorage(StravaMapOverlayPreferences.showRoutesOnMapKey) private var showStravaRoutesOnMap = false

    @State private var stravaClientIdDraft = ""
    @State private var stravaSecretDraft = ""
    @State private var stravaCredentialsConfigured = false
    @State private var stravaFooterNote: String?

    var body: some View {
        List {
            Section {
                Toggle("Show Strava routes on map", isOn: $showStravaRoutesOnMap)
                Text("When off, StrideCheck does not load activity polylines for the map. Turn on after you connect Strava to see routes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Map overlay")
            }

            Section {
                TextField("Client ID", text: $stravaClientIdDraft)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Client secret", text: $stravaSecretDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save credentials to Keychain") {
                    saveStravaCredentials()
                }
                .disabled(
                    stravaClientIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || stravaSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                if KeychainCredentialStore.string(for: .stravaOAuthClientId) != nil,
                   KeychainCredentialStore.string(for: .stravaOAuthClientSecret) != nil {
                    Button("Remove Keychain credentials", role: .destructive) {
                        removeStravaKeychainCredentials()
                    }
                }
                Group {
                    if stravaLink.isConnected {
                        Text("Signed in to Strava.")
                    } else if stravaCredentialsConfigured {
                        Text("Credentials are set. Tap Connect Strava to sign in.")
                    } else {
                        Text("Create a Strava API application and enter its Client ID and secret here (or use build-time keys in Info.plist).")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    if stravaLink.isConnected {
                        Button("Disconnect") {
                            stravaLink.disconnect()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            Task { await stravaLink.connect() }
                        } label: {
                            if stravaLink.isBusy {
                                ProgressView()
                            } else {
                                Text("Connect Strava")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(stravaLink.isBusy || !stravaCredentialsConfigured)
                    }
                }
                if stravaLink.isConnected, showStravaRoutesOnMap {
                    Button("Refresh routes on map") {
                        stravaLink.requestMapDataRefresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            } header: {
                Text("Strava")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let note = stravaFooterNote {
                        Text(note)
                            .font(.caption)
                    }
                    if let err = stravaLink.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Register this redirect URI in your Strava application: \(StrideCheckSecrets.stravaRedirectURI). Keychain values override StravaClientId / StravaClientSecret from Info.plist when both are saved.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Map data sources")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            stravaLink.refreshConnectionState()
            syncStravaCredentialsConfigured()
        }
    }

    private func syncStravaCredentialsConfigured() {
        stravaCredentialsConfigured = StrideCheckSecrets.stravaClientId != nil
            && StrideCheckSecrets.stravaClientSecret != nil
    }

    private func saveStravaCredentials() {
        let id = stravaClientIdDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = stravaSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return }
        KeychainCredentialStore.set(id, for: .stravaOAuthClientId)
        KeychainCredentialStore.set(secret, for: .stravaOAuthClientSecret)
        stravaClientIdDraft = ""
        stravaSecretDraft = ""
        syncStravaCredentialsConfigured()
        stravaFooterNote = "Saved to Keychain. Connect Strava when ready."
    }

    private func removeStravaKeychainCredentials() {
        KeychainCredentialStore.delete(.stravaOAuthClientId)
        KeychainCredentialStore.delete(.stravaOAuthClientSecret)
        stravaLink.disconnect()
        showStravaRoutesOnMap = false
        syncStravaCredentialsConfigured()
        stravaFooterNote = "Keychain credentials removed. Values from Info.plist still apply if your build defines them."
    }
}
