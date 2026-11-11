import Algebra
internal import Effect
public import Observer
public import Store

extension Store {

    @Observable
    public final class Runtime<State: Sendable, Action: Sendable>: @unchecked Sendable {

        public var state: State

        public let update: Store.Update<State, Action, Store.Work<Action>>

        public let scope: Store.Scope

        public let isolation: (any Actor)?

        let projection: @Sendable (State) -> Store.View.Node

        var _features: Registry.Mounts<Store.Feature.Mount>
        var _pending: Mailbox<Action>
        var _inFlight: Ledger<Store.Work<Action>.Record>
        var _nextTicket: UInt64
        var _reducing: Bool

        public init(
            state: State,
            update: Store.Update<State, Action, Store.Work<Action>>,
            scope: Store.Scope = .inherited,
            projection: @escaping @Sendable (State) -> Store.View.Node = { _ in .empty },

            isolation: isolated (any Actor)? = #isolation
        ) {

            self._state = state
            self.update = update
            self.scope = scope
            self.projection = projection
            self.isolation = isolation
            self._features = Registry.Mounts()
            self._pending = Mailbox()
            self._inFlight = Ledger()
            self._nextTicket = 0
            self._reducing = false
        }
    }
}

extension Store.Runtime {

    public func value<K: Store.Key.`Protocol`>(
        _ key: K.Type,
        at handle: Store.Feature.Handle
    ) -> K.Value {
        if let mount = _features.node(at: handle.registry), let value = mount.values.value(for: key) {
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
        let applied: Void? = _features.update(at: handle.registry) { mount in
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

    // swift-linter:disable:next raw concept
    // REASON: a path through the feature tree, the feature names from the root, as Store.Feature.Handle and the registry resolve it; not a file path, so File.Path does not own it, and no other type names it.
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

extension Store.Runtime {

    public func send(_ action: Action) {
        _pending.post(action)
        guard !_reducing else { return }

        _reducing = true
        defer { _reducing = false }

        while let next = _pending.next() {
            let effect = scope.run { self.update.effect(for: next, in: &self.state) }
            begin(effect)
        }
    }
}

extension Store.Runtime {

    func begin(_ effect: Store.Effect<Action, Store.Work<Action>>) {
        switch effect {
        case .none:
            return

        case .send(let action):
            _pending.post(action)

        case .run, .merge, .sequence:
            start(effect)
        }
    }

    @discardableResult
    private func start(_ effect: Store.Effect<Action, Store.Work<Action>>) -> [Task<Void, Never>] {
        switch effect {
        case .none:
            return []

        case .merge(let effects):
            return effects.flatMap { start($0) }

        case .send, .run, .sequence:
            let ticket = mintTicket()
            let send = sender()
            let launch = launcher()
            let cancellation = Self.cancellation(of: effect)

            let task = Task { [weak self] in
                await Self.execute(effect, send: send, launch: launch)
                guard let self else { return }
                await retire(ticket, isolation: isolation)
            }

            _inFlight.record(.init(cancellation: cancellation, task: task), as: ticket)
            return [task]
        }
    }

    private static func execute(
        _ effect: Store.Effect<Action, Store.Work<Action>>,
        send: Store.Send<Action>,
        launch: @escaping @Sendable (Store.Effect<Action, Store.Work<Action>>) async -> [Task<Void, Never>]
    ) async {
        switch effect {
        case .none:
            return

        case .send(let action):
            await send(action)

        case .run(let work):
            let body = work.body

            await Effect::Effect.perform(Store.Job { await body(send) })

        case .merge:
            await join(await launch(effect))

        case .sequence(let effects):
            for step in effects {
                guard !Task.isCancelled else { return }
                switch step {
                case .none, .send:
                    await execute(step, send: send, launch: launch)

                case .run, .merge, .sequence:
                    await join(await launch(step))
                }
            }
        }
    }

    private static func join(_ tasks: [Task<Void, Never>]) async {
        await withTaskCancellationHandler {
            for task in tasks {
                await task.value
            }
        } onCancel: {
            for task in tasks {
                task.cancel()
            }
        }
    }

    private static func cancellation(
        of effect: Store.Effect<Action, Store.Work<Action>>
    ) -> Store.Cancellation.ID? {
        guard case .run(let work) = effect else { return nil }
        return work.cancellation
    }
}

extension Store.Runtime {

    func sender() -> Store.Send<Action> {
        Store.Send { [weak self] action in
            guard let self else { return }
            await accept(action, isolation: isolation)
        }
    }

    private func accept(_ action: Action, isolation: isolated (any Actor)?) async {
        send(action)
    }

    func launcher() -> @Sendable (Store.Effect<Action, Store.Work<Action>>) async -> [Task<Void, Never>] {
        { [weak self] effect in
            guard let self else { return [] }
            guard let isolation else { return start(effect) }
            return await launch(effect, on: isolation)
        }
    }

    private func launch<Isolation: Actor>(
        _ effect: Store.Effect<Action, Store.Work<Action>>,
        on isolation: isolated Isolation
    ) async -> [Task<Void, Never>] {
        start(effect)
    }

    private func retire(_ ticket: UInt64, isolation: isolated (any Actor)?) async {
        _inFlight.discard(ticket)
    }

    private func mintTicket() -> UInt64 {
        _nextTicket += 1
        return _nextTicket
    }
}

extension Store.Runtime {

    public var isSettled: Bool {
        _inFlight.isEmpty && _pending.isEmpty
    }

    public var inFlight: [Store.Cancellation.ID] {
        var result: [Store.Cancellation.ID] = []
        _inFlight.forEach { _, record in
            if let cancellation = record.cancellation { result.append(cancellation) }
        }
        return result
    }

    public func cancel(_ id: Store.Cancellation.ID) {
        var doomed: [UInt64] = []
        _inFlight.forEach { ticket, record in
            if record.cancellation == id { doomed.append(ticket) }
        }
        for ticket in doomed {
            _inFlight.discard(ticket)?.task.cancel()
        }
    }

    public func cancelAll() {
        for ticket in _inFlight.tickets {
            _inFlight.discard(ticket)?.task.cancel()
        }
    }
}

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

extension Store.Runtime {

    public func view(redacting redaction: Store.Redaction = .nothing) -> Store.View.Node {
        let own = projection(state)
        let mounted = _features.root.map { spawned(under: $0) } ?? []

        return Store.View.Node(
            name: own.name,
            fields: own.fields,
            children: own.children + mounted
        )
        .redacted(by: redaction)
    }

    private func spawned(under handle: Registry.Handle) -> [Store.View.Node] {
        var result: [Store.View.Node] = []

        for child in _features.children(of: handle) {
            let descendants = spawned(under: child.handle)

            guard
                let mount = _features.node(at: child.handle),
                let render = mount.render
            else {
                result.append(contentsOf: descendants)
                continue
            }

            let rendered = render()
            result.append(
                Store.View.Node(
                    name: child.name,
                    fields: rendered.fields,
                    children: rendered.children + descendants
                )
            )
        }

        return result
    }
}
