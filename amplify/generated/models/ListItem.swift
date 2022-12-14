// swiftlint:disable all
import Amplify
import Foundation

public struct ListItem: Model {
  public let id: String
  public var Name: String
  public var Price: String?
  public var ShortDescription: String?
  public var ImageKey: String?
  public var Link: String?
  public var Reservation: [String]?
  public var userID: String
  public var createdAt: Temporal.DateTime?
  public var updatedAt: Temporal.DateTime?
  
  public init(id: String = UUID().uuidString,
      Name: String,
      Price: String? = nil,
      ShortDescription: String? = nil,
      ImageKey: String? = nil,
      Link: String? = nil,
      Reservation: [String]? = nil,
      userID: String) {
    self.init(id: id,
      Name: Name,
      Price: Price,
      ShortDescription: ShortDescription,
      ImageKey: ImageKey,
      Link: Link,
      Reservation: Reservation,
      userID: userID,
      createdAt: nil,
      updatedAt: nil)
  }
  internal init(id: String = UUID().uuidString,
      Name: String,
      Price: String? = nil,
      ShortDescription: String? = nil,
      ImageKey: String? = nil,
      Link: String? = nil,
      Reservation: [String]? = nil,
      userID: String,
      createdAt: Temporal.DateTime? = nil,
      updatedAt: Temporal.DateTime? = nil) {
      self.id = id
      self.Name = Name
      self.Price = Price
      self.ShortDescription = ShortDescription
      self.ImageKey = ImageKey
      self.Link = Link
      self.Reservation = Reservation
      self.userID = userID
      self.createdAt = createdAt
      self.updatedAt = updatedAt
  }
}