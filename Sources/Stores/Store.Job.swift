public import Effect
public import Store

extension Store {

    public struct Job: Effect::Effect.`Protocol`, Effect::Effect.Handled, Sendable {

        public let body: @Sendable () async -> Void

        public init(_ body: @escaping @Sendable () async -> Void) {
            self.body = body
        }
    }
}

extension Store.Job {
    public typealias Value = Void
    public typealias Failure = Never
    public typealias HandlerKey = Store.Job.Handler.Key
}
