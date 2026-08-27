public import Store_Reduction

extension Store.Runtime {

    @discardableResult
    public func mountRoot(
        _ configure: (inout Store.Feature.Mount) -> Void = { _ in }
    ) throws(Store.Error) -> Store.Feature.Handle {
        var mount = Store.Feature.Mount()
        configure(&mount)
        do throws(Registry.Error) {
            return Store.Feature.Handle(try _features.mount(mount))
        } catch {
            throw Store.Error(error)
        }
    }

    @discardableResult
    public func mount(
        _ name: String,
        under parent: Store.Feature.Handle,
        _ configure: (inout Store.Feature.Mount) -> Void = { _ in }
    ) throws(Store.Error) -> Store.Feature.Handle {
        var mount = Store.Feature.Mount()
        configure(&mount)
        do throws(Registry.Error) {
            return Store.Feature.Handle(
                try _features.mount(mount, named: name, under: parent.registry)
            )
        } catch {
            throw Store.Error(error)
        }
    }

    public func dismount(_ handle: Store.Feature.Handle) throws(Store.Error) {
        guard _features.holds(handle.registry) else { throw .notMounted }

        for descendant in _features.subtree(from: handle.registry).reversed() {
            guard let mount = _features.node(at: descendant) else { continue }
            for body in mount.teardown.reversed() {
                body()
            }
        }

        do throws(Registry.Error) {
            try _features.dismount(handle.registry)
        } catch {
            throw Store.Error(error)
        }
    }

    public func isMounted(_ handle: Store.Feature.Handle) -> Bool {
        _features.holds(handle.registry)
    }
}

extension Store.Runtime {

    public var root: Store.Feature.Handle? {
        _features.root.map(Store.Feature.Handle.init)
    }

    public func feature(at path: [String]) -> Store.Feature.Handle? {
        _features.handle(at: path).map(Store.Feature.Handle.init)
    }

    public func path(to handle: Store.Feature.Handle) -> [String]? {
        _features.path(to: handle.registry)
    }

    public func children(
        of handle: Store.Feature.Handle
    ) -> [(name: String, handle: Store.Feature.Handle)] {
        _features.children(of: handle.registry).map {
            (name: $0.name, handle: Store.Feature.Handle($0.handle))
        }
    }
}
