public import Store_Reduction

extension Store.Feature {

    public struct Handle: Hashable, Sendable {
        let registry: Registry.Handle

        init(_ registry: Registry.Handle) {
            self.registry = registry
        }
    }
}
