import SwiftUI

/// タイマー起動中のメモ追加シート
struct TimerMemoSheetView: View {

    @EnvironmentObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var memoText = ""

    private let maxLength = 140

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 対象書籍が複数の場合は選択 Picker を表示
                if viewModel.readingBooks.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("home.timer.selectBook")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $viewModel.selectedBook) {
                            ForEach(viewModel.readingBooks, id: \.id) { book in
                                Text(book.title ?? "").tag(book as Book?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                }

                // メモ入力
                VStack(alignment: .trailing, spacing: 4) {
                    TextEditor(text: $memoText)
                        .frame(minHeight: 180)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if memoText.isEmpty {
                                    Text("memo.placeholder")
                                        .foregroundColor(.secondary)
                                        .padding(12)
                                        .allowsHitTesting(false)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        )
                        .onChange(of: memoText) { newValue in
                            if newValue.count > maxLength {
                                memoText = String(newValue.prefix(maxLength))
                            }
                        }

                    // 文字数カウンター
                    Text(String(format: NSLocalizedString("memo.charCount", comment: ""), memoText.count))
                        .font(.caption)
                        .foregroundColor(memoText.count >= maxLength ? .red : .secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(Text("home.timer.addMemo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("memo.save") {
                        saveMemo()
                    }
                    .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
        }
    }

    // MARK: - メモ保存

    private func saveMemo() {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let book = viewModel.selectedBook else { return }
        viewModel.addMemo(content: trimmed, to: book)
        dismiss()
    }
}

#Preview {
    TimerMemoSheetView()
        .environmentObject(HomeViewModel())
}
