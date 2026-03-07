import SwiftUI
import GoogleMobileAds
import UIKit
import AppTrackingTransparency

/// アプリのエントリーポイント
@main
struct BibliionApp: App {

    // MARK: - ViewModels
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var taskViewModel = TaskViewModel()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 通知許可の申請
        NotificationManager.shared.requestAuthorization()

        // UserPlan 初期化（初回起動時）
        initializeUserPlan()
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
                        // ATT 確認後に AdMob を初期化し、必要に応じて広告をロード・表示
                        ATTManager.shared.requestIfNeeded {
                            // Freeプランの場合のみインタースティシャルを表示
                            let plan = CoreDataManager.shared.fetchOrCreateUserPlan()
                            let planType = PlanType(rawValue: plan.planType ?? "free") ?? .free
                            if PlanLimits.showLaunchInterstitial(for: planType) {
                                InterstitialAdManager.shared.startSdkAndLoadIfNeeded()
                            } else {
                                // SDK初期化のみ（広告表示なし）
                                InterstitialAdManager.shared.initializeSdkOnly()
                            }
                        }
                    }
                }
        }
    }

    // MARK: - UserPlan 初期化

    private func initializeUserPlan() {
        let cdManager = CoreDataManager.shared
        // fetchOrCreateUserPlan() 内でマイグレーションも実施
        cdManager.fetchOrCreateUserPlan()
        // 初回無料3チケット付与
        cdManager.grantFreeTicketsIfNeeded()
    }
}

// MARK: - ATT（App Tracking Transparency）管理

private final class ATTManager {

    static let shared = ATTManager()
    private let hasRequestedKey = "attHasRequested"

    private init() {}

    /// ATT 未確認なら許可ダイアログを表示し、完了後に completion を呼ぶ。
    /// 既に確認済みの場合は即座に completion を呼ぶ。
    func requestIfNeeded(completion: @escaping () -> Void) {
        guard !UserDefaults.standard.bool(forKey: hasRequestedKey) else {
            completion()
            return
        }
        UserDefaults.standard.set(true, forKey: hasRequestedKey)

        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { completion() }
            }
        } else {
            completion()
        }
    }
}

// MARK: - インタースティシャル広告管理（1日1回・プラン制御）

final class InterstitialAdManager: NSObject {

    static let shared = InterstitialAdManager()

    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用ID
    #else
    private let adUnitID = "ca-app-pub-5201067107891611/9633575022" // 本番用ID
    #endif
    private let lastShownDateKey = "interstitialLastShownDate"
    private var interstitialAd: GADInterstitialAd?
    private var isSdkStarted = false
    private var isLoading = false

    private override init() {
        super.init()
    }

    /// AdMob SDK を初期化し、必要に応じて広告をロード・表示する（セッション内で1回のみ初期化）
    func startSdkAndLoadIfNeeded() {
        guard !isSdkStarted else {
            loadAndShowIfNeeded()
            return
        }
        isSdkStarted = true
        GADMobileAds.sharedInstance().start { [weak self] _ in
            self?.loadAndShowIfNeeded()
        }
    }

    /// SDK初期化のみ（広告表示なし）
    func initializeSdkOnly() {
        guard !isSdkStarted else { return }
        isSdkStarted = true
        GADMobileAds.sharedInstance().start { _ in
            print("[Ad] SDK初期化完了（広告表示なし：有料プラン）")
        }
    }

    func loadAndShowIfNeeded() {
        guard isSdkStarted else {
            print("[Ad] SDK未初期化のためスキップ")
            return
        }
        guard !isLoading else {
            print("[Ad] ロード中のためスキップ")
            return
        }
        guard shouldShowToday() else {
            print("[Ad] 本日は既に表示済みのためスキップ")
            return
        }

        isLoading = true
        print("[Ad] インタースティシャル広告をロード開始")
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                print("[Ad] 読み込み失敗: \(error.localizedDescription)")
                return
            }
            print("[Ad] 読み込み成功、表示を試みます")
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
            guard let self else { return }
            guard let ad = self.interstitialAd else {
                print("[Ad] 広告オブジェクトがnil")
                return
            }
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                print("[Ad] アクティブなWindowSceneが見つかりません")
                return
            }
            guard let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                print("[Ad] rootViewControllerが見つかりません")
                return
            }

            print("[Ad] 表示します")
            ad.present(fromRootViewController: rootVC)
            UserDefaults.standard.set(Date(), forKey: self.lastShownDateKey)
        }
    }
}

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[Ad] 表示失敗: \(error.localizedDescription)")
        interstitialAd = nil
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("[Ad] 広告を閉じました")
        interstitialAd = nil
    }
}
