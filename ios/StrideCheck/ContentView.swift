import CoreLocation
import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var vm = ConditionsViewModel()
    @StateObject private var locationService = LocationService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    locationControls
                    if let error = vm.errorMessage ?? locationService.lastError {
                        errorBanner(error)
                    }
                    if let snapshot = vm.snapshot {
                        snapshotView(snapshot)
                    } else if vm.isLoading {
                        ProgressView("Loading runner conditions...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("StrideCheck")
        }
        .task {
            locationService.requestAccessAndLocation()
        }
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            Task { await vm.loadForCurrentLocation(coordinate) }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Road conditions for city runners")
                .font(.headline)
            Text("Uses your iPhone location first. Zip code is optional fallback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var locationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                locationService.requestAccessAndLocation()
            } label: {
                Label("Use Current Location", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)

            HStack {
                TextField("Zip fallback (optional)", text: $vm.zipInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Load Zip") {
                    Task { await vm.loadForZip() }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading || vm.zipInput.count < 5)
            }
        }
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

    private func snapshotView(_ snap: ConditionsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(snap.placeName).font(.title3).bold()
                Text(String(format: "%.4f, %.4f", snap.latitude, snap.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            scoreCard(score: snap.score, verdict: snap.verdict, bullets: snap.bullets)

            rowsCard(title: "Right Now", rows: snap.currentRows)
            rowsCard(title: "Air & Comfort", rows: snap.airRows)
            hourlyStrip(snap.hourly)
            alertsSection(snap.alerts)
        }
    }

    private func scoreCard(score: Int, verdict: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(score)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                VStack(alignment: .leading) {
                    Text("Run Index")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verdict)
                        .font(.headline)
                }
            }

            ForEach(bullets.prefix(3), id: \.self) { bullet in
                Label(bullet, systemImage: "figure.run")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func hourlyStrip(_ items: [HourlyDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next 12 Hours")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            Text(item.timeLabel).font(.caption2.monospacedDigit())
                            Text(item.icon).font(.title3)
                            Text(item.rainChanceLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
