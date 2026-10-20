import Clock_Concurrency
import Testing

@testable import Stores_Testing

extension Store.Test {
    @Suite struct Suites {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Store.Test.Suites {
    enum Action: Sendable, Equatable {
        case increment
        case set(Int)
        case load
        case linger
    }

    static var counting: Store.Update<Int, Action, Store.Work<Action>> {
        .init { count, action in
            switch action {
            case .increment:
                count += 1
                return .none

            case .set(let value):
                count = value
                return .none

            case .load:
                return .run(
                    Store.Work(cancellation: "load") { send in
                        await send(.set(41))
                    }
                )

            case .linger:
                return .run(
                    Store.Work(cancellation: "linger") { _ in

                        try? await Task.sleep(for: .seconds(60))
                    }
                )
            }
        }
    }

    static func view(_ count: Int) -> Store.View.Node {
        .init(fields: [.init("count", "\(count)")])
    }

    static func store(
        redacting redaction: Store.Redaction = .nothing
    ) -> Store.Test.Runtime<Int, Action> {
        .init(
            state: 0,
            update: counting,
            redacting: redaction,
            projection: view
        )
    }
}

extension Store.Test.Suites.Unit {
    @Test func `a step that states the right view passes`() throws {
        let store = Store.Test.Suites.store()
        try store.send(.increment, becoming: .init(fields: [.init("count", "1")]))
    }

    @Test func `a step that states the wrong view fails, and names both`() {
        let store = Store.Test.Suites.store()

        #expect {
            try store.send(.increment, becoming: .init(fields: [.init("count", "9")]))
        } throws: { error in
            guard case .unexpectedView(let expected, let actual) = error as? Store.Test.Failure
            else {
                return false
            }
            return expected.fields.first?.value == "9" && actual.fields.first?.value == "1"
        }
    }

    @Test func `a withheld field cannot make a step fail`() throws {
        let store = Store.Test.Suites.store(redacting: .withholding("count"))

        try store.send(.increment, becoming: .init(fields: [.init("count", "anything")]))
    }
}

extension Store.Test.Suites.Integration {
    @Test func `finishing succeeds once work has fed its result back`() async throws {
        let store = Store.Test.Suites.store()
        store.store.send(.load)
        try await store.finish()
        try store.require(.init(fields: [.init("count", "41")]))
    }

    @Test func `finishing fails while work is still in flight, and names it`() async {
        let store = Store.Test.Suites.store()
        store.store.send(.linger)

        await #expect {
            try await store.finish(turns: 4)
        } throws: { error in
            guard case .unfinishedWork(let names) = error as? Store.Test.Failure else {
                return false
            }
            return names.map(\.name) == ["linger"]
        }
    }

    @Test func `cancelling in-flight work lets the test finish`() async throws {
        let store = Store.Test.Suites.store()
        store.store.send(.linger)
        store.store.cancel("linger")
        try await store.finish()
    }
}
