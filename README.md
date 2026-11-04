# swift-stores

Use this package when you hold application state that changes only through actions, start async work from those changes, and mount features into a tree that talk to each other without naming each other. Start from `Store.Runtime`, create it on the actor or isolation the state should live on, and mount features with `Store.Runtime.mountRoot(_:)` and `Store.Runtime.mount(_:under:_:)`. To test a store step by step against a rendered view, use `Store.Test.Runtime` from Stores Testing. If you only need the update, effect and key vocabulary without a runtime, use swift-store.

## Laws

- `Store.Runtime.send(_:)` reduces before it returns. Actions are reduced in the order sent. An action sent while reducing, or returned as a send effect, is reduced in the same call, so it leaves no work in flight.
- Each run, merge or sequence effect that `update` returns starts one task. A merge runs its parts at the same time and a sequence runs them in order. Actions sent from work return to the runtime's isolation.
- Only a run effect at the top of what `update` returns is tracked by its cancellation ID. Work nested in a merge or sequence has no ID, so `Store.Runtime.cancel(_:)` can't reach it and it isn't named in `Store.Runtime.inFlight`.
- Starting work never cancels earlier work with the same ID. `Store.Runtime.cancel(_:)` cancels every in-flight work with that ID and drops it from the runtime at once.
- A runtime is settled when no action is waiting and no work is in flight.
- Work bodies run through the `Store.Job.Handler` dependency, which runs them inline unless overridden. `update` runs inside the runtime's `Store.Scope`.
- A runtime has one root feature, and sibling names are unique. A handle kept after its feature is dismounted never resolves to a later feature mounted at the same place. Supplying or dismounting through it fails as not mounted.
- Dismounting a feature removes its whole subtree. Teardowns run deepest first, and in reverse order of registration within a feature.
- `Store.Runtime.value(_:at:)` reads the feature itself, then the nearest ancestor that supplied the key, then the key's initial value.
- `Store.Runtime.aggregate(_:from:)` combines the contributions of the feature and its whole subtree, level by level, under the key's monoid. With no contributions it is the monoid's identity.
- `Store.Runtime.raise(_:from:)` starts at the parent, not at the feature that raises. Receivers are asked in registration order, nearest ancestor first. A transformed event replaces the original for everyone after. It returns true only if some receiver consumed the event.
- A spawned runtime reduces its own state and actions, uses the parent's scope unless given one, and renders under the parent's view at its name. Dismounting its feature cancels all of its work.
- A redacted field keeps its name and shows `<withheld>` as its value. `Store.Test.Runtime` redacts both the view it expects and the view it gets before comparing.
- `Store.Test.Runtime.finish(turns:)` yields up to the given number of turns, 1000 by default, and then fails if work is still in flight, naming the work that has a cancellation ID.
