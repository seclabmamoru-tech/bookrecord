import SwiftUI
import UIKit

/// AI生成結果表示画面
struct AIResultView: View {

    let result: String
    let referencedBooks: [String]
    let menuType: AIMenuType
    let onRetry: () -> Void

    @State private var showReferences = false
    @State private var showRetryAlert = false
    @State private var showCopiedFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 生成テキスト（UITextViewベースでブラウザ的テキスト選択が可能）
                SelectableMarkdownView(text: result)
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
                    // 全文コピーボタン
                    Button {
                        UIPasteboard.general.string = result
                        withAnimation { showCopiedFeedback = true }
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
            Button("ai.result.retry") { onRetry() }
        }
    }
}

// MARK: - ブラウザ的テキスト選択が可能なマークダウン表示

struct SelectableMarkdownView: View {
    let text: String
    @State private var contentHeight: CGFloat = 100

    var body: some View {
        GeometryReader { geo in
            MarkdownTextViewRepresentable(
                text: text,
                availableWidth: geo.size.width,
                contentHeight: $contentHeight
            )
        }
        .frame(height: contentHeight)
    }
}

private struct MarkdownTextViewRepresentable: UIViewRepresentable {
    let text: String
    let availableWidth: CGFloat
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let newAttr = buildAttributedString(text)
        if tv.attributedText?.string != newAttr.string {
            tv.attributedText = newAttr
        }
        DispatchQueue.main.async {
            let w = max(availableWidth, 1)
            let h = tv.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
            if abs(h - contentHeight) > 1 { contentHeight = h }
        }
    }

    // MARK: NSAttributedString マークダウン変換

    private func buildAttributedString(_ raw: String) -> NSAttributedString {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
        let label = UIColor.label
        let secondary = UIColor.secondaryLabel
        let result = NSMutableAttributedString()
        let lines = raw.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineAttr: NSAttributedString

            if trimmed.hasPrefix("## ") {
                let ps = NSMutableParagraphStyle()
                ps.paragraphSpacingBefore = 12
                ps.paragraphSpacing = 2
                lineAttr = NSAttributedString(
                    string: String(trimmed.dropFirst(3)),
                    attributes: [.font: headlineFont, .foregroundColor: label, .paragraphStyle: ps])
            } else if trimmed.hasPrefix("# ") {
                let titleFont = headlineFont.boldVariant()
                let ps = NSMutableParagraphStyle()
                ps.paragraphSpacingBefore = 12
                lineAttr = NSAttributedString(
                    string: String(trimmed.dropFirst(2)),
                    attributes: [.font: titleFont, .foregroundColor: label, .paragraphStyle: ps])
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("・") {
                let offset = trimmed.hasPrefix("・") ? 1 : 2
                let content = String(trimmed.dropFirst(offset))
                let bullet = NSAttributedString(
                    string: "•  ",
                    attributes: [.font: bodyFont, .foregroundColor: secondary])
                let body = inlineMarkdown(content, font: bodyFont, color: label)
                let combined = NSMutableAttributedString(attributedString: bullet)
                combined.append(body)
                lineAttr = combined
            } else if trimmed.isEmpty {
                lineAttr = NSAttributedString(string: "")
            } else {
                lineAttr = inlineMarkdown(trimmed, font: bodyFont, color: label)
            }

            result.append(lineAttr)
            if i < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        return result
    }

    private func inlineMarkdown(_ text: String, font: UIFont, color: UIColor) -> NSAttributedString {
        if let attr = try? AttributedString(markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            let ns = NSMutableAttributedString(attr)
            let range = NSRange(location: 0, length: ns.length)
            ns.enumerateAttributes(in: range, options: []) { attrs, subrange, _ in
                if attrs[.font] == nil { ns.addAttribute(.font, value: font, range: subrange) }
                if attrs[.foregroundColor] == nil { ns.addAttribute(.foregroundColor, value: color, range: subrange) }
            }
            return ns
        }
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    }
}

private extension UIFont {
    func boldVariant() -> UIFont {
        guard let desc = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: desc, size: pointSize)
    }
}

// MARK: - UIActivityViewController ラッパー（履歴詳細で使用）

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
            result: "## 悩みへのアドバイス\n\nこれはAIが生成したテキストです。\n\n**重要なポイント**として、読書メモに基づきました。\n\n- アクション1: まず〇〇するだけ\n- アクション2: 次に△△を試す\n\nあなたの「悩み」を受け取りました。",
            referencedBooks: ["ゼロ・トゥ・ワン", "影響力の武器"],
            menuType: .consultation,
            onRetry: {}
        )
    }
}
