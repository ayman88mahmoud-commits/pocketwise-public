import Foundation
import CloudKit

enum WalletSyncCKRecordAdapter {

    static let recordType = "WalletSyncRecord"

    // All DTO field keys are prefixed to ensure they never collide with the metadata keys below.
    static let fieldKeyPrefix = "field_"

    private enum MetadataKey {
        static let entity    = "entity"
        static let id        = "id"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
        static let isDeleted = "isDeleted"
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
            record[fieldKeyPrefix + key] = ckValue(for: value)
        }

        return record
    }

    // Returns nil for .null so that assigning it to a CKRecord field leaves the field absent.
    private static func ckValue(for fieldValue: WalletSyncFieldValue) -> CKRecordValueProtocol? {
        switch fieldValue {
        case .string(let s):         return s
        case .double(let d):         return NSNumber(value: d)
        case .int(let i):            return NSNumber(value: i)
        case .bool(let b):           return NSNumber(value: b)
        case .date(let date):        return date
        case .uuid(let uuid):        return uuid.uuidString.lowercased()
        case .stringArray(let arr):  return arr as NSArray
        case .null:                  return nil
        }
    }
}
