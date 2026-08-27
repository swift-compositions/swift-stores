internal import Effects
public import Store_Reduction

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

    private func start(_ effect: Store.Effect<Action, Store.Work<Action>>) {
        let ticket = mintTicket()
        let send = sender()
        let cancellation = Self.cancellation(of: effect)

        let task = Task { [weak self] in
            await Self.execute(effect, send: send)
            guard let self else { return }
            await retire(ticket, isolation: isolation)
        }

        _inFlight.record(.init(cancellation: cancellation, task: task), as: ticket)
    }

    private static func execute(
        _ effect: Store.Effect<Action, Store.Work<Action>>,
        send: Store.Send<Action>
    ) async {
        switch effect {
        case .none:
            return

        case .send(let action):
            await send(action)

        case .run(let work):
            let body = work.body

            await Effects.Effect.perform(Store.Job { await body(send) })

        case .merge(let effects):
            await withTaskGroup(of: Void.self) { group in
                for effect in effects {
                    group.addTask { await Self.execute(effect, send: send) }
                }
            }

        case .sequence(let effects):
            for effect in effects {
                await Self.execute(effect, send: send)
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
