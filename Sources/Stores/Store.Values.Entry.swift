public import Store

extension Store.Values {

    struct Entry: Sendable {
        let identity: ObjectIdentifier

        let value: any Sendable
    }
}
