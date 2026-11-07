import SwiftUI

/// Hoja "Estado de sincronización" (F10-04, pantalla 37). Se abre al tocar la pastilla de Inicio: conexión, última
/// sincronización, cambios pendientes por tipo, el último error con "Reintentar" y los dispositivos con acceso.
/// Igual que `ui/home/SyncStatusSheet.kt` en Android.
struct SyncStatusSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var cloud: CloudAccount { .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    header
                    Card(padding: Spacing.s2) {
                        VStack(spacing: 0) {
                            row("Conexión", SyncText.connection(online: cloud.isReachable))
                            divider
                            TimelineView(.everyMinute) { timeline in
                                row("Última sincronización", SyncText.relative(cloud.lastSyncAt, now: timeline.date))
                            }
                            divider
                            row("Pendientes", SyncText.pendingSummary(cloud.pendingCounts))
                        }
                    }
                    if let progress = cloud.uploadProgress {
                        Card {
                            HStack(spacing: Spacing.s3) {
                                ProgressView()
                                Text(InitialUpload.progressText(done: progress.done, total: progress.total))
                                    .appFont(.cuerpo)
                                    .foregroundStyle(Palette.texto1)
                            }
                            .frame(minHeight: Size.toqueMinimo)
                        }
                    }
                    if !cloud.isReachable {
                        Text(SyncText.offlineNote).appFont(.leyenda).foregroundStyle(Palette.texto2)
                    }
                    if let problem = cloud.lastError ?? SyncText.failedText(cloud.failedCount) {
                        errorCard(problem)
                    } else {
                        Button("Sincronizar ahora") { Task { await cloud.sync() } }
                            .buttonStyle(.secondary)
                            .disabled(!cloud.isReachable || cloud.pill == .sincronizando)
                    }
                    if !cloud.devices.isEmpty { devicesCard }
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .scrollIndicators(.hidden)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Estado de sincronización")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
        .task { await cloud.refreshDevices() }
    }

    private var pill: SyncPill { cloud.pill ?? .alDia }

    private var header: some View {
        HStack(spacing: Spacing.s3) {
            IconTile(content: .symbol(pill.symbol), tint: tint, foreground: foreground, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(pill.text).appFont(.titulo2).foregroundStyle(Palette.texto1)
                if cloud.initialUploadDone && cloud.uploadProgress == nil && pill == .alDia {
                    Text(InitialUpload.doneText).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch pill {
        case .alDia: Palette.superficie3
        case .sincronizando: Palette.hieloVelo
        case .sinConexion: Palette.oroVelo
        case .error: Palette.peligroVelo
        }
    }

    private var foreground: Color {
        switch pill {
        case .alDia: Palette.exito
        case .sincronizando: Palette.hielo
        case .sinConexion: Palette.oro
        case .error: Palette.peligro
        }
    }

    private func errorCard(_ text: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("No se pudo sincronizar").appFont(.titulo3).foregroundStyle(Palette.peligro)
                Text(text).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                Button("Reintentar") { Task { await cloud.retryFailed() } }
                    .buttonStyle(.primary)
                    .disabled(cloud.pill == .sincronizando)
            }
        }
    }

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            SectionLabel(text: "Dispositivos con acceso")
            Card(padding: Spacing.s3) {
                VStack(spacing: Spacing.s2) {
                    ForEach(cloud.devices) { device in
                        let waiting = cloud.pendingApprovals.contains { $0.id == device.id }
                        ListRow(tile: IconTile(content: .symbol("iphone")),
                                title: device.id == cloud.thisDeviceId ? "Este iPhone" : (device.name ?? "iPhone"),
                                subtitle: waiting ? "Espera tu aprobación" : "Con acceso") {
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    private var divider: some View { Divider().overlay(Palette.linea) }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer(minLength: Spacing.s2)
            Text(value)
                .appFont(.cuerpo2)
                .foregroundStyle(Palette.texto2)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, Spacing.s2)
        .padding(.vertical, Spacing.s3)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }
}
