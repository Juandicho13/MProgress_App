import SwiftUI
import PhotosUI
import Vision
import VisionKit

/// Escanear recibo (F08-05): foto con la cámara o desde Fotos, lee el texto en el iPhone y arma un borrador.
struct ReceiptScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (_ merchant: String?, _ amountMinor: Int64?) -> Void

    @State private var showsCamera = false
    @State private var photo: PhotosPickerItem?
    @State private var working = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("Escanear recibo").appFont(.titulo2).foregroundStyle(Palette.texto1).padding(.top, Spacing.s6)
            Text("Leemos el total y el comercio en tu iPhone; la foto no sale de aquí ni se guarda.")
                .appFont(.cuerpo2)
                .foregroundStyle(Palette.texto2)
            if working {
                ProgressView("Leyendo el recibo…").tint(Palette.brasa).frame(maxWidth: .infinity)
            }
            if failed {
                Text("No encontramos un total. Puedes escribirlo tú.").appFont(.cuerpo2).foregroundStyle(Palette.peligro)
                Button("Escribirlo a mano") {
                    onResult(nil, nil)
                    dismiss()
                }
                .buttonStyle(.secondary)
            }
            Spacer()
            if VNDocumentCameraViewController.isSupported {
                Button("Tomar foto") { showsCamera = true }.buttonStyle(.primary)
            }
            PhotosPicker(selection: $photo, matching: .images) {
                Text("Elegir de Fotos").frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s2)
        .background(Palette.superficie2.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsCamera) {
            DocumentCamera { image in
                showsCamera = false
                if let image { Task { await read(image) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data)?.cgImage {
                    await read(image)
                }
            }
        }
    }

    private func read(_ image: CGImage) async {
        working = true
        failed = false
        let lines = await ReceiptText.lines(in: image)
        working = false
        guard let total = ReceiptParser.total(lines: lines) else {
            failed = true
            return
        }
        onResult(ReceiptParser.merchant(lines: lines), total)
        dismiss()
    }
}

/// Texto del recibo con Vision, en español.
@MainActor
enum ReceiptText {
    static func lines(in image: CGImage) async -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [Locale.Language(identifier: "es-CO"), Locale.Language(identifier: "es")]
        request.usesLanguageCorrection = true
        guard let observations = try? await request.perform(on: image) else { return [] }
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }
}

/// Cámara de documentos de VisionKit: recorta y endereza el recibo.
private struct DocumentCamera: UIViewControllerRepresentable {
    let onFinish: (CGImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        let onFinish: (CGImage?) -> Void

        init(onFinish: @escaping (CGImage?) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish(scan.pageCount > 0 ? scan.imageOfPage(at: 0).cgImage : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(nil)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish(nil)
        }
    }
}
