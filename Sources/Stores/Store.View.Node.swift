public import Store

extension Store.View {

    public struct Node: Sendable, Hashable {

        public let name: String

        public let fields: [Store.View.Field]

        public let children: [Store.View.Node]

        public init(
            name: String = "",
            fields: [Store.View.Field] = [],
            children: [Store.View.Node] = []
        ) {
            self.name = name
            self.fields = fields
            self.children = children
        }
    }
}

extension Store.View.Node {

    public static var empty: Self {
        .init()
    }

    public func redacted(by redaction: Store.Redaction) -> Self {
        .init(
            name: name,
            fields: fields.map { redaction.withholds($0.name) ? $0.redacted : $0 },
            children: children.map { $0.redacted(by: redaction) }
        )
    }
}
