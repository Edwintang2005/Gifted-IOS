// swiftlint:disable all
import Amplify
import Foundation

extension User {
  // MARK: - CodingKeys 
   public enum CodingKeys: String, ModelKey {
    case id
    case Username
    case Friends
    case Groups
    case Lists
    case createdAt
    case updatedAt
  }
  
  public static let keys = CodingKeys.self
  //  MARK: - ModelSchema 
  
  public static let schema = defineSchema { model in
    let user = User.keys
    
    model.authRules = [
      rule(allow: .public, operations: [.create, .update, .delete, .read])
    ]
    
    model.pluralName = "Users"
    
    model.attributes(
      .primaryKey(fields: [user.id])
    )
    
    model.fields(
      .field(user.id, is: .required, ofType: .string),
      .field(user.Username, is: .required, ofType: .string),
      .field(user.Friends, is: .required, ofType: .embeddedCollection(of: String.self)),
      .field(user.Groups, is: .required, ofType: .embeddedCollection(of: String.self)),
      .hasMany(user.Lists, is: .optional, ofType: List.self, associatedWith: List.keys.userID),
      .field(user.createdAt, is: .optional, isReadOnly: true, ofType: .dateTime),
      .field(user.updatedAt, is: .optional, isReadOnly: true, ofType: .dateTime)
    )
    }
}

extension User: ModelIdentifiable {
  public typealias IdentifierFormat = ModelIdentifierFormat.Default
  public typealias IdentifierProtocol = DefaultModelIdentifier<Self>
}