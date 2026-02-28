import SwiftUI
import PhotosUI

/// 書籍追加・編集画面
struct AddBookView: View {

    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    // 編集対象の書籍（nil の場合は新規追加）
    var book: Book?

    // MARK: - フォームフィールド

    @State private var title = ""
    @State private var author = ""
    @State private var genre = "ビジネス"
    @State private var status = "want"
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var coverImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var isEditing: Bool { book != nil }

    var body: some View {
        NavigationStack {
            Form {
                // 書籍情報セクション
                Section {
                    TextField(LocalizedStringKey("book.title"), text: $title)
                    TextField(LocalizedStringKey("book.author"), text: $author)

                    Picker("book.genre", selection: $genre) {
                        ForEach(LibraryViewModel.genres, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }

                    Picker("book.status", selection: $status) {
                        Text("library.filter.want").tag("want")
                        Text("library.filter.reading").tag("reading")
                        Text("library.filter.completed").tag("completed")
                    }
                } header: {
                    Text("library.addBook")
                }

                // 読書期間セクション
                Section {
                    Toggle(isOn: $hasStartDate) {
                        Text("book.startDate")
                    }
                    if hasStartDate {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    Toggle(isOn: $hasEndDate) {
                        Text("book.endDate")
                    }
                    .onChange(of: hasEndDate) { enabled in
                        if enabled { status = "completed" }
                    }
                    if hasEndDate {
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                } header: {
                    Text("book.readingPeriod")
                }

                // 表紙画像セクション
                Section {
                    HStack {
                        // 現在の表紙画像プレビュー
                        if let image = coverImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 80)
                                .clipped()
                                .cornerRadius(6)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 80)
                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            // フォトライブラリから選択
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images
                            ) {
                                Text("book.selectFromLibrary")
                                    .font(.caption)
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                loadSelectedPhoto(newItem)
                            }

                            if coverImage != nil {
                                Button(role: .destructive) {
                                    coverImage = nil
                                } label: {
                                    Text("common.delete")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } header: {
                    Text("book.coverImage")
                }
            }
            .navigationTitle(isEditing ? Text("common.edit") : Text("library.addBook"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("memo.save") { saveBook() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("common.error", isPresented: $showAlert) {
                Button("common.done", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear { loadBookData() }
    }

    // MARK: - データ読み込み

    private func loadBookData() {
        guard let book = book else { return }
        title = book.title ?? ""
        author = book.author ?? ""
        genre = book.genre ?? "ビジネス"
        status = book.status ?? "want"

        if let start = book.startDate {
            hasStartDate = true
            startDate = start
        }
        if let end = book.endDate {
            hasEndDate = true
            endDate = end
        }
        if let imageData = book.coverImageData {
            coverImage = UIImage(data: imageData)
        }
    }

    // MARK: - フォト読み込み

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let uiImage = UIImage(data: data) {
                        coverImage = uiImage
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - 保存

    private func saveBook() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let imageData = coverImage?.jpegData(compressionQuality: 0.8)

        if let book = book {
            // 既存書籍を更新
            book.title = trimmedTitle
            book.author = author.trimmingCharacters(in: .whitespaces)
            book.genre = genre
            book.status = status
            book.startDate = hasStartDate ? startDate : nil
            book.endDate = hasEndDate ? endDate : nil
            book.coverImageData = imageData
            viewModel.updateBook(book)
        } else {
            // 新規書籍を追加
            viewModel.addBook(
                title: trimmedTitle,
                author: author.trimmingCharacters(in: .whitespaces),
                genre: genre,
                status: status,
                startDate: hasStartDate ? startDate : nil,
                endDate: hasEndDate ? endDate : nil,
                coverImageData: imageData
            )
        }
        dismiss()
    }
}

#Preview {
    AddBookView()
        .environmentObject(LibraryViewModel())
}
