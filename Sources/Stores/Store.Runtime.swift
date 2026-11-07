public import Observations
public import Store

extension Store {

    @Observable
    public final class Runtime<State: Sendable, Action: Sendable>: @unchecked Sendable {

        public var state: State

        public let update: Store.Update<State, Action, Store.Work<Action>>

        public let scope: Store.Scope

        public let isolation: (any Actor)?

        let projection: @Sendable (State) -> Store.View.Node

        var _features: Registry.Mounts<Store.Feature.Mount>
        var _pending: Mailbox<Action>
        var _inFlight: Ledger<Store.Work<Action>.Record>
        var _nextTicket: UInt64
        var _reducing: Bool

        public init(
            state: State,
            update: Store.Update<State, Action, Store.Work<Action>>,
            scope: Store.Scope = .inherited,
            projection: @escaping @Sendable (State) -> Store.View.Node = { _ in .empty },

            isolation: isolated (any Actor)? = #isolation
        ) {

            self._state = state
            self.update = update
            self.scope = scope
            self.projection = projection
            self.isolation = isolation
            self._features = Registry.Mounts()
            self._pending = Mailbox()
            self._inFlight = Ledger()
            self._nextTicket = 0
            self._reducing = false
        }
    }
}
