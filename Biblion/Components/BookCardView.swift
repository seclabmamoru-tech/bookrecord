import SwiftUI

private let appStoreURL = "https://apps.apple.com/jp/app/biblion/id6759857926"

/// 書籍一覧グリッド用のカードビュー
struct BookCardView: View {

    @ObservedObject var book: Book
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 表紙画像 + 共有ボタン
            coverImage
                .frame(height: 160)
                .clipped()
                .cornerRadius(10)
                .overlay(alignment: .topTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(6)
                }

            // タイトル
            Text(book.title ?? "")
                .font(.subheadline.bold())
                .lineLimit(2)
                .foregroundColor(.primary)

            // 著者
            if let author = book.author, !author.isEmpty {
                Text(author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // ステータスバッジ
            HStack(spacing: 4) {
                StatusBadge(status: book.status ?? "want")
                let memoCount = book.memos?.count ?? 0
                if memoCount > 0 {
                    Text(String(format: NSLocalizedString("book.memoCount", comment: ""), memoCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .sheet(isPresented: $showShareSheet) {
            ActivityShareView(items: shareItems)
        }
    }

    private var shareItems: [Any] {
        ["\(book.title ?? "")\n\(appStoreURL)"]
    }

    // MARK: - 表紙画像

    @ViewBuilder
    private var coverImage: some View {
        if let imageData = book.coverImageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            // プレースホルダー
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.3), Color.indigo.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.indigo.opacity(0.5))
            }
        }
    }
}

// MARK: - UIActivityViewController ラッパー

private struct ActivityShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let book = Book()
    return BookCardView(book: book)
        .frame(width: 180)
        .padding()
}
