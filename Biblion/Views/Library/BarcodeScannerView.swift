import SwiftUI
import AVFoundation

// MARK: - スキャン結果

struct BarcodeBookInfo {
    let isbn: String
    let title: String
    let author: String
}

// MARK: - BarcodeScannerView

/// バーコードスキャナー（AVFoundation使用、Basic以上のみ）
struct BarcodeScannerView: UIViewControllerRepresentable {

    /// スキャン成功時のコールバック
    var onFound: (BarcodeBookInfo) -> Void
    /// エラー時のコールバック
    var onError: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound, onError: onError)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, BarcodeScannerDelegate {
        let onFound: (BarcodeBookInfo) -> Void
        let onError: (String) -> Void

        init(onFound: @escaping (BarcodeBookInfo) -> Void, onError: @escaping (String) -> Void) {
            self.onFound = onFound
            self.onError = onError
        }

        func didFind(isbn: String) {
            Task { @MainActor in
                do {
                    if let info = try await OpenBDService.fetchBookInfo(isbn: isbn) {
                        onFound(info)
                    } else {
                        onError(NSLocalizedString("barcode.notFound", comment: ""))
                    }
                } catch {
                    onError(NSLocalizedString("barcode.notFound", comment: ""))
                }
            }
        }
    }
}

// MARK: - バーコードスキャナーDelegate

protocol BarcodeScannerDelegate: AnyObject {
    func didFind(isbn: String)
}

// MARK: - BarcodeScannerViewController

final class BarcodeScannerViewController: UIViewController {

    weak var delegate: BarcodeScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasFoundCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
        addGuideOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    // MARK: - セッション設定

    private func setupCaptureSession() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showError("カメラの初期化に失敗しました")
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // MARK: - ガイドオーバーレイ

    private func addGuideOverlay() {
        let label = UILabel()
        label.text = NSLocalizedString("barcode.scanning", comment: "")
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            label.heightAnchor.constraint(equalToConstant: 44)
        ])

        // スキャン枠
        let frameView = UIView()
        frameView.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 8
        frameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)

        NSLayoutConstraint.activate([
            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            frameView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            frameView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasFoundCode,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let isbn = metadata.stringValue else { return }

        hasFoundCode = true
        captureSession?.stopRunning()
        delegate?.didFind(isbn: isbn)
    }
}

// MARK: - BarcodeScannerSheet（SwiftUI Sheet ラッパー）

struct BarcodeScannerSheet: View {
    let onFound: (BarcodeBookInfo) -> Void
    let onError: (String) -> Void

    var body: some View {
        NavigationStack {
            BarcodeScannerView(onFound: onFound, onError: onError)
                .ignoresSafeArea()
                .navigationTitle(Text("barcode.scan"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - OpenBD API サービス

struct OpenBDService {
    static func fetchBookInfo(isbn: String) async throws -> BarcodeBookInfo? {
        let cleanISBN = isbn.filter { $0.isNumber }
        guard let url = URL(string: "https://api.openbd.jp/v1/get?isbn=\(cleanISBN)") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]?],
              let first = jsonArray.first,
              let summary = first?["summary"] as? [String: Any] else {
            return nil
        }

        let title = summary["title"] as? String ?? ""
        let author = summary["author"] as? String ?? ""

        guard !title.isEmpty else { return nil }

        return BarcodeBookInfo(isbn: cleanISBN, title: title, author: author)
    }
}
