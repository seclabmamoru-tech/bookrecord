import SwiftUI

/// ライブラリ画面（書籍一覧グリッド）
struct LibraryView: View {

    @EnvironmentObject var viewModel: LibraryViewModel
    @State private var showAddBook = false

    // グリッド列定義（2列）
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // フィルターバー
                filterBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))

                // 書籍グリッド
                if viewModel.filteredBooks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.filteredBooks, id: \.id) { book in
                                NavigationLink(destination: BookDetailView(book: book)) {
                                    BookCardView(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }

                // バナー広告
                BannerAdView()
                    .frame(height: 50)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text("tab.library"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            viewModel.fetchBooks()
        }
    }

    // MARK: - フィルターバー

    private var filterBar: some View {
        VStack(spacing: 8) {
            // ステータスフィルター（SegmentedControl）
            Picker("", selection: $viewModel.selectedStatus) {
                Text("library.filter.all").tag("all")
                Text("library.filter.want").tag("want")
                Text("library.filter.reading").tag("reading")
                Text("library.filter.completed").tag("completed")
            }
            .pickerStyle(.segmented)

            // ジャンルフィルター
            HStack {
                Text("book.genre")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $viewModel.selectedGenre) {
                    Text("library.filter.all").tag("all")
                    ForEach(LibraryViewModel.genres, id: \.self) { genre in
                        Text(genre).tag(genre)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("library.empty")
                .foregroundColor(.secondary)
            Button {
                showAddBook = true
            } label: {
                Label("library.addBook", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
            Spacer()
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryViewModel())
}
