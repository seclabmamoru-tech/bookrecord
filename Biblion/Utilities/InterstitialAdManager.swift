import GoogleMobileAds
import UIKit

/// インタースティシャル広告の管理クラス（1日1回表示）
final class InterstitialAdManager: NSObject {

    static let shared = InterstitialAdManager()

    private let adUnitID = "ca-app-pub-5201067107891611/9633575022"
    private let lastShownDateKey = "interstitialLastShownDate"
    private var interstitialAd: GADInterstitialAd?

    private override init() {
        super.init()
    }

    // MARK: - 公開メソッド

    /// 必要に応じて広告を読み込み・表示する（1日1回）
    func loadAndShowIfNeeded() {
        guard shouldShowToday() else { return }

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("インタースティシャル広告の読み込みに失敗: \(error.localizedDescription)")
                return
            }
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.present()
        }
    }

    // MARK: - Private

    private func shouldShowToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastShownDateKey) as? Date else {
            return true
        }
        return !Calendar.current.isDateInToday(lastDate)
    }

    private func present() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let ad = self.interstitialAd,
                  let windowScene = UIApplication.shared.connectedScenes
                      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else { return }

            ad.present(fromRootViewController: rootVC)
            UserDefaults.standard.set(Date(), forKey: self.lastShownDateKey)
        }
    }
}

// MARK: - GADFullScreenContentDelegate

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("インタースティシャル広告の表示に失敗: \(error.localizedDescription)")
        interstitialAd = nil
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        interstitialAd = nil
    }
}
