internal import Dictionary_Ordered
internal import Dictionary_Primitive

struct Ledger<Value: Sendable>: ~Copyable {
    private var storage: Dictionary_Primitive.Dictionary<Ticket, Value>.Ordered

    init() {
        self.storage = Dictionary_Primitive.Dictionary<Ticket, Value>.Ordered()
    }
}

extension Ledger {

    typealias Ticket = UInt64
}

extension Ledger {

    var isEmpty: Bool {
        storage.isEmpty
    }

    func holds(_ ticket: Ticket) -> Bool {
        storage.contains(key: ticket)
    }

    mutating func record(_ value: consuming Value, as ticket: Ticket) {
        storage.insert(key: ticket, value: value)
    }

    @discardableResult
    mutating func discard(_ ticket: Ticket) -> Value? {
        storage.removeValue(forKey: ticket)
    }

    var tickets: [Ticket] {
        var result: [Ticket] = []
        storage.forEach { ticket, _ in result.append(ticket) }
        return result
    }

    func forEach(_ body: (Ticket, Value) -> Void) {
        storage.forEach { ticket, value in body(ticket, value) }
    }

    mutating func discard() {
        storage.removeAll()
    }
}
