import SwiftUI

/// AI機能利用同意ダイアログ
/// Phase 2: 同意状態をCoreData（UserPlan.isAIConsentGiven）に保存
struct AIConsentView: View {

    /// 同意完了コールバック（呼び出し元に通知）
    var onConsent: (() -> Void)?

    @EnvironmentObject var viewModel: AIInsightViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isChecked = false

    private var privacyPolicyURL: URL {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        return URL(string: isJapanese
            ? "https://it-master.jp/biblion/privacy-policy.html"
            : "https://it-master.jp/biblion/privacy-policy-en.html")!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // タイトルアイコン
                    HStack {
                        Spacer()
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.indigo)
                        Spacer()
                    }
                    .padding(.top)

                    Text("ai.consentTitle")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // 同意文（スクロール可能テキストエリア）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ai.consentBody")
                            .font(.body)
                            .lineSpacing(4)

                        // プライバシーポリシーリンク
                        Link(destination: privacyPolicyURL) {
                            Label("settings.privacyPolicy", systemImage: "link")
                                .font(.footnote)
                                .foregroundColor(.indigo)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    // 同意チェックボックス
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            isChecked.toggle()
                        } label: {
                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundColor(isChecked ? .indigo : .gray)
                        }
                        .buttonStyle(.plain)

                        Text("ai.consentCheck")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture { isChecked.toggle() }
                    }

                    // 確認ボタン（チェックが入っている場合のみ活性化）
                    Button {
                        grantConsent()
                    } label: {
                        Text("ai.consentConfirm")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isChecked ? Color.indigo : Color(.systemGray4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!isChecked)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 同意処理

    private func grantConsent() {
        // CoreDataに保存（Phase 2）
        CoreDataManager.shared.setAIConsent(true)

        // 後方互換：既存ViewModelも更新
        viewModel.grantConsent()

        onConsent?()
        dismiss()
    }
}

#Preview {
    AIConsentView()
        .environmentObject(AIInsightViewModel())
}
