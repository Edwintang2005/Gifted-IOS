// swiftlint:disable all
import Amplify
import Foundation

public struct User: Model {
  public let id: String
  public var Username: String
  public var Lists: [String]
  public var Friends: [String]
  public var Groups: [String]
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      Username: String,
      Lists: [String] = [],
      Friends: [String] = [],
      Groups: [String] = []) {
    self.init(id: id,
      Username: Username,
      Lists: Lists,
      Friends: Friends,
      Groups: Groups,
      createdAt: nil,
      updatedAt: nil)
  }
  internal init(id: String = UUID().uuidString,
      Username: String,
      Lists: [String] = [],
      Friends: [String] = [],
      Groups: [String] = [],
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.Username = Username
      self.Lists = Lists
      self.Friends = Friends
      self.Groups = Groups
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}