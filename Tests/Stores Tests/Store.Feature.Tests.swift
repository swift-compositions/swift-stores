import Algebra
import Synchronization
import Testing

@testable import Stores

extension Store.Feature {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Store.Feature.Test {
    enum Action: Sendable, Equatable {
        case increment
        case set(Int)
        case load
        case loadSlowly
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

            case .loadSlowly:
                return .run(
                    Store.Work(cancellation: "slow") { _ in

                        try? await Task.sleep(for: .seconds(60))
                    }
                )
            }
        }
    }

    static func view(_ count: Int) -> Store.View.Node {
        .init(fields: [.init("count", "\(count)")])
    }

    enum Theme: Store.Key.`Protocol` {}

    enum Warnings: Store.Key.Aggregate {}

    struct Saved: Sendable, Equatable {
        let id: Int
    }

    struct Refresh: Sendable, Equatable {
        let id: Int
    }
}

extension Store.Feature.Test.Theme {
    static var initial: String { "system" }
}

extension Store.Feature.Test.Warnings {
    typealias Value = [String]

    static var aggregation: Algebra.Monoid<[String]> {
        .init(identity: [], combining: +)
    }
}

extension Store.Feature.Test.Unit {
    @Test func `sending an action advances the state`() {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        runtime.send(.increment)
        runtime.send(.increment)
        #expect(runtime.state == 2)
    }

    @Test func `an effect that only sends is folded in without leaving work in flight`() {
        let update = Store.Update<
            Int, Store.Feature.Test.Action, Store.Work<Store.Feature.Test.Action>
        > { count, action in
            guard case .increment = action else {
                count = 0
                return .none
            }
            count += 1
            return count < 3 ? .send(.increment) : .none
        }

        let runtime = Store.Runtime(state: 0, update: update)
        runtime.send(.increment)

        #expect(runtime.state == 3)
        #expect(runtime.isSettled)
    }
}

extension Store.Feature.Test.Unit {
    @Test func `a mounted feature is addressable by its path`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        let detail = try runtime.mount("detail", under: root)

        #expect(runtime.path(to: detail) == ["detail"])
        #expect(runtime.feature(at: ["detail"]) == detail)
        #expect(runtime.children(of: root).map(\.name) == ["detail"])
    }

    @Test func `teardown runs deepest first`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let order = Store.Feature.Test.Order()

        let root = try runtime.mountRoot()
        let parent = try runtime.mount("parent", under: root) { mount in
            mount.onDismount { order.record("parent") }
        }
        _ = try runtime.mount("child", under: parent) { mount in
            mount.onDismount { order.record("child") }
        }

        try runtime.dismount(parent)
        #expect(order.recorded == ["child", "parent"])
    }

    @Test func `a second feature cannot take a name already mounted`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        _ = try runtime.mount("detail", under: root)

        #expect(throws: Store.Error.nameOccupied("detail")) {
            _ = try runtime.mount("detail", under: root)
        }
    }
}

extension Store.Feature.Test.`Edge Case` {
    @Test func `a handle held past a dismount resolves to nothing, not to its replacement`() throws
    {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()

        let first = try runtime.mount("detail", under: root)
        try runtime.dismount(first)

        let second = try runtime.mount("detail", under: root)

        #expect(runtime.isMounted(second))
        #expect(!runtime.isMounted(first))
        #expect(first != second)
        #expect(runtime.path(to: first) == nil)
    }

    @Test func `dismounting takes the whole subtree with it`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        let parent = try runtime.mount("parent", under: root)
        let child = try runtime.mount("child", under: parent)

        try runtime.dismount(parent)

        #expect(!runtime.isMounted(parent))
        #expect(!runtime.isMounted(child))
    }

    @Test func `dismounting twice is refused rather than silently accepted`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        let detail = try runtime.mount("detail", under: root)

        try runtime.dismount(detail)
        #expect(throws: Store.Error.notMounted) {
            try runtime.dismount(detail)
        }
    }
}

extension Store.Feature.Test.Unit {
    @Test func `a value resolves from the nearest ancestor that supplied one`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot { $0.supply(Store.Feature.Test.Theme.self, "dark") }
        let middle = try runtime.mount("middle", under: root)
        let leaf = try runtime.mount("leaf", under: middle)

        #expect(runtime.value(Store.Feature.Test.Theme.self, at: leaf) == "dark")

        try runtime.supply(Store.Feature.Test.Theme.self, "high-contrast", at: middle)
        #expect(runtime.value(Store.Feature.Test.Theme.self, at: leaf) == "high-contrast")
    }

    @Test func `a key with nothing supplied anywhere answers with its initial value`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        #expect(runtime.value(Store.Feature.Test.Theme.self, at: root) == "system")
    }

    @Test func `contributions from a subtree combine under the key's monoid`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot {
            $0.contribute(Store.Feature.Test.Warnings.self, ["root"])
        }
        let first = try runtime.mount("first", under: root) {
            $0.contribute(Store.Feature.Test.Warnings.self, ["first"])
        }
        _ = try runtime.mount("second", under: root) {
            $0.contribute(Store.Feature.Test.Warnings.self, ["second"])
        }
        _ = try runtime.mount("deep", under: first) {
            $0.contribute(Store.Feature.Test.Warnings.self, ["deep"])
        }

        #expect(
            runtime.aggregate(Store.Feature.Test.Warnings.self, from: root)
                == ["root", "first", "second", "deep"]
        )
    }

    @Test func `aggregating with no contributors is the monoid identity`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        #expect(runtime.aggregate(Store.Feature.Test.Warnings.self, from: root) == [])
    }
}

extension Store.Feature.Test.Integration {
    @Test func `an event bubbles until an ancestor consumes it`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let order = Store.Feature.Test.Order()

        let root = try runtime.mountRoot { mount in
            mount.on(Store.Feature.Test.Saved.self) { _ in
                order.record("root")
                return .consumed
            }
        }
        let middle = try runtime.mount("middle", under: root) { mount in
            mount.on(Store.Feature.Test.Saved.self) { _ in
                order.record("middle")
                return .ignored
            }
        }
        let leaf = try runtime.mount("leaf", under: middle)

        #expect(runtime.raise(Store.Feature.Test.Saved(id: 7), from: leaf))
        #expect(order.recorded == ["middle", "root"])
    }

    @Test func `an ancestor may transform an event into a different one`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let seen = Store.Feature.Test.Order()

        let root = try runtime.mountRoot { mount in
            mount.on(Store.Feature.Test.Refresh.self) { refresh in
                seen.record("refresh(\(refresh.id))")
                return .consumed
            }
        }
        let middle = try runtime.mount("middle", under: root) { mount in
            mount.on(Store.Feature.Test.Saved.self) { saved in
                .transformed(Store.Feature.Test.Refresh(id: saved.id))
            }
        }
        let leaf = try runtime.mount("leaf", under: middle)

        #expect(runtime.raise(Store.Feature.Test.Saved(id: 7), from: leaf))
        #expect(seen.recorded == ["refresh(7)"])
    }

    @Test func `an event nobody consumes reports that it was not consumed`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        let leaf = try runtime.mount("leaf", under: root)

        #expect(!runtime.raise(Store.Feature.Test.Saved(id: 7), from: leaf))
    }
}

extension Store.Feature.Test.Integration {
    @Test func `a spawned subtree reduces its own actions and the parent's state is untouched`()
        throws
    {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()

        let child = try runtime.spawn(
            "child",
            under: root,
            state: 0,
            update: Store.Feature.Test.counting
        )

        child.send(.increment)
        child.send(.increment)

        #expect(child.state == 2)
        #expect(runtime.state == 0)
    }

    @Test func `dismounting the parent feature stops the spawned subtree's work`() async throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()

        let child = try runtime.spawn(
            "child",
            under: root,
            state: 0,
            update: Store.Feature.Test.counting
        )

        child.send(.loadSlowly)
        #expect(!child.isSettled)

        try runtime.dismount(runtime.feature(at: ["child"]) ?? root)
        #expect(child.isSettled)
    }
}

extension Store.Feature.Test.Unit {
    @Test func `a redacted field keeps its name and loses its value`() {
        let node = Store.View.Node(
            fields: [.init("count", "1"), .init("loadedAt", "12:00")]
        )

        let redacted = node.redacted(by: .withholding("loadedAt"))

        #expect(redacted.fields.map(\.name) == ["count", "loadedAt"])
        #expect(redacted.fields[1].value == Store.View.Field.withheld)
    }

    @Test func `a spawned subtree renders under the parent's view`() throws {
        let runtime = Store.Runtime(
            state: 0,
            update: Store.Feature.Test.counting,
            projection: Store.Feature.Test.view
        )
        let root = try runtime.mountRoot()

        let child = try runtime.spawn(
            "child",
            under: root,
            state: 0,
            update: Store.Feature.Test.counting,
            projection: Store.Feature.Test.view
        )
        child.send(.increment)

        let view = runtime.view()
        #expect(view.fields == [.init("count", "0")])
        #expect(view.children.map(\.name) == ["child"])
        #expect(view.children.first?.fields == [.init("count", "1")])
    }
}

extension Store.Feature.Test {

    final class Order: @unchecked Sendable {
        private let lock = Mutex<[String]>([])
    }
}

extension Store.Feature.Test.Order {
    func record(_ entry: String) {
        lock.withLock { $0.append(entry) }
    }

    var recorded: [String] {
        lock.withLock { $0 }
    }
}

extension Store.Feature.Test.`Edge Case` {
    @Test func `supplying through a handle held past a dismount is refused and does not reach the replacement`() throws {
        let runtime = Store.Runtime(state: 0, update: Store.Feature.Test.counting)
        let root = try runtime.mountRoot()
        let first = try runtime.mount("detail", under: root)
        try runtime.dismount(first)
        let second = try runtime.mount("detail", under: root)

        #expect(throws: Store.Error.notMounted) {
            try runtime.supply(Store.Feature.Test.Theme.self, "dark", at: first)
        }
        #expect(runtime.value(Store.Feature.Test.Theme.self, at: second) == "system")
    }
}
