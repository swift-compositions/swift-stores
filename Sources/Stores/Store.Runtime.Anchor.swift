extension Store.Runtime {

    struct Anchor: @unchecked Sendable {
        #if hasFeature(Embedded)
            let runtime: Store.Runtime<State, Action>?
        #else
            weak var runtime: Store.Runtime<State, Action>?
        #endif

        init(_ runtime: Store.Runtime<State, Action>) {
            self.runtime = runtime
        }
    }
}
