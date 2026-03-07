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
            AddTaskFromAIView(suggestedTitle: String(result.prefix(50)))
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
    let suggestedTitle: String
    @State private var taskTitle: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskViewModel: TaskViewModel

    init(suggestedTitle: String) {
        self.suggestedTitle = suggestedTitle
        _taskTitle = State(initialValue: suggestedTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("task.add")) {
                    TextField("task.add", text: $taskTitle)
                }
            }
            .navigationTitle(Text("ai.result.addTodo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("memo.save") {
                        if !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            let tasks = CoreDataManager.shared.fetchTasks()
                            taskViewModel.addTask(title: taskTitle.trimmingCharacters(in: .whitespaces))
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
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
