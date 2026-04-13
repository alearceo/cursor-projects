import SwiftUI
import UIKit

/// Conditions tab: location, data sources link, run index snapshot, and related cards.
struct ConditionsTabView: View {
    @ObservedObject var vm: ConditionsViewModel
    @ObservedObject var locationService: LocationService
    @AppStorage("stridecheck.notifyRunWindows") private var notifyStrongWindows = false

    var body: some View {
        ZStack {
            StrideTelemetryBackground()
            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
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
                                .tint(AppTheme.accent)
                                .foregroundStyle(Color.strideInkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
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
                .background(Color.clear)
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .top) {
                    TopEdgeFrostFade(style: .editorialScroll)
                        .ignoresSafeArea(edges: .top)
                }
            }
        }
    }

    // MARK: Brand block — data-panel header style

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STRIDECHECK")
                    .font(StrideFont.heroTitle)
                    .foregroundStyle(Color.strideInk)
                    .tracking(1.5)
                Text("Road conditions for city runners")
                    .font(StrideFont.brandSubtitle)
                    .foregroundStyle(Color.strideInkSecondary)
            }
            // Horizontal amber rule — telemetry section separator
            Rectangle()
                .fill(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location first, zip optional")
                .font(StrideFont.sectionTitle)
                .foregroundStyle(Color.strideInk)
            Text("Uses your iPhone location first. Enter a zip only if you need a manual fallback.")
                .font(.subheadline)
                .foregroundStyle(Color.strideInkSecondary)
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .strideCard(strokeOpacity: 0.12)
    }

    private var locationControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.tight) {
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
            .tint(AppTheme.accent)
            .disabled(vm.isLoading)

            HStack(spacing: 10) {
                TextField("Zip fallback (optional)", text: $vm.zipInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Load") {
                    Task { await vm.loadForZip() }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
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
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data sources for run index")
                        .font(StrideFont.cardTitle)
                        .foregroundStyle(Color.strideInk)
                    Text("Apple Health, Whoop, Oura — choose what affects your score")
                        .font(.caption)
                        .foregroundStyle(Color.strideInkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.strideInk.opacity(0.35))
            }
            .padding(AppTheme.Spacing.cardPadding - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .strideCard(strokeOpacity: 0.12)
        }
        .buttonStyle(.plain)
    }

    private var notificationToggle: some View {
        Toggle(isOn: $notifyStrongWindows) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strong run alerts")
                    .font(StrideFont.cardTitle)
                    .foregroundStyle(Color.strideInk)
                Text("At most one local notification per ~12h when the run index is high.")
                    .font(.caption)
                    .foregroundStyle(Color.strideInkSecondary)
            }
        }
        .tint(AppTheme.accent)
        .padding(AppTheme.Spacing.cardPadding - 2)
        .strideCard(strokeOpacity: 0.12)
        .onChange(of: notifyStrongWindows) { _, on in
            if on {
                Task { _ = await RunWindowNotifier.requestAuthorizationIfNeeded() }
            }
        }
    }

    // MARK: Banners — left-bar / log-terminal style

    private func offlineBanner(_ date: Date) -> some View {
        StrideLeftBarBanner(barColor: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Offline snapshot", systemImage: "wifi.slash")
                    .font(StrideFont.cardTitle)
                    .foregroundStyle(Color.strideInk)
                Text("Showing cached data from \(SnapshotCache.formattedSavedAt(date)). Pull to refresh when you are back online.")
                    .font(.caption)
                    .foregroundStyle(Color.strideInkSecondary)
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        StrideLeftBarBanner(barColor: .red) {
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.red)
        }
    }

    private func runIndexDataSourcesHintBanner() -> some View {
        StrideLeftBarBanner(barColor: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Run index needs a data source", systemImage: "heart.slash")
                        .font(StrideFont.cardTitle)
                        .foregroundStyle(Color.strideInk)
                    Text("Apple Health isn't contributing (access off, denied, or no HRV/sleep/activity yet), and Whoop/Oura aren't turned on for the run index. Use Data sources to allow Health or enable a wearable.")
                        .font(.caption)
                        .foregroundStyle(Color.strideInkSecondary)
                }
                NavigationLink {
                    WearableDataSourcesView()
                } label: {
                    Text("Open Data sources")
                        .font(StrideFont.cardTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
    }

    // MARK: Snapshot

    private func snapshotView(_ snap: ConditionsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.placeName)
                    .font(.system(.title2, design: .default).weight(.bold))
                    .foregroundStyle(Color.strideInk)
                Text(String(format: "%.4f, %.4f", snap.latitude, snap.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.strideInkSecondary)
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
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(tier.accentColor.opacity(0.55), lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(tier.accentColor.opacity(0.12))
                        .frame(width: 70, height: 70)
                    Text("\(score)")
                        .font(StrideFont.scoreLarge(30))
                        .foregroundStyle(Color.strideInk)
                        .contentTransition(.numericText())
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.78), value: score)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Run Index")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.strideInkSecondary)
                        Text(tier.label.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tier.accentColor.opacity(0.20))
                            .foregroundStyle(tier.accentColor)
                            .clipShape(Capsule())
                    }
                    Text(verdict)
                        .font(StrideFont.sectionTitle)
                        .foregroundStyle(Color.strideInk)
                }
            }

            ForEach(bullets.prefix(4), id: \.self) { bullet in
                Label(bullet, systemImage: "figure.run")
                    .font(.footnote)
                    .foregroundStyle(Color.strideInkSecondary)
            }
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .strideCard(strokeOpacity: 0.10)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous)
                .strokeBorder(tier.accentColor.opacity(0.55), lineWidth: 2)
        )
    }

    private func awarenessCard(score: Int, verdict: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(AppTheme.accent)
                Text("Route awareness")
                    .font(StrideFont.cardTitle)
                    .foregroundStyle(Color.strideInk)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score)")
                    .font(StrideFont.scoreLarge(34))
                    .foregroundStyle(Color.strideInk)
                Text("/ 100")
                    .font(.caption.design(.monospaced))
                    .foregroundStyle(Color.strideInkSecondary)
                Spacer()
            }
            Text(verdict)
                .font(.subheadline)
                .foregroundStyle(Color.strideInk)
            ForEach(bullets.prefix(4), id: \.self) { bullet in
                Text("• \(bullet)")
                    .font(.footnote)
                    .foregroundStyle(Color.strideInkSecondary)
            }
            Text("Combines daylight, weather, air, NWS alerts, and optional third-party crime-incident feeds (incomplete, delayed). Not a substitute for judgment, trusted people, or official safety resources.")
                .font(.caption2)
                .foregroundStyle(Color.strideInkSecondary.opacity(0.85))
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.strideRouteAwarenessTint)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Corner.card, style: .continuous)
                .strokeBorder(Color.strideInk.opacity(0.14), lineWidth: 1)
        )
    }

    private func rowsCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.strideInkSecondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).foregroundStyle(Color.strideInkSecondary)
                    Spacer()
                    Text(row.1)
                        .font(StrideFont.dataValue)
                        .foregroundStyle(Color.strideInk)
                }
                .font(.subheadline)
            }
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .strideCard(strokeOpacity: 0.12)
    }

    private func hourlyStrip(_ items: [HourlyDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next 12 Hours")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.strideInkSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            Text(item.timeLabel)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Color.strideInkSecondary)
                            Text(item.icon).font(.title3)
                            Text(item.rainChanceLabel)
                                .font(.caption2)
                                .foregroundStyle(Color.strideInkSecondary)
                        }
                        .padding(8)
                        .background(Color.strideSurfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.chip, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Corner.chip, style: .continuous)
                                .strokeBorder(Color.strideInk.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .strideCard(strokeOpacity: 0.12)
    }

    private func alertsSection(_ alerts: [NWSAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Alerts")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.strideInkSecondary)

            if alerts.isEmpty {
                Text("No active NWS alerts right now.")
                    .font(.footnote)
                    .foregroundStyle(Color.strideInkSecondary)
            } else {
                ForEach(alerts) { alert in
                    StrideLeftBarBanner(barColor: AppTheme.accent) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.strideInk)
                            if let description = alert.description, !description.isEmpty {
                                Text(description)
                                    .font(.footnote)
                                    .foregroundStyle(Color.strideInkSecondary)
                                    .lineLimit(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .strideCard(strokeOpacity: 0.12)
    }
}
