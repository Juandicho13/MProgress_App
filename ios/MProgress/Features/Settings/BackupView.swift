import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Respaldo y dispositivos (pantalla 4): respaldo cifrado automático, Exportar (.mprogress y CSV) y Restaurar.
/// iCloud Drive se activa cuando la app tenga firma (F00-02); la cuenta MProgress y los dispositivos, en F10.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @AppStorage(BackupService.lastBackupKey) private var lastBackup: Double = 0

    @State private var exportURL: URL?
    @State private var csvURL: URL?
    @State private var importing = false
    @State private var pending: BackupSnapshot?
    @State private var message: String?
    @State private var errorText: String?

    private var currency: Currency { (spaces.first { $0.kindRaw == "personal" } ?? spaces.first)?.currency ?? .cop }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Respaldo y dispositivos").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                statusCard
                SectionLabel(text: "Dónde se guarda")
                Card(padding: Spacing.s2) {
                    VStack(spacing: 0) {
                        place("En este iPhone", "Cifrado, uno por día, los últimos 7. Lo ves en Archivos › MProgress.", on: true)
                        Divider().overlay(Palette.linea)
                        place("iCloud", "Llega cuando la app tenga firma. La llave de cifrado ya viaja en tu llavero de iCloud.", on: false)
                        Divider().overlay(Palette.linea)
                        place("Cuenta MProgress", "Sincronización en vivo entre teléfonos, en la fase de cuentas.", on: false)
                    }
                }
                SectionLabel(text: "Exportar e importar")
                HStack(spacing: Spacing.s3) {
                    if let exportURL {
                        ShareLink(item: exportURL) { Text("Exportar").frame(maxWidth: .infinity) }.buttonStyle(.secondary)
                    }
                    Button("Restaurar") { importing = true }.buttonStyle(.secondary)
                }
                if let csvURL {
                    ShareLink(item: csvURL) { Text("Movimientos en CSV").frame(maxWidth: .infinity) }.buttonStyle(.secondary)
                }
                Text("El archivo .mprogress trae todo: movimientos, pagos fijos, bancos, límites y metas. El CSV abre en Excel o Numbers.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
                SignatureFooter()
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task { prepareExports() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .json]) { result in
            load(result)
        }
        .confirmationDialog("¿Restaurar este respaldo?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            Button("Restaurar y reemplazar", role: .destructive) { restore() }
            Button("Cancelar", role: .cancel) { pending = nil }
        } message: {
            if let pending {
                Text("Trae \(pending.summary). Lo que hay ahora en la app se reemplaza. Antes se guarda un respaldo de hoy por si acaso.")
            }
        }
        .alert("No se pudo", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var statusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(spacing: Spacing.s3) {
                    IconTile(content: .symbol(lastBackup > 0 ? "checkmark" : "exclamationmark"),
                             tint: lastBackup > 0 ? Palette.brasa : Palette.oroVelo,
                             foreground: lastBackup > 0 ? Palette.sobreBrasa : Palette.oro, size: 40, circle: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lastBackup > 0 ? "Todo está a salvo" : "Aún sin respaldo").appFont(.titulo3).foregroundStyle(Palette.texto1)
                        Text(lastBackupText).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                    }
                }
                Button("Respaldar ahora") { backupNow() }.buttonStyle(.primary)
                if let message {
                    Text(message).appFont(.leyenda).foregroundStyle(Palette.exito)
                }
            }
        }
    }

    private var lastBackupText: String {
        guard lastBackup > 0 else { return "La app se respalda sola una vez al día." }
        let date = Date(timeIntervalSinceReferenceDate: lastBackup)
        let time = date.formatted(date: .omitted, time: .shortened)
        return "Último respaldo: \(DueText.describe(date, now: .now, calendar: calendar).lowercased()), \(time)"
    }

    private func place(_ title: String, _ detail: String, on: Bool) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Text(detail).appFont(.leyenda).foregroundStyle(Palette.texto2)
            }
            Spacer()
            Image(systemName: on ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(on ? Palette.brasa : Palette.texto2)
        }
        .padding(.horizontal, Spacing.s2)
        .padding(.vertical, Spacing.s3)
        .accessibilityElement(children: .combine)
        .accessibilityValue(on ? "Activo" : "Pronto")
    }

    /// Escribe los dos archivos de exportar en la carpeta temporal para compartirlos.
    private func prepareExports() {
        do {
            let snapshot = try BackupService.snapshot(context: context)
            let folder = URL.temporaryDirectory
            let file = folder.appending(path: BackupCodec.fileName(date: .now, calendar: calendar))
            try BackupCodec.encode(snapshot).write(to: file, options: .atomic)
            exportURL = file
            let csv = folder.appending(path: BackupCodec.fileName(date: .now, calendar: calendar, ext: "csv"))
            try Data(BackupCodec.csv(snapshot, currency: currency, calendar: calendar).utf8).write(to: csv, options: .atomic)
            csvURL = csv
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func backupNow() {
        do {
            try BackupService.autoBackupIfNeeded(context: context, calendar: calendar, force: true)
            message = "Listo, respaldo cifrado guardado."
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pending = try BackupService.read(Data(contentsOf: url))
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func restore() {
        guard let pending else { return }
        do {
            try BackupService.autoBackupIfNeeded(context: context, calendar: calendar, force: true)
            try BackupService.restore(pending, context: context)
            message = "Respaldo restaurado: \(pending.summary)."
            self.pending = nil
            prepareExports()
            Task { await NotificationScheduler.reschedule(context: context) }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
