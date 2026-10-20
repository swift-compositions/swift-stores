public import Clock_Concurrency
public import Stores

extension Store.Test {

    public final class Runtime<State: Sendable, Action: Sendable>: @unchecked Sendable {

        public let store: Store.Runtime<State, Action>

        public let clock: Clock.Test

        public let redaction: Store.Redaction

        public init(
            state: State,
            update: Store.Update<State, Action, Store.Work<Action>>,
            clock: Clock.Test = Clock.Test(),
            scope: Store.Scope = .inherited,
            redacting redaction: Store.Redaction = .nothing,
            projection: @escaping @Sendable (State) -> Store.View.Node = { _ in .empty },

            isolation: isolated (any Actor)? = #isolation
        ) {
            self.clock = clock
            self.redaction = redaction
            self.store = Store.Runtime(
                state: state,
                update: update,
                scope: scope,
                projection: projection,
                isolation: isolation
            )
        }
    }
}

extension Store.Test.Runtime {

    public var view: Store.View.Node {
        store.view(redacting: redaction)
    }

    public func send(
        _ action: Action,
        becoming expected: Store.View.Node
    ) throws(Store.Test.Failure) {
        store.send(action)
        try require(expected)
    }

    public func require(_ expected: Store.View.Node) throws(Store.Test.Failure) {
        let redacted = expected.redacted(by: redaction)
        let actual = view
        guard actual == redacted else {
            throw .unexpectedView(expected: redacted, actual: actual)
        }
    }
}

extension Store.Test.Runtime {

    public func advance(
        by duration: Duration,

        isolation: isolated (any Actor)? = #isolation
    ) async {
        clock.advance(by: duration)
        await settle(isolation: isolation)
    }

    public func settle(
        turns: Int = 1_000,

        isolation: isolated (any Actor)? = #isolation
    ) async {
        for _ in 0..<turns where !store.isSettled {
            await Task.yield()
        }
    }

    public func finish(
        turns: Int = 1_000,

        isolation: isolated (any Actor)? = #isolation
    ) async throws(Store.Test.Failure) {
        await settle(turns: turns, isolation: isolation)
        guard store.isSettled else {
            throw .unfinishedWork(store.inFlight)
        }
    }
}
