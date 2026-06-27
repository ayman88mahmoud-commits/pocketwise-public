import Foundation
import CloudKit

enum WalletSyncCKRecordAdapter {

    // MARK: - CKRecord contract

    static let recordType = "WalletSyncRecord"

    // Custom DTO field values and their type markers use separate prefixes so they cannot
    // collide with reserved metadata keys or with each other.
    static let fieldKeyPrefix = "field_"
    static let fieldTypeKeyPrefix = "fieldType_"

    private enum MetadataKey {
        static let entity    = "entity"
        static let id        = "id"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
        static let isDeleted = "isDeleted"
    }

    enum AdapterError: Error, Equatable {
        case invalidRecordType(String)
        case missingMetadata(String)
        case invalidEntity(String)
        case invalidID(String)
        case missingFieldType(String)
        case invalidFieldValue(String)
    }

    static func ckRecord(from dto: WalletSyncRecordDTO) -> CKRecord {
        let recordID = CKRecord.ID(recordName: dto.recordName)
        let record   = CKRecord(recordType: recordType, recordID: recordID)

        record[MetadataKey.entity]    = dto.entity.rawValue
        record[MetadataKey.id]        = dto.id.uuidString.lowercased()
        if let updatedAt = dto.updatedAt { record[MetadataKey.updatedAt] = updatedAt }
        if let deletedAt = dto.deletedAt { record[MetadataKey.deletedAt] = deletedAt }
        record[MetadataKey.isDeleted] = NSNumber(value: dto.isDeleted)

        for (key, value) in dto.fields {
            guard let ckValue = ckValue(for: value) else {
                continue
            }
            record[fieldKeyPrefix + key] = ckValue
            record[fieldTypeKeyPrefix + key] = fieldType(for: value).rawValue
        }

        return record
    }

    static func dto(from record: CKRecord) throws -> WalletSyncRecordDTO {
        guard record.recordType == recordType else {
            throw AdapterError.invalidRecordType(record.recordType)
        }

        guard let entityRawValue = record[MetadataKey.entity] as? String else {
            throw AdapterError.missingMetadata(MetadataKey.entity)
        }
        guard let entity = WalletSyncRecordEntity(rawValue: entityRawValue) else {
            throw AdapterError.invalidEntity(entityRawValue)
        }

        guard let idString = record[MetadataKey.id] as? String else {
            throw AdapterError.missingMetadata(MetadataKey.id)
        }
        guard let id = UUID(uuidString: idString) else {
            throw AdapterError.invalidID(idString)
        }

        var fields: [String: WalletSyncFieldValue] = [:]
        for key in record.allKeys() where key.hasPrefix(fieldKeyPrefix) {
            let fieldName = String(key.dropFirst(fieldKeyPrefix.count))
            guard let typeRawValue = record[fieldTypeKeyPrefix + fieldName] as? String else {
                throw AdapterError.missingFieldType(fieldName)
            }
            guard let type = FieldType(rawValue: typeRawValue) else {
                throw AdapterError.invalidFieldValue(fieldName)
            }
            fields[fieldName] = try fieldValue(for: record[key], type: type, fieldName: fieldName)
        }

        return WalletSyncRecordDTO(
            recordName: record.recordID.recordName,
            entity: entity,
            id: id,
            updatedAt: record[MetadataKey.updatedAt] as? Date,
            deletedAt: record[MetadataKey.deletedAt] as? Date,
            isDeleted: boolValue(from: record[MetadataKey.isDeleted]) ?? false,
            fields: fields
        )
    }

    // Returns nil for values CloudKit should not store so the value field and
    // field type marker remain absent.
    private static func ckValue(for fieldValue: WalletSyncFieldValue) -> CKRecordValueProtocol? {
        switch fieldValue {
        case .string(let s):         return s
        case .double(let d):         return NSNumber(value: d)
        case .int(let i):            return NSNumber(value: i)
        case .bool(let b):           return NSNumber(value: b)
        case .date(let date):        return date
        case .uuid(let uuid):        return uuid.uuidString.lowercased()
        case .stringArray(let arr):  return arr.isEmpty ? nil : arr as NSArray
        case .null:                  return nil
        }
    }

    private enum FieldType: String {
        case string
        case double
        case int
        case bool
        case date
        case uuid
        case stringArray
    }

    private static func fieldType(for fieldValue: WalletSyncFieldValue) -> FieldType {
        switch fieldValue {
        case .string:      return .string
        case .double:      return .double
        case .int:         return .int
        case .bool:        return .bool
        case .date:        return .date
        case .uuid:        return .uuid
        case .stringArray: return .stringArray
        case .null:        return .string
        }
    }

    private static func fieldValue(
        for value: CKRecordValueProtocol?,
        type: FieldType,
        fieldName: String
    ) throws -> WalletSyncFieldValue {
        switch type {
        case .string:
            guard let string = value as? String else { throw AdapterError.invalidFieldValue(fieldName) }
            return .string(string)
        case .double:
            guard let number = value as? NSNumber else { throw AdapterError.invalidFieldValue(fieldName) }
            return .double(number.doubleValue)
        case .int:
            guard let number = value as? NSNumber else { throw AdapterError.invalidFieldValue(fieldName) }
            return .int(number.intValue)
        case .bool:
            guard let bool = boolValue(from: value) else { throw AdapterError.invalidFieldValue(fieldName) }
            return .bool(bool)
        case .date:
            guard let date = value as? Date else { throw AdapterError.invalidFieldValue(fieldName) }
            return .date(date)
        case .uuid:
            guard let string = value as? String, let uuid = UUID(uuidString: string) else {
                throw AdapterError.invalidFieldValue(fieldName)
            }
            return .uuid(uuid)
        case .stringArray:
            if let strings = value as? [String] {
                return .stringArray(strings)
            }
            if let array = value as? NSArray, let strings = array as? [String] {
                return .stringArray(strings)
            }
            throw AdapterError.invalidFieldValue(fieldName)
        }
    }

    private static func boolValue(from value: CKRecordValueProtocol?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}
