import SwiftUI
import GoogleMobileAds

/// AdMob バナー広告ビュー（UIViewRepresentable）
struct BannerAdView: UIViewRepresentable {

    private let adUnitID = "ca-app-pub-5201067107891611/8582219363"

    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        return bannerView
    }

    func updateUIView(_ bannerView: GADBannerView, context: Context) {
        // rootViewController を設定してリクエストを送信
        guard bannerView.rootViewController == nil else { return }

        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            bannerView.rootViewController = rootVC
            bannerView.load(GADRequest())
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("バナー広告の読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BannerAdView()
        .frame(height: 50)
}
