import SwiftUI
import UIKit

/// Ajustes › Cuenta (docs/PLAN_F10.md): entrar con el enlace del correo, estado de la sincronización,
/// "Sincronizar ahora", código de recuperación, dispositivos y cerrar sesión. La nube es opcional.
struct AccountView: View {
    @Environment(\.calendar) private var calendar
    @State private var emailText = ""
    @State private var codeText = ""
    @State private var showsRecoveryEntry = false
    @State private var confirmsSignOut = false
    @State private var confirmsNewCode = false

    private var cloud: CloudAccount { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Cuenta").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                switch cloud.phase {
                case .signedOut: signInCard
                case .linkSent(let email): linkSentCard(email)
                case .connecting: connectingCard
                case .needsApproval: approvalCard
                case .ready: readyContent
                }
                if let error = cloud.errorText {
                    Text(error).appFont(.cuerpo2).foregroundStyle(Palette.peligro)
                }
                Text("Tus datos se cifran en este iPhone antes de subir. Ni Supabase ni nadie más puede leer tus montos, nombres o notas: solo tus dispositivos.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsRecoveryEntry) { RecoveryEntryView() }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { Task { await cloud.signOut() } }
        } message: {
            Text("Tus datos se quedan en este iPhone. Este dispositivo sale de tu cuenta y para volver a ver lo de la nube tendrás que entrar y aprobarlo otra vez.")
        }
        .confirmationDialog("¿Crear un código nuevo?", isPresented: $confirmsNewCode, titleVisibility: .visible) {
            Button("Crear código nuevo") { Task { await cloud.newRecoveryCode() } }
        } message: {
            Text("El código que tienes guardado deja de servir.")
        }
        .task { if cloud.phase == .ready { await cloud.refreshDevices() } }
    }

    // MARK: Sin cuenta

    private var signInCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("Crear cuenta o entrar").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text("Con una cuenta tus datos quedan respaldados y cifrados en la nube, y los ves en tus otros dispositivos. Sin contraseña: te mandamos un enlace al correo.")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
                TextField("tu@correo.com", text: $emailText)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .appFont(.cuerpo)
                    .foregroundStyle(Palette.texto1)
                    .padding(.horizontal, Spacing.s4)
                    .frame(minHeight: Size.toqueMinimo)
                    .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                    .submitLabel(.send)
                    .onSubmit { send() }
                Button(cloud.isWorking ? "Enviando…" : "Enviarme el enlace") { send() }
                    .buttonStyle(.primary)
                    .disabled(cloud.isWorking || emailText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func linkSentCard(_ email: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                IconTile(content: .symbol("envelope.open"), tint: Palette.brasaVelo, foreground: Palette.brasaTinta, size: 52)
                Text("Revisa tu correo").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text("Te mandamos un enlace a \(email). Ábrelo en este iPhone y entras de una vez. Si no llega, mira en correo no deseado.")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
                if CloudConfig.allowsCodeEntry {
                    TextField("Código de 6 dígitos", text: $codeText)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .appFont(.cifra)
                        .padding(.horizontal, Spacing.s4)
                        .frame(minHeight: Size.toqueMinimo)
                        .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                    Button("Entrar con el código") { Task { await cloud.verify(code: codeText) } }
                        .buttonStyle(.primary)
                        .disabled(codeText.filter(\.isNumber).count != 6 || cloud.isWorking)
                }
                Button("Reenviar el enlace") {
                    emailText = email
                    send()
                }
                .buttonStyle(.secondary)
                .disabled(cloud.isWorking)
                Button("Usar otro correo") { cloud.cancelLink() }
                    .appFont(.etiqueta)
                    .foregroundStyle(Palette.texto2)
                    .frame(minHeight: Size.toqueMinimo)
            }
        }
    }

    private var connectingCard: some View {
        Card {
            HStack(spacing: Spacing.s3) {
                ProgressView()
                Text("Conectando con tu cuenta…").appFont(.cuerpo).foregroundStyle(Palette.texto1)
            }
            .frame(minHeight: Size.toqueMinimo)
        }
    }

    // MARK: Segundo dispositivo

    private var approvalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                IconTile(content: .symbol("iphone.and.arrow.forward"), tint: Palette.hieloVelo, foreground: Palette.hielo, size: 52)
                Text("Aprueba este dispositivo en tu otro teléfono").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text("Abre MProgress en el iPhone donde ya tienes tu cuenta. Verás un aviso para aprobar este; también está en Ajustes › Cuenta › Dispositivos.")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
                Button(cloud.isWorking ? "Buscando…" : "Ya lo aprobé") { Task { await cloud.checkApproval() } }
                    .buttonStyle(.primary)
                    .disabled(cloud.isWorking)
                Button("Usar el código de recuperación") { showsRecoveryEntry = true }
                    .buttonStyle(.secondary)
                if let email = cloud.email {
                    Text("Entraste como \(email)").appFont(.leyenda).foregroundStyle(Palette.texto2)
                }
                Button("Cerrar sesión") { confirmsSignOut = true }
                    .appFont(.etiqueta)
                    .foregroundStyle(Palette.texto2)
                    .frame(minHeight: Size.toqueMinimo)
            }
        }
    }

    // MARK: Con cuenta

    @ViewBuilder
    private var readyContent: some View {
        ForEach(cloud.pendingApprovals) { device in
            Card {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Un dispositivo nuevo quiere entrar").appFont(.titulo3).foregroundStyle(Palette.texto1)
                    Text("\(device.name ?? "iPhone") entró con tu correo. Si fuiste tú, apruébalo para que pueda leer tus datos.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                    Button("Aprobar") { Task { await cloud.approve(device) } }
                        .buttonStyle(.primary)
                        .disabled(cloud.isWorking)
                }
            }
        }
        // Primera subida (F10-05): avance y, al terminar, que todo quedó en la nube.
        if let progress = cloud.uploadProgress {
            Card {
                HStack(spacing: Spacing.s3) {
                    ProgressView()
                    Text(InitialUpload.progressText(done: progress.done, total: progress.total))
                        .appFont(.cuerpo)
                        .foregroundStyle(Palette.texto1)
                }
                .frame(minHeight: Size.toqueMinimo)
                .accessibilityElement(children: .combine)
            }
        } else if cloud.initialUploadDone {
            Card {
                HStack(spacing: Spacing.s3) {
                    IconTile(content: .symbol("checkmark.icloud"), tint: Palette.superficie3, foreground: Palette.exito, size: 40)
                    Text(InitialUpload.doneText).appFont(.cuerpo).foregroundStyle(Palette.texto1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        Card(padding: Spacing.s2) {
            VStack(spacing: 0) {
                row("Correo", cloud.email ?? "")
                divider
                row("Estado", statusText)
                divider
                Button {
                    Task { await cloud.sync() }
                } label: {
                    rowLabel("Sincronizar ahora", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                if case .error = cloud.status {
                    divider
                    Button { Task { await cloud.retryFailed() } } label: { rowLabel("Reintentar lo que no subió", systemImage: "arrow.clockwise") }
                        .buttonStyle(.plain)
                }
                divider
                NavigationLink { DevicesView() } label: {
                    rowLabel("Dispositivos", value: "\(cloud.devices.count)", chevron: true)
                }
                .buttonStyle(.plain)
                divider
                Button { confirmsNewCode = true } label: {
                    rowLabel("Código de recuperación", value: "Crear uno nuevo", chevron: true)
                }
                .buttonStyle(.plain)
            }
        }
        Text("Con el código de recuperación entras en un iPhone nuevo aunque pierdas todos tus dispositivos. Si lo perdiste, crea uno nuevo aquí.")
            .appFont(.leyenda)
            .foregroundStyle(Palette.texto2)
        Button("Cerrar sesión") { confirmsSignOut = true }
            .buttonStyle(.secondary)
    }

    /// "Al día · hace 2 min".
    private var statusText: String {
        let base = (cloud.pill ?? .alDia).text
        guard let last = cloud.lastSyncAt else { return base }
        return "\(base) · \(SyncText.relative(last, now: .now).lowercased())"
    }

    // MARK: Piezas

    private var divider: some View { Divider().overlay(Palette.linea) }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer()
            Text(value).appFont(.cuerpo2).foregroundStyle(Palette.texto2).lineLimit(1)
        }
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private func rowLabel(_ title: String, systemImage: String? = nil, value: String? = nil, chevron: Bool = false) -> some View {
        HStack {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.brasaTinta)
            }
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer()
            if let value { Text(value).appFont(.cuerpo2).foregroundStyle(Palette.texto2) }
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.texto2)
            }
        }
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func send() {
        let email = emailText
        Task { await cloud.sendLink(email: email) }
    }
}

/// El código de recuperación recién creado. Se muestra una sola vez: hay que guardarlo.
struct RecoveryCodeView: View {
    let code: String
    @State private var copied = false

    private var groups: [String] { code.split(separator: "-").map(String.init) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("Guarda tu código de recuperación").appFont(.titulo2).foregroundStyle(Palette.texto1)
                    Text("Con él entras a tus datos en un iPhone nuevo si pierdes todos tus dispositivos. Guárdalo en tu gestor de contraseñas o escríbelo en papel. Nosotros no lo tenemos y no lo podemos recuperar.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                    Card {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 3), spacing: Spacing.s3) {
                            ForEach(Array(groups.enumerated()), id: \.offset) { item in
                                Text(item.element)
                                    .appFont(.cifra)
                                    .foregroundStyle(Palette.texto1)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Código de recuperación")
                        .accessibilityValue(code.map { String($0) }.joined(separator: " "))
                    }
                    Button(copied ? "Copiado" : "Copiar") {
                        UIPasteboard.general.string = code
                        copied = true
                    }
                    .buttonStyle(.secondary)
                    Button("Ya lo guardé") { CloudAccount.shared.recoveryPrompt = nil }
                        .buttonStyle(.primary)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Código de recuperación")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }
}

/// Escribir el código de recuperación en un dispositivo nuevo.
struct RecoveryEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var cloud: CloudAccount { .shared }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Escribe los 24 caracteres del código que guardaste al crear tu cuenta. Los guiones y las mayúsculas no importan.")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
                TextField("ABCD-EFGH-JKLM-NPQR-STUV-WXYZ", text: $text, axis: .vertical)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .appFont(.cifra)
                    .foregroundStyle(Palette.texto1)
                    .padding(Spacing.s4)
                    .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                if let error = cloud.errorText {
                    Text(error).appFont(.cuerpo2).foregroundStyle(Palette.peligro)
                }
                Button(cloud.isWorking ? "Recuperando…" : "Recuperar mis datos") {
                    let code = text
                    Task { if await cloud.useRecoveryCode(code) { dismiss() } }
                }
                .buttonStyle(.primary)
                .disabled(RecoveryCode.normalize(text) == nil || cloud.isWorking)
                Spacer()
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.vertical, Spacing.s4)
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Código de recuperación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }
}

/// Dispositivos de la cuenta: este, los aprobados y los que esperan aprobación.
struct DevicesView: View {
    @Environment(\.calendar) private var calendar
    @State private var removing: RemoteDevice?

    private var cloud: CloudAccount { .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("Dispositivos").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                Card(padding: Spacing.s3) {
                    VStack(spacing: Spacing.s2) {
                        ForEach(cloud.devices) { device in
                            deviceRow(device)
                        }
                        if cloud.devices.isEmpty {
                            Text("Cargando…").appFont(.cuerpo2).foregroundStyle(Palette.texto2).padding(Spacing.s2)
                        }
                    }
                }
                Text("Quitar un dispositivo lo saca de tu cuenta: ya no recibe tus cambios nuevos. Lo que ya tenía guardado se queda en él.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cloud.refreshDevices() }
        .confirmationDialog("¿Quitar este dispositivo?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible) {
            Button("Quitar", role: .destructive) {
                if let device = removing { Task { await cloud.remove(device) } }
            }
        }
    }

    private func deviceRow(_ device: RemoteDevice) -> some View {
        let isThis = device.id == cloud.thisDeviceId
        let waiting = cloud.pendingApprovals.contains { $0.id == device.id }
        let since = device.createdAt.map { "Desde el \(DueText.shortDate($0, calendar: calendar))" } ?? ""
        return ListRow(tile: IconTile(content: .symbol("iphone")),
                       title: isThis ? "Este iPhone" : (device.name ?? "iPhone"),
                       subtitle: waiting ? "Espera tu aprobación" : since) {
            if waiting {
                Button("Aprobar") { Task { await cloud.approve(device) } }
                    .appFont(.etiqueta)
                    .foregroundStyle(Palette.brasaTinta)
                    .frame(minHeight: Size.toqueMinimo)
            } else if !isThis {
                Button { removing = device } label: {
                    Image(systemName: "trash").foregroundStyle(Palette.peligro).frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
                }
                .accessibilityLabel("Quitar")
            }
        }
    }
}
