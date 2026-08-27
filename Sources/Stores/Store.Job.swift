public import Effects
public import Store_Reduction

extension Store {

    public struct Job: Effects.Effect.`Protocol`, EffectWithHandler, Sendable {

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
