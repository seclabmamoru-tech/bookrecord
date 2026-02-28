import SwiftUI

/// AI相談画面（Phase 2 プレースホルダー）
struct AIInsightView: View {

    @EnvironmentObject var viewModel: AIInsightViewModel

    var body: some View {
        Group {
            if viewModel.hasConsented {
                // 同意済み：プレースホルダー UI を表示
                aiPlaceholderContent
            } else {
                // 未同意：同意を促す画面
                consentPromptContent
            }
        }
        .navigationTitle(Text("tab.ai"))
        .sheet(isPresented: $viewModel.showConsentSheet) {
            AIConsentView()
                .environmentObject(viewModel)
        }
    }

    // MARK: - プレースホルダーコンテンツ

    private var aiPlaceholderContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // アイコン
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(.indigo)
                    .padding(.top, 40)

                Text("ai.comingSoon")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("ai.disclaimer")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 課題入力欄（現フェーズは disabled）
                VStack(alignment: .leading, spacing: 8) {
                    Text("ai.inputPlaceholder")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $viewModel.challengeText)
                        .frame(height: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .disabled(true)
                        .opacity(0.6)
                }
                .padding(.horizontal)

                // 提案を見るボタン（現フェーズは常に disabled）
                Button {
                    // Phase 2 で実装
                } label: {
                    Text("ai.getSuggestion")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(true)
                .padding(.horizontal)

                // 近日公開予定ラベル
                HStack {
                    Image(systemName: "clock")
                    Text("ai.comingSoon")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - 同意を促す画面

    private var consentPromptContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.indigo)

            Text("ai.consentTitle")
                .font(.title2.bold())

            Text("ai.consentRequired")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.showConsentSheet = true
            } label: {
                Text("ai.consentConfirm")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

#Preview {
    AIInsightView()
        .environmentObject(AIInsightViewModel())
}
