public import Store_Reduction

extension Store {

    public struct Redaction: Sendable, Equatable {

        public let fields: Swift.Set<String>

        public init(fields: Swift.Set<String>) {
            self.fields = fields
        }
    }
}

extension Store.Redaction {

    public static var nothing: Self {
        .init(fields: [])
    }

    public static func withholding(_ fields: String...) -> Self {
        .init(fields: Swift.Set(fields))
    }

    public func withholds(_ field: String) -> Bool {
        fields.contains(field)
    }
}
