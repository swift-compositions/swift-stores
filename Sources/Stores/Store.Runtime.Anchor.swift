extension Store.Runtime {

    struct Anchor: @unchecked Sendable {
        let runtime: Store.Runtime<State, Action>?

        init(_ runtime: Store.Runtime<State, Action>) {
            self.runtime = runtime
        }
    }
}
