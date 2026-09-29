public import Store

extension Store.Event {

    struct Receiver: Sendable {

        let accept: @Sendable (any Sendable) -> Store.Event.Disposition

        init(accept: @escaping @Sendable (any Sendable) -> Store.Event.Disposition) {
            self.accept = accept
        }
    }
}

extension Store.Event.Receiver {

    static func of<E: Sendable>(
        _ type: E.Type,
        _ handle: @escaping @Sendable (E) -> Store.Event.Disposition
    ) -> Self {
        .init { event in
            guard let event = event as? E else { return .ignored }
            return handle(event)
        }
    }
}
