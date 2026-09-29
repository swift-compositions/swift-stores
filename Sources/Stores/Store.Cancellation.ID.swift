public import Store

extension Store.Cancellation {

    public struct ID: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {

        public let name: String

        public init(_ name: String) {
            self.name = name
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }
    }
}

extension Store.Cancellation.ID {
    public var description: String {
        name
    }
}
