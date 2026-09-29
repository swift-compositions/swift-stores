public import Store

extension Store {

    public struct Send<Action: Sendable>: Sendable {
        let deliver: @Sendable (Action) async -> Void

        init(deliver: @escaping @Sendable (Action) async -> Void) {
            self.deliver = deliver
        }
    }
}

extension Store.Send {

    public func callAsFunction(_ action: Action) async {
        await deliver(action)
    }
}
