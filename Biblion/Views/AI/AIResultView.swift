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
    @State private var showAddTaskSheet = false
    @State private var showRetryAlert = false

    private var shareText: String {
        if includePromo {
            return result + NSLocalizedString("ai.share.appPromo", comment: "")
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 生成テキスト
                Text(result)
                    .font(.body)
                    .lineSpacing(6)
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
                    // Todoに追加（悩み相談のみ）
                    if menuType == .consultation {
                        Button {
                            showAddTaskSheet = true
                        } label: {
                            Label("ai.result.addTodo", systemImage: "plus.circle")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo.opacity(0.1))
                                .foregroundColor(.indigo)
                                .cornerRadius(12)
                        }
                    }

                    // コピーボタン
                    Button {
                        UIPasteboard.general.string = result
                    } label: {
                        Label("ai.result.copy", systemImage: "doc.on.doc")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
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
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskFromAIView(result: result)
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

// MARK: - AI結果からタスク追加

private struct AddTaskFromAIView: View {
    let result: String
    @State private var actions: [String]
    @State private var selections: [Bool]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskViewModel: TaskViewModel

    init(result: String) {
        self.result = result
        let parsed = Self.parseActions(from: result)
        _actions = State(initialValue: parsed)
        _selections = State(initialValue: Array(repeating: false, count: parsed.count))
    }

    /// AIの出力テキストから箇条書き・番号付きのアクション行を抽出する
    static func parseActions(from text: String) -> [String] {
        let bulletPrefixes = ["- ", "・", "• ", "● ", "◆ ", "▶ ", "✅ ", "→ "]
        return text.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for prefix in bulletPrefixes {
                if trimmed.hasPrefix(prefix) {
                    let content = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    return content.isEmpty ? nil : content
                }
            }
            // 「1. 」「1） 」「① 」形式
            if trimmed.range(of: #"^\d+[\.）\)]\s+"#, options: .regularExpression) != nil ||
               trimmed.range(of: #"^[①-⑳]\s*"#, options: .regularExpression) != nil {
                let content = trimmed.replacingOccurrences(of: #"^\d+[\.）\)]\s+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^[①-⑳]\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                return content.isEmpty ? nil : content
            }
            return nil
        }
    }

    private var allSelected: Bool { selections.allSatisfy { $0 } }
    private var anySelected: Bool { selections.contains(true) }

    var body: some View {
        NavigationStack {
            Group {
                if actions.isEmpty {
                    // アクション抽出できなかった場合のフォールバック
                    ContentUnavailableView(
                        "ai.result.addTodo.noActions",
                        systemImage: "text.badge.xmark",
                        description: Text("ai.result.addTodo.noActionsDescription")
                    )
                } else {
                    List {
                        Section {
                            ForEach(actions.indices, id: \.self) { i in
                                Button {
                                    selections[i].toggle()
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: selections[i] ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selections[i] ? .indigo : Color(.systemGray3))
                                            .font(.title3)
                                        Text(actions[i])
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack {
                                Text("ai.result.addTodo.selectActions")
                                Spacer()
                                Button(allSelected ? "common.deselectAll" : "common.selectAll") {
                                    let next = !allSelected
                                    selections = selections.map { _ in next }
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text("ai.result.addTodo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.add") {
                        zip(actions, selections)
                            .filter(\.1)
                            .map(\.0)
                            .forEach { taskViewModel.addTask(title: $0) }
                        dismiss()
                    }
                    .bold()
                    .disabled(!anySelected)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIResultView(
            result: "これはAIが生成したテキストのサンプルです。読書メモに基づいて生成されました。",
            referencedBooks: ["ゼロ・トゥ・ワン", "影響力の武器"],
            menuType: .consultation,
            onRetry: {}
        )
    }
}
