import SwiftUI

/// メモ追加・編集画面（140文字制限）
struct AddEditMemoView: View {

    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    let book: Book
    let memo: Memo? // nil の場合は新規追加

    @State private var memoText = ""

    private let maxLength = 140

    private var isEditing: Bool { memo != nil }
    private var remaining: Int { maxLength - memoText.count }
    private var isOverLimit: Bool { memoText.count >= maxLength }

    var body: some View {
        NavigationStack {
            VStack(alignment: .trailing, spacing: 8) {
                // テキストエディター
                TextEditor(text: $memoText)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isOverLimit ? Color.red : Color(.systemGray4), lineWidth: 1)
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
                        // 140文字を超えた場合は入力を制限
                        if newValue.count > maxLength {
                            memoText = String(newValue.prefix(maxLength))
                        }
                    }

                // 文字数カウンター
                Text(String(format: NSLocalizedString("memo.charCount", comment: ""), memoText.count))
                    .font(.caption)
                    .foregroundColor(isOverLimit ? .red : .secondary)

                Spacer()
            }
            .padding()
            .navigationTitle(isEditing ? Text("common.edit") : Text("book.addMemo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("memo.save") { saveMemo() }
                        .bold()
                        .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let memo = memo {
                memoText = memo.content ?? ""
            }
        }
    }

    // MARK: - 保存

    private func saveMemo() {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let memo = memo {
            // 既存メモを更新
            memo.content = trimmed
            viewModel.updateMemo(memo)
        } else {
            // 新規メモを追加
            viewModel.addMemo(content: trimmed, to: book)
        }
        dismiss()
    }
}

#Preview {
    AddEditMemoView(book: Book(), memo: nil)
        .environmentObject(LibraryViewModel())
}
