public import Store

extension Store {

    public struct Values: Sendable {
        var entries: [Store.Values.Entry]

        public init() {
            self.entries = []
        }
    }
}

extension Store.Values {

    public var isEmpty: Bool {
        entries.isEmpty
    }

    public func value<K: Store.Key.`Protocol`>(for key: K.Type) -> K.Value? {
        let identity = ObjectIdentifier(key)
        for entry in entries where entry.identity == identity {
            return entry.value as? K.Value
        }
        return nil
    }

    public mutating func set<K: Store.Key.`Protocol`>(_ key: K.Type, to value: K.Value) {
        let identity = ObjectIdentifier(key)
        let entry = Store.Values.Entry(identity: identity, value: value)
        for index in entries.indices where entries[index].identity == identity {
            entries[index] = entry
            return
        }
        entries.append(entry)
    }

    public mutating func clear<K: Store.Key.`Protocol`>(_ key: K.Type) {
        let identity = ObjectIdentifier(key)
        entries.removeAll { $0.identity == identity }
    }
}
