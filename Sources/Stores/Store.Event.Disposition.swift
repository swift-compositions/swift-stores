public import Store_Reduction

extension Store.Event {

    public enum Disposition: Sendable {

        case ignored

        case consumed

        case transformed(any Sendable)
    }
}
