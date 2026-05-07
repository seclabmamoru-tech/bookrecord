import Foundation

enum TicketGrantReason: String, Codable {
    case initialGrant
    case monthly
    case planChange
    case purchase

    var localizedLabel: String {
        switch self {
        case .initialGrant: return NSLocalizedString("ticket.history.reason.initial", comment: "")
        case .monthly:      return NSLocalizedString("ticket.history.reason.monthly", comment: "")
        case .planChange:   return NSLocalizedString("ticket.history.reason.planChange", comment: "")
        case .purchase:     return NSLocalizedString("ticket.history.reason.purchase", comment: "")
        }
    }
}

struct TicketHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let amount: Int
    let reason: TicketGrantReason
}

final class TicketHistoryStore {

    static let shared = TicketHistoryStore()

    private let key = "ticketGrantHistory"
    private init() {}

    func entries() -> [TicketHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TicketHistoryEntry].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }

    func record(amount: Int, reason: TicketGrantReason) {
        var current = entries()
        let entry = TicketHistoryEntry(id: UUID(), date: Date(), amount: amount, reason: reason)
        current.insert(entry, at: 0)
        if let encoded = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
