import SwiftUI

/// 設定画面（プライバシーポリシー・利用規約）
struct SettingsView: View {

    private var isJapanese: Bool {
        Locale.current.language.languageCode?.identifier == "ja"
    }
    private var privacyPolicyURL: URL {
        URL(string: isJapanese
            ? "https://it-master.jp/biblion/privacy-policy.html"
            : "https://it-master.jp/biblion/privacy-policy-en.html")!
    }
    private var termsURL: URL {
        URL(string: isJapanese
            ? "https://it-master.jp/biblion/terms.html"
            : "https://it-master.jp/biblion/terms-en.html")!
    }

    var body: some View {
        NavigationStack {
            Form {
                // リンクセクション
                Section {
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
