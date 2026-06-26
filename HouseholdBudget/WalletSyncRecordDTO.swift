import Foundation

enum WalletSyncFieldValue: Codable, Hashable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case date(Date)
    case uuid(UUID)
    case stringArray([String])
    case null

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum ValueType: String, Codable {
        case string
        case double
        case int
        case bool
        case date
        case uuid
        case stringArray
        case null
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)

        switch type {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .value))
        case .int:
            self = .int(try container.decode(Int.self, forKey: .value))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .date:
            self = .date(try container.decode(Date.self, forKey: .value))
        case .uuid:
            self = .uuid(try container.decode(UUID.self, forKey: .value))
        case .stringArray:
            self = .stringArray(try container.decode([String].self, forKey: .value))
        case .null:
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode(ValueType.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode(ValueType.int, forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case .date(let value):
            try container.encode(ValueType.date, forKey: .type)
            try container.encode(value, forKey: .value)
        case .uuid(let value):
            try container.encode(ValueType.uuid, forKey: .type)
            try container.encode(value, forKey: .value)
        case .stringArray(let value):
            try container.encode(ValueType.stringArray, forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode(ValueType.null, forKey: .type)
        }
    }
}

struct WalletSyncRecordDTO: Codable, Hashable {
    var recordName: String
    var entity: WalletSyncRecordEntity
    var id: UUID
    var updatedAt: Date?
    var deletedAt: Date?
    var isDeleted: Bool
    var fields: [String: WalletSyncFieldValue]

    init(
        identity: WalletSyncRecordIdentity,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        isDeleted: Bool = false,
        fields: [String: WalletSyncFieldValue] = [:]
    ) {
        self.recordName = identity.recordName
        self.entity = identity.entity
        self.id = identity.id
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.isDeleted = isDeleted
        self.fields = fields
    }

    init(
        recordName: String,
        entity: WalletSyncRecordEntity,
        id: UUID,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        isDeleted: Bool = false,
        fields: [String: WalletSyncFieldValue] = [:]
    ) {
        self.recordName = recordName
        self.entity = entity
        self.id = id
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.isDeleted = isDeleted
        self.fields = fields
    }
}
