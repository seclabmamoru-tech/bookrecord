import SwiftUI

/// AI生成結果表示画面
struct AIResultView: View {

    let result: String
    let referencedBooks: [String]
    let menuType: AIMenuType
    let onRetry: () -> Void

    @State private var showReferences = false
    @State private var includePromo = true
    @State private var showShareSheet = false
    @State private var showRetryAlert = false
    @State private var showCopiedFeedback = false

    private var shareText: String {
        if includePromo {
            return result + NSLocalizedString("ai.share.appPromo", comment: "")
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 生成テキスト（マークダウン表示・テキスト選択可）
                AIMarkdownView(text: result)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                // 参照書籍アコーディオン
                if !referencedBooks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation { showReferences.toggle() }
                        } label: {
                            HStack {
                                Text("ai.result.references")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: showReferences ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)

                        if showReferences {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(referencedBooks, id: \.self) { bookTitle in
                                    HStack(spacing: 6) {
                                        Image(systemName: "book.closed")
                                            .font(.caption)
                                            .foregroundColor(.indigo)
                                        Text(bookTitle)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                    )
                }

                // 注意書き
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("ai.result.disclaimer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // アクションボタン群
                VStack(spacing: 12) {
                    // コピーボタン
                    Button {
                        UIPasteboard.general.string = result
                        withAnimation {
                            showCopiedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopiedFeedback = false }
                        }
                    } label: {
                        Label(
                            showCopiedFeedback ? "ai.result.copied" : "ai.result.copy",
                            systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                        )
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(showCopiedFeedback ? Color.green.opacity(0.15) : Color(.systemGray5))
                        .foregroundColor(showCopiedFeedback ? .green : .primary)
                        .cornerRadius(12)
                        .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
                    }

                    // シェアボタン（SNS投稿のみ）
                    if menuType == .sns {
                        VStack(spacing: 8) {
                            Toggle(isOn: $includePromo) {
                                Text("ai.share.includePromo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .toggleStyle(.switch)
                            .tint(.indigo)

                            Button {
                                showShareSheet = true
                            } label: {
                                Label("ai.result.share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }

                    // もう一度試すボタン
                    Button {
                        showRetryAlert = true
                    } label: {
                        Text("ai.result.retry")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Text("tab.ai"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("ai.result.retryAlert", isPresented: $showRetryAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("ai.result.retry") {
                onRetry()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
}

// MARK: - マークダウン表示ビュー

struct AIMarkdownView: View {
    let text: String

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("## ") {
            Text(trimmed.dropFirst(3))
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 2)
        } else if trimmed.hasPrefix("# ") {
            Text(trimmed.dropFirst(2))
                .font(.title3.bold())
                .padding(.top, 12)
                .padding(.bottom, 2)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("・") || trimmed.hasPrefix("• ") {
            let prefix = trimmed.hasPrefix("- ") ? 2 : 1
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                inlineMarkdown(String(trimmed.dropFirst(prefix)))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 3)
        } else if trimmed.isEmpty {
            Color.clear.frame(height: 8)
        } else {
            inlineMarkdown(trimmed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3)
        }
    }

    @ViewBuilder
    private func inlineMarkdown(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .lineSpacing(4)
        } else {
            Text(text)
                .lineSpacing(4)
        }
    }
}

// MARK: - UIActivityViewController ラッパー

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        AIResultView(
            result: "## 悩みへのアドバイス\n\nこれはAIが生成したテキストのサンプルです。\n\n**重要なポイント**として、読書メモに基づいて生成されました。\n\n- アクション1: まず〇〇するだけ\n- アクション2: 次に△△を試す\n\nあなたの「悩み」という言葉を受け取りました。一歩ずつ進んでいきましょう。",
            referencedBooks: ["ゼロ・トゥ・ワン", "影響力の武器"],
            menuType: .consultation,
            onRetry: {}
        )
    }
}
