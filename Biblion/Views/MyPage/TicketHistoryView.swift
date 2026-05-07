import SwiftUI

struct TicketHistoryView: View {

    private let entries = TicketHistoryStore.shared.entries()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("ticket.history.empty", comment: ""),
                        systemImage: "ticket",
                        description: Text("ticket.history.empty.description")
                    )
                } else {
                    List(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.reason.localizedLabel)
                                    .font(.subheadline.bold())
                                Text(dateFormatter.string(from: entry.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: NSLocalizedString("ticket.history.amount", comment: ""), entry.amount))
                                .font(.subheadline.bold())
                                .foregroundColor(.indigo)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle(Text("ticket.history.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
