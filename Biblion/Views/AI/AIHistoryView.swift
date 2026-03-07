import SwiftUI

/// AI利用履歴一覧画面
struct AIHistoryView: View {

    @State private var histories: [AIHistory] = []
    @State private var selectedHistory: AIHistory?

    var body: some View {
        Group {
            if histories.isEmpty {
                ContentUnavailableView(
                    "ai.history.empty",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("ai.history.emptyDescription")
                )
            } else {
                List(histories, id: \.id) { history in
                    Button {
                        selectedHistory = history
                    } label: {
                        AIHistoryRow(history: history)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(Text("ai.history.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            histories = CoreDataManager.shared.fetchAIHistory()
        }
        .sheet(item: $selectedHistory) { history in
            AIHistoryDetailView(history: history)
        }
    }
}

// MARK: - 履歴行

private struct AIHistoryRow: View {
    let history: AIHistory

    private var menuLabel: (icon: String, text: String) {
        switch history.menuType {
        case "consultation": return ("brain.head.profile", "ai.menu.consultation.title")
        case "summary":      return ("book.closed.fill",   "ai.menu.summary.title")
        case "sns":          return ("square.and.pencil",  "ai.menu.sns.title")
        default:             return ("sparkles",           "ai.menu.title")
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: menuLabel.icon)
                .font(.title3)
                .foregroundColor(.indigo)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(menuLabel.text))
                    .font(.subheadline.bold())
                Text(history.inputText ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let date = history.createdAt {
                Text(date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 履歴詳細

private struct AIHistoryDetailView: View {
    let history: AIHistory
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    private var menuTitle: String {
        switch history.menuType {
        case "consultation": return NSLocalizedString("ai.menu.consultation.title", comment: "")
        case "summary":      return NSLocalizedString("ai.menu.summary.title", comment: "")
        case "sns":          return NSLocalizedString("ai.menu.sns.title", comment: "")
        default:             return NSLocalizedString("ai.menu.title", comment: "")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 日時・メニュー種別
                    HStack {
                        Text(menuTitle)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.1))
                            .foregroundColor(.indigo)
                            .clipShape(Capsule())

                        Spacer()

                        if let date = history.createdAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 入力内容
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ai.history.input")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(history.inputText ?? "")
                            .font(.subheadline)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                    }

                    // 出力結果
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ai.history.output")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(history.outputText ?? "")
                            .font(.body)
                            .lineSpacing(6)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                    }

                    // アクション
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = history.outputText
                        } label: {
                            Label("ai.result.copy", systemImage: "doc.on.doc")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("ai.result.share", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(Text("ai.history.detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [history.outputText ?? ""])
            }
        }
    }
}
