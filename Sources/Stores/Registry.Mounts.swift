internal import Tree_Keyed

extension Registry {

    struct Mounts<Node: Sendable> {
        private var storage: Storage

        init() {
            self.storage = Storage()
        }
    }
}

extension Registry.Mounts {
    typealias Storage = __Tree<TreeStorage.Keyed<Node, String>>
}

extension Registry.Mounts {

    var root: Registry.Handle? {
        storage.root.map(Registry.Handle.init)
    }

    var isEmpty: Bool {
        storage.isEmpty
    }

    func holds(_ handle: Registry.Handle) -> Bool {

        storage.peek(at: handle.position) != nil
    }
}

extension Registry.Mounts {

    mutating func mount(_ node: Node) throws(Registry.Error) -> Registry.Handle {
        do throws(Storage.Error) {
            return Registry.Handle(try storage.insert(node, at: Storage.Insert.Position.root))
        } catch {
            throw Registry.Error(error)
        }
    }

    mutating func mount(
        _ node: Node,
        named name: String,
        under parent: Registry.Handle
    ) throws(Registry.Error) -> Registry.Handle {
        do throws(Storage.Error) {

            return Registry.Handle(
                try storage.insert(node, at: .child(of: parent.position, key: name))
            )
        } catch {
            throw Registry.Error(error)
        }
    }

    mutating func dismount(_ handle: Registry.Handle) throws(Registry.Error) {
        guard holds(handle) else { throw .stale }
        do throws(__TreeError) {

            try storage.removeSubtree(at: handle.position)
        } catch {
            throw .stale
        }
    }
}

extension Registry.Mounts {

    func node(at handle: Registry.Handle) -> Node? {

        storage.peek(at: handle.position)
    }

    @discardableResult
    mutating func update<R>(at handle: Registry.Handle, _ body: (inout Node) -> R) -> R? {

        storage.withElementMut(at: handle.position, body)
    }
}

extension Registry.Mounts {

    func handle(at path: some Swift.Sequence<String>) -> Registry.Handle? {

        storage.position(at: path).map(Registry.Handle.init)
    }

    func path(to handle: Registry.Handle) -> [String]? {

        storage.keyPath(to: handle.position)
    }

    func name(of handle: Registry.Handle) -> String? {

        storage.key(of: handle.position)
    }
}

extension Registry.Mounts {

    func children(of handle: Registry.Handle) -> [(name: String, handle: Registry.Handle)] {

        guard let children = storage.children(of: handle.position) else { return [] }

        return children.map { (name: $0.key, handle: Registry.Handle($0.position)) }
    }

    func ancestors(of handle: Registry.Handle) -> [Registry.Handle] {
        var result: [Registry.Handle] = []

        var current = handle.position
        while let parent = storage.parent(of: current) {
            result.append(Registry.Handle(parent))
            current = parent
        }
        return result
    }

    func subtree(from handle: Registry.Handle) -> [Registry.Handle] {
        var result: [Registry.Handle] = []
        var frontier: [Registry.Handle] = [handle]
        while !frontier.isEmpty {
            let current = frontier.removeFirst()
            result.append(current)
            frontier.append(contentsOf: children(of: current).map(\.handle))
        }
        return result
    }
}
