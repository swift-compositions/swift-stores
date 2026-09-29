public import Store

extension Store.Feature {

    public struct Mount: Sendable {

        var values: Store.Values

        var contributions: Store.Values

        var receivers: [Store.Event.Receiver]

        var teardown: [@Sendable () -> Void]

        var render: (@Sendable () -> Store.View.Node)?

        public init() {
            self.values = Store.Values()
            self.contributions = Store.Values()
            self.receivers = []
            self.teardown = []
            self.render = nil
        }
    }
}

extension Store.Feature.Mount {

    public mutating func supply<K: Store.Key.`Protocol`>(_ key: K.Type, _ value: K.Value) {
        values.set(key, to: value)
    }

    public mutating func contribute<K: Store.Key.Aggregate>(_ key: K.Type, _ value: K.Value) {
        contributions.set(key, to: value)
    }

    public mutating func on<E: Sendable>(
        _ type: E.Type,
        _ handle: @escaping @Sendable (E) -> Store.Event.Disposition
    ) {
        receivers.append(.of(type, handle))
    }

    public mutating func onDismount(_ body: @escaping @Sendable () -> Void) {
        teardown.append(body)
    }

    public mutating func renders(_ body: @escaping @Sendable () -> Store.View.Node) {
        render = body
    }
}
