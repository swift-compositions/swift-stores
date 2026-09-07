public import Algebra
public import Store_Reduction

extension Store.Runtime {

    public func value<K: Store.Key.`Protocol`>(
        _ key: K.Type,
        at handle: Store.Feature.Handle
    ) -> K.Value {
        if let mount = _features.node(at: handle.registry), let value = mount.values.value(for: key)
        {
            return value
        }
        for ancestor in _features.ancestors(of: handle.registry) {
            if let mount = _features.node(at: ancestor), let value = mount.values.value(for: key) {
                return value
            }
        }
        return K.initial
    }

    public func supply<K: Store.Key.`Protocol`>(
        _ key: K.Type,
        _ value: K.Value,
        at handle: Store.Feature.Handle
    ) throws(Store.Error) {
        let applied = _features.update(at: handle.registry) { mount in
            mount.values.set(key, to: value)
        }
        guard applied != nil else { throw .notMounted }
    }
}

extension Store.Runtime {

    public func aggregate<K: Store.Key.Aggregate>(
        _ key: K.Type,
        from handle: Store.Feature.Handle
    ) -> K.Value {
        let monoid: Algebra.Monoid<K.Value> = K.aggregation
        var result = monoid.identity
        for member in _features.subtree(from: handle.registry) {
            guard
                let mount = _features.node(at: member),
                let contribution = mount.contributions.value(for: key)
            else { continue }
            result = monoid.combining(result, contribution)
        }
        return result
    }

    @discardableResult
    public func raise<E: Sendable>(_ event: E, from handle: Store.Feature.Handle) -> Bool {

        var current: any Sendable = event

        for ancestor in _features.ancestors(of: handle.registry) {
            guard let mount = _features.node(at: ancestor) else { continue }
            for receiver in mount.receivers {
                switch receiver.accept(current) {
                case .ignored:
                    continue

                case .consumed:
                    return true

                case .transformed(let replacement):
                    current = replacement
                }
            }
        }

        return false
    }
}
