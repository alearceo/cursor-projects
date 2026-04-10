import SwiftUI
import UIKit

/// Conditions tab: location, data sources link, run index snapshot, and related cards.
struct ConditionsTabView: View {
    @ObservedObject var vm: ConditionsViewModel
    @ObservedObject var locationService: LocationService
    @AppStorage("stridecheck.notifyRunWindows") private var notifyStrongWindows = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    brandBlock
                    headerCard
                    dataSourcesLinkCard
                    locationControls
                    notificationToggle

                    if let cached = vm.snapshot?.cachedAt {
                        offlineBanner(cached)
                    }
                    if let error = vm.errorMessage ?? locationService.lastError {
                        errorBanner(error)
                    }

                    if let snapshot = vm.snapshot {
                        snapshotView(snapshot)
                    } else if vm.isLoading {
                        ProgressView("Loading runner conditions...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                if let c = locationService.coordinate {
                    await vm.loadForCurrentLocation(c)
                } else if vm.zipInput.count == 5 {
                    await vm.loadForZip()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                TopEdgeFrostFade(style: .groupedScroll)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("StrideCheck")
                .font(.largeTitle.weight(.bold))
            Text("Road conditions for city runners")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Location first, zip optional")
                .font(.headline)
            Text("Uses your iPhone location first. Enter a zip only if you need a manual fallback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var locationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                locationService.requestAccessAndLocation()
                if let c = locationService.coordinate {
                    Task { await vm.loadForCurrentLocation(c) }
                }
            } label: {
                Label("Use Current Location", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)

            HStack(spacing: 10) {
                TextField("Zip fallback (optional)", text: $vm.zipInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Load") {
                    Task { await vm.loadForZip() }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading || vm.zipInput.count < 5)
            }
        }
    }

    private var dataSourcesLinkCard: some View {
        NavigationLink {
            WearableDataSourcesView()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data sources for run index")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Apple Health, Whoop, Oura — choose what affects your score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var notificationToggle: some View {
        Toggle(isOn: $notifyStrongWindows) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strong run alerts")
                    .font(.subheadline.weight(.semibold))
                Text("At most one local notification per ~12h when the run index is high.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: notifyStrongWindows) { _, on in
            if on {
                Task { _ = await RunWindowNotifier.requestAuthorizationIfNeeded() }
            }
        }
    }

    private func offlineBanner(_ date: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline snapshot")
                    .font(.subheadline.weight(.semibold))
                Text("Showing cached data from \(SnapshotCache.formattedSavedAt(date)). Pull to refresh when you are back online.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func runIndexDataSourcesHintBanner() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.slash")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run index needs a data source")
                        .font(.subheadline.weight(.semibold))
                    Text("Apple Health isn’t contributing (access off, denied, or no HRV/sleep/activity yet), and Whoop/Oura aren’t turned on for the run index. Use Data sources to allow Health or enable a wearable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                WearableDataSourcesView()
            } label: {
                Text("Open Data sources")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func snapshotView(_ snap: ConditionsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(snap.placeName).font(.title3).bold()
                Text(String(format: "%.4f, %.4f", snap.latitude, snap.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if snap.showRunIndexDataSourcesHint {
                runIndexDataSourcesHintBanner()
            }

            runIndexCard(score: snap.score, verdict: snap.verdict, bullets: snap.bullets)
            rowsCard(title: "Wearables & readiness", rows: snap.wearableRows)
            awarenessCard(score: snap.awarenessScore, verdict: snap.awarenessVerdict, bullets: snap.awarenessBullets)

            rowsCard(title: "Right Now", rows: snap.currentRows)
            rowsCard(title: "Air & Comfort", rows: snap.airRows)
            hourlyStrip(snap.hourly)
            alertsSection(snap.alerts)
        }
    }

    private func runIndexCard(score: Int, verdict: String, bullets: [String]) -> some View {
        let tier = RunIndexTier(score: score)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: tier.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Run Index")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tier.label.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tier.accentColor.opacity(0.22))
                            .foregroundStyle(tier.accentColor)
                            .clipShape(Capsule())
                    }
                    Text(verdict)
                        .font(.headline)
                }
            }

            ForEach(bullets.prefix(4), id: \.self) { bullet in
                Label(bullet, systemImage: "figure.run")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tier.accentColor.opacity(0.45), lineWidth: 2)
        )
    }

    private func awarenessCard(score: Int, verdict: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.indigo)
                Text("Route awareness")
                    .font(.subheadline.weight(.semibold))
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(verdict)
                .font(.subheadline)
            ForEach(bullets.prefix(4), id: \.self) { bullet in
                Text("• \(bullet)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Combines daylight, weather, air, NWS alerts, and optional third-party crime-incident feeds (incomplete, delayed). Not a substitute for judgment, trusted people, or official safety resources.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rowsCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1).bold()
                }
                .font(.subheadline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func hourlyStrip(_ items: [HourlyDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next 12 Hours")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            Text(item.timeLabel).font(.caption2.monospacedDigit())
                            Text(item.icon).font(.title3)
                            Text(item.rainChanceLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func alertsSection(_ alerts: [NWSAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Alerts")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            if alerts.isEmpty {
                Text("No active NWS alerts right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.headline).bold()
                        if let description = alert.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
