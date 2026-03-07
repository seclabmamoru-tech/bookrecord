import SwiftUI

/// 悩み相談画面
struct AIConsultationView: View {

    @ObservedObject var viewModel: AIViewModel
    @State private var inputText = ""
    @State private var showResult = false
    @State private var showRetryAlert = false

    private let maxChars = 500

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    // 入力エリア
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今の悩みや解決したい課題を入力してください")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text(LocalizedStringKey("ai.inputPlaceholder"))
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $inputText)
                                .frame(height: 160)
                                .padding(4)
                                .onChange(of: inputText) { newValue in
                                    if newValue.count > maxChars {
                                        inputText = String(newValue.prefix(maxChars))
                                    }
                                }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                        // 文字数カウンター
                        Text("\(inputText.count) / \(maxChars)")
                            .font(.caption)
                            .foregroundColor(inputText.count >= maxChars ? .orange : .secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)

                    // 参照書籍数
                    let count = viewModel.booksWithMemosCount
                    if count > 0 {
                        Text(String(format: NSLocalizedString("ai.menu.bookRefCount", comment: ""), count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // 実行ボタン
                    Button {
                        Task { await executeAI() }
                    } label: {
                        Text("ai.execute.consultation")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canExecute ? Color.indigo : Color(.systemGray4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canExecute)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 16)
                .navigationTitle(Text("ai.menu.consultation.title"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showResult) {
                    if let result = viewModel.result {
                        AIResultView(
                            result: result,
                            referencedBooks: viewModel.referencedBooks,
                            menuType: .consultation,
                            onRetry: {
                                showResult = false
                                showRetryAlert = true
                            }
                        )
                    }
                }
                .alert("ai.result.retryAlert", isPresented: $showRetryAlert) {
                    Button("common.cancel", role: .cancel) {}
                    Button("ai.result.retry") {
                        Task { await executeAI() }
                    }
                }
                .alert("common.error", isPresented: .init(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )) {
                    Button("common.done", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }

                // ローディングオーバーレイ
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
        }
    }

    private var canExecute: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("ai.loading")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray2)))
        }
    }

    private func executeAI() async {
        await viewModel.executeAI(menuType: .consultation, userInput: inputText)
        if viewModel.result != nil {
            showResult = true
        }
    }
}

#Preview {
    AIConsultationView(viewModel: AIViewModel())
}
