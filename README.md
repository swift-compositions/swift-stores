# swift-stores

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

An isolation-generic store runtime for Swift — state advanced by actions, an explicit feature lifecycle you can put a breakpoint on, typed communication between features that never name each other, and tests that assert against a derived view instead of demanding `Equatable` state.

## Key Features

- **Isolation-generic, main actor as a specialization** — a runtime captures the isolation it was created on and returns to it. Created on the main actor it is main-actor isolated; created inside an actor it is isolated to that actor. Nothing here assumes a user interface exists.
- **Mount and dismount are API** — features appear and disappear at call sites, not by reflection over state and not because some optional became `nil`. A handle held past a dismount resolves to nothing rather than to whatever was mounted there next.
- **Typed communication in both directions** — values and commands travel down, events bubble up with consume-or-transform, and contributions aggregate upward under a monoid. Neither participant names the other, and no traffic is matched by string.
- **Per-subtree runtimes** — a spawned subtree runs its own state on its own runtime and opts out of the parent's action routing, so sending to it does not cost more for being deep in a tree. The parent keeps the lifecycle.
- **Execution belongs to the effect owner** — the runtime decides when work starts and stops; how a body is performed is a swappable handler, which is what makes a test a handler swap rather than a different runtime.

## Quick Start

```swift
import Stores

enum Action: Sendable { case increment, load, loaded(Int) }

let update = Store.Update<Int, Action, Store.Work<Action>> { count, action in
    switch action {
    case .increment:
        count += 1
        return .none
    case .load:
        return .run(Store.Work(cancellation: "load") { send in
            await send(.loaded(41))
        })
    case .loaded(let value):
        count = value
        return .send(.increment)
    }
}

@MainActor
func run() {
    let runtime = Store.Runtime(state: 0, update: update)  // main-actor isolated
    runtime.send(.increment)                                // state == 1
}
```

## Features and communication

A feature is a named position. What it offers the rest of the tree is stated where it is mounted:

```swift
enum Theme: Store.Key.`Protocol` {
    static var initial: Palette { .system }
}

let root = try runtime.mountRoot { $0.supply(Theme.self, .dark) }
let detail = try runtime.mount("detail", under: root) { mount in
    mount.on(Saved.self) { _ in .consumed }
    mount.onDismount { subscription.cancel() }
}

runtime.value(Theme.self, at: detail)   // .dark — resolved from an ancestor
runtime.raise(Saved(id: 7), from: detail)
try runtime.dismount(detail)            // teardown runs deepest first
```

A command needs no separate machinery: it is a value whose type is a function, so the same key mechanism carries it, and the key's initial value doubles as the neutral behaviour.

## Testing

Tests assert against a rendered view. State needs no `Equatable`, failures name the field that differed, and fields that legitimately vary run to run are withheld once rather than worked around at every assertion:

```swift
import Stores_Testing

let store = Store.Test.Runtime(
    state: 0,
    update: update,
    redacting: .withholding("loadedAt"),
    projection: { count in .init(fields: [.init("count", "\(count)")]) }
)

try store.send(.increment, becoming: .init(fields: [.init("count", "1")]))
try await store.finish()   // fails if any work is still in flight
```

## Installation

```swift
.package(url: "https://github.com/swift-compositions/swift-stores.git", branch: "main")
```

## Design attribution

An independent implementation in the Elm lineage. The vocabulary of a store advanced by actions descends from Elm and Redux. Effects returned from a reduction as data, and a test store that asserts step by step, are prior art visible in the MIT-licensed swift-composable-architecture and its public 2.0 beta. No code or API surface from any of those is reproduced here.

## License

Apache License 2.0. See [LICENSE.md](LICENSE.md).
