public import Store_Reduction

extension Store.Runtime {

    @discardableResult
    public func spawn<ChildState: Sendable, ChildAction: Sendable>(
        _ name: String,
        under parent: Store.Feature.Handle,
        state: ChildState,
        update: Store.Update<ChildState, ChildAction, Store.Work<ChildAction>>,
        scope: Store.Scope? = nil,
        projection: @escaping @Sendable (ChildState) -> Store.View.Node = { _ in .empty },
        _ configure: (inout Store.Feature.Mount) -> Void = { _ in },

        isolation: isolated (any Actor)? = #isolation
    ) throws(Store.Error) -> Store.Runtime<ChildState, ChildAction> {
        let child = Store.Runtime<ChildState, ChildAction>(
            state: state,
            update: update,
            scope: scope ?? self.scope,
            projection: projection,
            isolation: isolation
        )

        try mount(name, under: parent) { mount in
            configure(&mount)
            mount.renders { child.view() }
            mount.onDismount { child.cancelAll() }
        }

        return child
    }
}
