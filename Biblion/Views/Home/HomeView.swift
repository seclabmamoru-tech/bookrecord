import SwiftUI
import Charts

/// ホーム画面（統計ダッシュボード・読書タイマー）
struct HomeView: View {

    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 統計サマリーカード
                    statsRow

                    // ジャンル別グラフ
                    genreChartCard

                    // 月別読了数グラフ
                    monthlyChartCard

                    // 読書中の書籍
                    currentlyReadingSection

                    // 読書タイマー
                    timerCard

                    // バナー広告
                    BannerAdView()
                        .frame(height: 50)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle(Text("tab.home"))
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            viewModel.fetchBooks()
        }
        .sheet(isPresented: $viewModel.showMemoSheet) {
            TimerMemoSheetView()
                .environmentObject(viewModel)
        }
    }

    // MARK: - 統計サマリー

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "book.closed.fill",
                title: Text("home.stats.totalBooks"),
                value: "\(viewModel.completedBooksCount)",
                unit: Text("common.books")
            )
            StatCard(
                icon: "clock.fill",
                title: Text("home.stats.totalTime"),
                value: viewModel.totalReadingTimeFormatted,
                unit: Text("common.hours")
            )
        }
    }

    // MARK: - ジャンル別グラフ

    private var genreChartCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("home.stats.byGenre", systemImage: "chart.pie.fill")
                    .font(.headline)

                if viewModel.genreData.isEmpty {
                    Text("book.noData")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    genreChart
                        .frame(height: 200)
                }
            }
        }
    }

    @ViewBuilder
    private var genreChart: some View {
        if #available(iOS 17.0, *) {
            Chart {
                ForEach(viewModel.genreData, id: \.0) { item in
                    SectorMark(
                        angle: .value("Count", item.1),
                        innerRadius: .ratio(0.4),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Genre", item.0))
                    .cornerRadius(4)
                }
            }
        } else {
            Chart {
                ForEach(viewModel.genreData, id: \.0) { item in
                    BarMark(
                        x: .value("Genre", item.0),
                        y: .value("Count", item.1)
                    )
                    .foregroundStyle(Color.indigo)
                    .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - 月別読了数グラフ

    private var monthlyChartCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("home.stats.byMonth", systemImage: "chart.bar.fill")
                    .font(.headline)

                Chart {
                    ForEach(viewModel.monthlyData, id: \.0) { item in
                        BarMark(
                            x: .value("Month", item.0),
                            y: .value("Books", item.1)
                        )
                        .foregroundStyle(Color.indigo)
                        .cornerRadius(4)
                    }
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
            }
        }
    }

    // MARK: - 読書中の書籍

    private var currentlyReadingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("home.currentlyReading")
                .font(.headline)
                .padding(.horizontal, 4)

            if viewModel.readingBooks.isEmpty {
                CardContainer {
                    Text("home.noReadingBooks")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.readingBooks, id: \.id) { book in
                            ReadingBookMiniCard(book: book)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - 読書タイマー

    private var timerCard: some View {
        CardContainer {
            VStack(spacing: 16) {
                // 経過時間表示
                Text(viewModel.elapsedTimeString)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundColor(viewModel.isTimerRunning ? .indigo : .primary)

                if viewModel.isTimerRunning {
                    // タイマー起動中
                    if viewModel.readingBooks.count > 1 {
                        Picker("", selection: $viewModel.selectedBook) {
                            ForEach(viewModel.readingBooks, id: \.id) { book in
                                Text(book.title ?? "").tag(book as Book?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack(spacing: 16) {
                        // メモを追加ボタン（タイマー起動中のみ表示）
                        Button {
                            viewModel.showMemoSheet = true
                        } label: {
                            Label("home.timer.addMemo", systemImage: "note.text.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)

                        // タイマー停止ボタン
                        Button(action: viewModel.stopTimer) {
                            Label("home.timer.stop", systemImage: "stop.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                } else {
                    // タイマー停止中
                    Button(action: viewModel.startTimer) {
                        Label("home.timer.start", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(viewModel.readingBooks.isEmpty)

                    if viewModel.readingBooks.isEmpty {
                        Text("home.timer.noBook")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 統計カード

private struct StatCard: View {
    let icon: String
    let title: Text
    let value: String
    let unit: Text

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    title.font(.caption).foregroundColor(.secondary)
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(.indigo)
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title.bold())
                    unit.font(.caption).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 読書中書籍ミニカード

private struct ReadingBookMiniCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageData = book.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 110)
                    .clipped()
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 110)
                    .overlay(Image(systemName: "book.closed").foregroundColor(.gray))
            }
            Text(book.title ?? "")
                .font(.caption2)
                .lineLimit(2)
                .frame(width: 80, alignment: .leading)
        }
    }
}

// MARK: - カードコンテナ

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeViewModel())
}
