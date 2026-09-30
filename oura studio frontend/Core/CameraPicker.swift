import SwiftUI
import AVFoundation
import Combine
import UIKit

// MARK: - CameraPicker (kamera custom 1:1 via AVFoundation)
//
// Menggantikan UIImagePickerController + overlay. Preview-nya BENAR-BENAR kotak 1:1
// (preview layer di dalam frame persegi, aspectFill), sehingga hasil capture
// = yang terlihat di layar. Tidak ada lagi geser akibat beda framing preview vs sensor.

struct CameraPicker: View {
    @Binding var selectedImage: UIImage?
    /// Dibiarkan agar call-site lama tetap kompilasi — kamera ini selalu 1:1.
    var squareCrop: Bool = true
    @Environment(\.dismiss) private var dismiss

    @StateObject private var manager = SquareCameraManager()
    @State private var captured: UIImage?
    @State private var showCaptured = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let captured, showCaptured {
                // MARK: Review hasil (WYSIWYG — persis kotak preview)
                VStack(spacing: 0) {
                    HStack {
                        Button("Ulangi") {
                            showCaptured = false
                            self.captured = nil
                            manager.restartPreview()
                        }
                        .foregroundStyle(.white)
                        Spacer()
                        Text("Pratinjau 1:1")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Pakai Foto") {
                            selectedImage = captured
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
                        Image(uiImage: captured)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: side, height: side)
                            .clipped()
                            .border(.white, width: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    Spacer(minLength: 40)
                }
                .transition(.opacity)
            } else if manager.accessDenied {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Akses kamera ditolak")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Buka Pengaturan → Oura → Kamera untuk mengaktifkan.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Buka Pengaturan") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.yellow)
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(24)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                        Spacer()
                        Text("Foto Produk · 1:1")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            manager.switchCamera()
                        } label: {
                            Image(systemName: "camera.rotate.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                    }
                    .padding(.horizontal, 8)

                    Text("Sejajarkan produk di dalam kotak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 8)

                    // Preview persegi — di tengah layar seperti layar review,
                    // agar transisi live -> hasil terasa smooth (tidak lompat).
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
                        ZStack {
                            CameraPreviewView(session: manager.session)
                                .frame(width: side, height: side)
                                .clipped()
                                .overlay(Rectangle().stroke(.white, lineWidth: 2))
                            if !manager.isReady {
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: side, height: side)
                            }
                            if let err = manager.errorMsg {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                    .padding(8)
                                    .background(.black.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(width: side, height: side, alignment: .bottom)
                                    .padding(.bottom, 8)
                            }
                        }
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Button {
                        manager.capture { image in
                            if let image {
                                captured = image
                                showCaptured = true
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 84, height: 84)
                            if manager.isCapturing {
                                ProgressView().tint(.black)
                            }
                        }
                    }
                    .disabled(!manager.isReady || manager.isCapturing)
                    .opacity(manager.isReady && !manager.isCapturing ? 1 : 0.4)
                    .padding(.bottom, 8)

                    Text("PHOTO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCaptured)
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }
}

// MARK: - Preview layer (persegi, aspectFill = sama dengan hasil crop)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Session manager

final class SquareCameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    private var isConfigured = false
    private var completion: ((UIImage?) -> Void)?

    @Published var isReady = false
    @Published var isCapturing = false
    @Published var errorMsg: String?
    @Published var accessDenied = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configure() }
                    else { self?.accessDenied = true }
                }
            }
        default:
            accessDenied = true
        }
    }

    func stop() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func restartPreview() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    private func configure() {
        if isConfigured {
            restartPreview()
            DispatchQueue.main.async { self.isReady = true }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.addInputLocked(position: self.currentPosition)
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            self.isConfigured = true
            DispatchQueue.main.async { self.isReady = true }
        }
    }

    private func addInputLocked(position: AVCaptureDevice.Position) {
        session.inputs.forEach { session.removeInput($0) }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async { self.errorMsg = "Kamera tidak tersedia di perangkat ini." }
            return
        }
        session.addInput(input)
    }

    func switchCamera() {
        guard isConfigured else { return }
        currentPosition = (currentPosition == .back) ? .front : .back
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.addInputLocked(position: self.currentPosition)
            self.session.commitConfiguration()
        }
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing else { return }
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        }
        DispatchQueue.main.async { self.isCapturing = true }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async { self.isCapturing = false }
        if let error {
            DispatchQueue.main.async { self.errorMsg = "Gagal mengambil foto: \(error.localizedDescription)" }
            completion?(nil)
            completion = nil
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.errorMsg = "Gagal memproses foto." }
            completion?(nil)
            completion = nil
            return
        }
        let square = Self.centerSquareNormalized(image)
        let cb = completion
        completion = nil
        DispatchQueue.main.async { cb?(square) }
    }

    /// Center-crop ke persegi + normalisasi ke orientasi .up.
    /// Karena preview memakai .resizeAspectFill di frame 1:1 yang terpusat,
    /// crop tengah sensor = persis yang terlihat di layar (tidak geser).
    static func centerSquareNormalized(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let side = min(w, h)
        let rect = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
        guard let croppedCG = cg.cropping(to: rect) else { return image }
        let cropped = UIImage(cgImage: croppedCG, scale: 1, orientation: image.imageOrientation)
        // Normalisasi ke .up agar konsisten saat upload/di-cache
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        }
    }
}
