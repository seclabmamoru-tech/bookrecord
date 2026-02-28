import SwiftUI
import GoogleMobileAds

/// アプリのエントリーポイント
@main
struct BibliionApp: App {

    // MARK: - ViewModels
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var aiInsightViewModel = AIInsightViewModel()

    init() {
        // AdMob SDK の初期化
        GADMobileAds.sharedInstance().start(completionHandler: nil)
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
                .environmentObject(aiInsightViewModel)
        }
    }
}
