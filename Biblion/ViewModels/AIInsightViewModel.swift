import SwiftUI

/// AI相談画面の ViewModel（同意管理）
final class AIInsightViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var hasConsented: Bool
    @Published var challengeText: String = ""
    @Published var showConsentSheet = false

    // MARK: - UserDefaults キー

    private static let consentKey = "aiConsentGranted"

    // MARK: - 初期化

    init() {
        hasConsented = UserDefaults.standard.bool(forKey: AIInsightViewModel.consentKey)
    }

    // MARK: - 同意操作

    /// AI機能への同意を記録する
    func grantConsent() {
        UserDefaults.standard.set(true, forKey: AIInsightViewModel.consentKey)
        hasConsented = true
        showConsentSheet = false
    }

    /// AI機能への同意を撤回する
    func revokeConsent() {
        UserDefaults.standard.set(false, forKey: AIInsightViewModel.consentKey)
        hasConsented = false
    }
}
