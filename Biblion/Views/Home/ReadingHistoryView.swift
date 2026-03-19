import SwiftUI
import CoreData

/// 読書履歴一覧画面
struct ReadingHistoryView: View {

    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: ReadingSession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ReadingSession.date, ascending: false)]
    ) private var sessions: FetchedResults<ReadingSession>

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sessions, id: \.id) { session in
                            sessionRow(session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(Text("home.readingHistory.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("home.readingHistory.empty")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 行

    private func sessionRow(_ session: ReadingSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.book?.title ?? "")
                    .font(.body)
                    .lineLimit(2)
                if let date = session.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(formatDuration(Int(session.durationMinutes)))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.indigo)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 時間フォーマット（秒→h/m/s）

    private func formatDuration(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }
}
