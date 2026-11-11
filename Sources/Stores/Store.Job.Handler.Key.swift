public import Effect
public import Store

extension Store.Job.Handler {

    public struct Key: Effect::Effect.Context.Key {}
}

extension Store.Job.Handler.Key {
    public typealias Value = Store.Job.Handler

    public static var liveValue: Store.Job.Handler { .inline }

    public static var testValue: Store.Job.Handler { .inline }
}
