public import Store

extension Store.View {

    public struct Field: Sendable, Hashable {

        public let name: String

        public let value: String

        public init(_ name: String, _ value: String) {
            self.name = name
            self.value = value
        }
    }
}

extension Store.View.Field {

    public static let withheld: String = "<withheld>"

    public var redacted: Self {
        .init(name, Self.withheld)
    }
}
