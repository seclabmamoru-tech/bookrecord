import SwiftUI

/// 設定画面（AI同意撤回・プライバシーポリシー・利用規約）
struct SettingsView: View {

    @EnvironmentObject var viewModel: AIInsightViewModel
    @State private var showRevokeAlert = false

    private let privacyPolicyURL = URL(string: "https://it-master.jp/privacy-policy")!
    private let termsURL = URL(string: "https://it-master.jp/terms")!

    var body: some View {
        NavigationStack {
            Form {
                // AI機能設定セクション
                Section {
                    if viewModel.hasConsented {
                        // 同意済みの場合：撤回ボタンを表示
                        Button(role: .destructive) {
                            showRevokeAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "xmark.shield")
                                Text("settings.revokeConsent")
                            }
                        }
                    } else {
                        Label {
                            Text("ai.notConsented")
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "xmark.shield")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("tab.ai")
                } footer: {
                    if viewModel.hasConsented {
                        Text("settings.revokeConsentFooter")
                    }
                }

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
            .alert("settings.revokeConsent", isPresented: $showRevokeAlert) {
                Button("settings.revokeConsent", role: .destructive) {
                    viewModel.revokeConsent()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.revokeConsentMessage")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AIInsightViewModel())
}
