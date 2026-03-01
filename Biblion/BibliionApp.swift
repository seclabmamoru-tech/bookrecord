import SwiftUI
import GoogleMobileAds
import UIKit

/// アプリのエントリーポイント
@main
struct BibliionApp: App {

    // MARK: - ViewModels
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var taskViewModel = TaskViewModel()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // AdMob SDK の初期化（完了を待ってから広告ロードを許可）
        GADMobileAds.sharedInstance().start { _ in
            InterstitialAdManager.shared.notifySdkReady()
        }
        // 通知許可の申請
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
                .environmentObject(homeViewModel)
                .environmentObject(libraryViewModel)
                .environmentObject(taskViewModel)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        InterstitialAdManager.shared.loadAndShowIfNeeded()
                    }
                }
        }
    }
}

// MARK: - インタースティシャル広告管理（1日1回）

private final class InterstitialAdManager: NSObject {

    static let shared = InterstitialAdManager()

    private let adUnitID = "ca-app-pub-5201067107891611/9633575022"
    private let lastShownDateKey = "interstitialLastShownDate"
    private var interstitialAd: GADInterstitialAd?
    private var isLoading = false
    private var isSdkReady = false

    private override init() {
        super.init()
    }

    func notifySdkReady() {
        isSdkReady = true
    }

    func loadAndShowIfNeeded() {
        guard isSdkReady, !isLoading, shouldShowToday() else { return }

        isLoading = true
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                print("インタースティシャル広告の読み込みに失敗: \(error.localizedDescription)")
                return
            }
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.present()
        }
    }

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

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("インタースティシャル広告の表示に失敗: \(error.localizedDescription)")
        interstitialAd = nil
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        interstitialAd = nil
    }
}
