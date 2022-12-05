// swiftlint:disable all
import Amplify
import Foundation

extension Group {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case users
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let group = Group.keys
    
    model.authRules = [
      rule(allow: .public, operations: [.create, .update, .delete, .read])
    ]
    
    model.pluralName = "Groups"
    
    model.attributes(
      .primaryKey(fields: [group.id])
    )
    
    model.fields(
      .field(group.id, is: .required, ofType: .string),
      .hasMany(group.users, is: .optional, ofType: UserGroup.self, associatedWith: UserGroup.keys.group),
      .field(group.createdAt, is: .optional, isReadOnly: true, ofType: .dateTime),
      .field(group.updatedAt, is: .optional, isReadOnly: true, ofType: .dateTime)
    )
    }
}

extension Group: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}