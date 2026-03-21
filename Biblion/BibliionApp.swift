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

    /// 同一フォアグラウンド滞在中に didBecomeActive が複数回発火しても処理を1回に限定するフラグ
    /// didEnterBackground で false にリセットされる
    @State private var pendingActivationHandled = false

    init() {
        // UserPlan 初期化（初回起動時）
        // ※通知許可は ATT より先に表示されないよう、ATT 完了後にリクエストする
        initializeUserPlan()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
                .environmentObject(homeViewModel)
                .environmentObject(libraryViewModel)
                .environmentObject(taskViewModel)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // バッジをクリアする
                    NotificationManager.shared.clearBadge()
                    guard !pendingActivationHandled else { return }
                    pendingActivationHandled = true
                    ATTManager.shared.requestIfNeeded { wasFirstRequest in
                        NotificationManager.shared.requestAuthorization()
                        let plan = CoreDataManager.shared.fetchOrCreateUserPlan()
                        let planType = PlanType(rawValue: plan.planType ?? "free") ?? .free
                        if !wasFirstRequest && PlanLimits.showLaunchInterstitial(for: planType) {
                            InterstitialAdManager.shared.startSdkAndLoadIfNeeded()
                        } else {
                            InterstitialAdManager.shared.initializeSdkOnly()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    pendingActivationHandled = false
                    // 朝のメモ通知をスケジュール（有効な場合）
                    scheduleMorningMemoNotificationIfNeeded()
                }
        }
    }

    // MARK: - 朝のメモ通知スケジューリング

    /// バックグラウンド移行時に翌朝のメモ通知を動的にスケジュールする
    private func scheduleMorningMemoNotificationIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "morningMemo.isEnabled") else { return }

        let hour   = defaults.object(forKey: "morningMemo.hour")   != nil ? defaults.integer(forKey: "morningMemo.hour")   : 8
        let minute = defaults.object(forKey: "morningMemo.minute") != nil ? defaults.integer(forKey: "morningMemo.minute") : 0

        // メモが存在する書籍からランダムに1件選択
        let books = CoreDataManager.shared.fetchBooks()
        let booksWithMemos = books.filter { book in
            let memos = CoreDataManager.shared.fetchMemos(for: book)
            return !memos.isEmpty
        }

        guard let randomBook = booksWithMemos.randomElement(),
              let bookTitle = randomBook.title else {
            NotificationManager.shared.removeMorningMemoNotification()
            return
        }

        let memos = CoreDataManager.shared.fetchMemos(for: randomBook)
        guard let randomMemo = memos.randomElement(),
              let memoContent = randomMemo.content else { return }

        NotificationManager.shared.scheduleMorningMemoNotification(
            memo: memoContent,
            bookTitle: bookTitle,
            hour: hour,
            minute: minute
        )
    }

    // MARK: - UserPlan 初期化

    private func initializeUserPlan() {
        let cdManager = CoreDataManager.shared
        // fetchOrCreateUserPlan() 内でマイグレーションも実施
        cdManager.fetchOrCreateUserPlan()
        // 初回無料チケット付与（3枚）
        cdManager.grantFreeTicketsIfNeeded()
        // 月次チケット付与（Free/Basic: 1枚/月, Premium: 10枚/月）
        cdManager.grantMonthlyTicketsIfNeeded()
    }
}

// MARK: - ATT（App Tracking Transparency）管理

private final class ATTManager {

    static let shared = ATTManager()

    private init() {}

    /// ATT ステータスが未確定ならダイアログを表示し、完了後に completion を呼ぶ。
    /// UserDefaults ではなく OS が管理する実際のステータスを参照するため、
    /// 再インストール後に UserDefaults がリセットされても正しく動作する。
    /// - Parameter completion: wasFirstRequest が true の場合はダイアログを表示した（広告スキップ対象）
    func requestIfNeeded(completion: @escaping (_ wasFirstRequest: Bool) -> Void) {
        guard #available(iOS 14, *) else {
            completion(false)
            return
        }

        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else {
            // 既にユーザーが回答済み（または制限あり）→ ダイアログ不要
            print("[ATT] ステータス確定済みのためダイアログをスキップ: \(status.rawValue)")
            completion(false)
            return
        }

        // ウィンドウ階層が確立されてからダイアログを表示する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { completion(true) }
            }
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
    private var aiAdCompletion: (() -> Void)?

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

    /// AI実行後に広告を表示し、閉じたら completion を呼ぶ（日次制限なし）
    func showAIAd(completion: @escaping () -> Void) {
        guard isSdkStarted else {
            DispatchQueue.main.async { completion() }
            return
        }
        aiAdCompletion = completion
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { completion(); return }
            if let error {
                print("[Ad] AI広告 読み込み失敗: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.aiAdCompletion?()
                    self.aiAdCompletion = nil
                }
                return
            }
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.presentAd()
        }
    }

    func loadAndShowIfNeeded(retryCount: Int = 0) {
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
        print("[Ad] インタースティシャル広告をロード開始（試行\(retryCount + 1)回目）")
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                print("[Ad] 読み込み失敗: \(error.localizedDescription)")
                // 最大2回リトライ（2秒・4秒後）
                if retryCount < 2 {
                    let delay = Double(retryCount + 1) * 2.0
                    print("[Ad] \(Int(delay))秒後にリトライ（残り\(2 - retryCount)回）")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.loadAndShowIfNeeded(retryCount: retryCount + 1)
                    }
                }
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
        // 日付は実際にウィンドウが見つかって表示する直前に記録する（失敗時は記録しない）
        presentAd(retriesLeft: 3)
    }

    private func presentAd(retriesLeft: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let ad = self.interstitialAd else {
                print("[Ad] 広告オブジェクトがnil")
                let completion = self.aiAdCompletion
                self.aiAdCompletion = nil
                completion?()
                return
            }
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                // ウィンドウ未確立の場合はリトライ
                if retriesLeft > 0 {
                    print("[Ad] ウィンドウ未確立、1秒後にリトライ（残り\(retriesLeft)回）")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.presentAd(retriesLeft: retriesLeft - 1)
                    }
                } else {
                    print("[Ad] アクティブなWindowSceneが見つかりません（リトライ上限）")
                    let completion = self.aiAdCompletion
                    self.aiAdCompletion = nil
                    completion?()
                }
                return
            }
            let keyWindow: UIWindow?
            if #available(iOS 15, *) {
                keyWindow = windowScene.keyWindow
            } else {
                keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
            }
            guard let rootVC = keyWindow?.rootViewController else {
                // rootVC未確立の場合もリトライ
                if retriesLeft > 0 {
                    print("[Ad] rootVC未確立、1秒後にリトライ（残り\(retriesLeft)回）")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.presentAd(retriesLeft: retriesLeft - 1)
                    }
                } else {
                    print("[Ad] rootViewControllerが見つかりません（リトライ上限）")
                    let completion = self.aiAdCompletion
                    self.aiAdCompletion = nil
                    completion?()
                }
                return
            }
            // rootVC がすでにモーダルを表示中（通知許可ダイアログ等）の場合はリトライ
            if rootVC.presentedViewController != nil {
                if retriesLeft > 0 {
                    print("[Ad] rootVCが他のVCを表示中、1秒後にリトライ（残り\(retriesLeft)回）")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.presentAd(retriesLeft: retriesLeft - 1)
                    }
                } else {
                    print("[Ad] rootVCが他のVCを表示中のまま上限に達しました")
                    let completion = self.aiAdCompletion
                    self.aiAdCompletion = nil
                    completion?()
                }
                return
            }
            print("[Ad] 表示します")
            ad.present(fromRootViewController: rootVC)
        }
    }
}

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // 実際に画面に表示されたタイミングで日次フラグを記録（失敗時は記録しない）
        if aiAdCompletion == nil {
            UserDefaults.standard.set(Date(), forKey: lastShownDateKey)
        }
        print("[Ad] 広告を表示しました")
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[Ad] 表示失敗: \(error.localizedDescription)")
        interstitialAd = nil
        let completion = aiAdCompletion
        aiAdCompletion = nil
        DispatchQueue.main.async { completion?() }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("[Ad] 広告を閉じました")
        interstitialAd = nil
        let completion = aiAdCompletion
        aiAdCompletion = nil
        DispatchQueue.main.async { completion?() }
    }
}
