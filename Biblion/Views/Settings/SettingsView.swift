import SwiftUI

/// 設定画面（プライバシーポリシー・利用規約）
struct SettingsView: View {

    private let privacyPolicyURL = URL(string: "https://it-master.jp/privacy-policy")!
    private let termsURL = URL(string: "https://it-master.jp/terms")!

    var body: some View {
        NavigationStack {
            Form {
                // リンクセクション
                Section {
                    Link(destination: privacyPolicyURL) {
                        HStack {
                            Label("settings.privacyPolicy", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    Link(destination: termsURL) {
                        HStack {
                            Label("settings.terms", systemImage: "doc.text.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("settings.legal")
                }

                // アプリ情報
                Section {
                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("settings.about")
                }
            }
            .navigationTitle(Text("settings.title"))
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
}
