public import Effects
public import Store_Reduction

extension Store.Job {

    public struct Handler: Effects.Effect.Handler.`Protocol`, Sendable {
        let run: @Sendable (@escaping @Sendable () async -> Void) async -> Void

        public init(_ run: @escaping @Sendable (@escaping @Sendable () async -> Void) async -> Void)
        {
            self.run = run
        }
    }
}

extension Store.Job.Handler {
    public typealias Handled = Store.Job

    public func handle(
        _ effect: borrowing Store.Job,
        continuation: consuming Effects.Effect.Continuation.One<Void, Never>
    ) async {
        let body = effect.body
        await run(body)
        await continuation.resume()
    }
}

extension Store.Job.Handler {

    public static var inline: Self {
        .init { body in await body() }
    }
}
