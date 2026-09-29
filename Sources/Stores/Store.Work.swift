public import Store

extension Store {

    public struct Work<Action: Sendable>: Sendable {

        public let cancellation: Store.Cancellation.ID?

        public let body: @Sendable (Store.Send<Action>) async -> Void

        public init(
            cancellation: Store.Cancellation.ID? = nil,
            _ body: @escaping @Sendable (Store.Send<Action>) async -> Void
        ) {
            self.cancellation = cancellation
            self.body = body
        }
    }
}
