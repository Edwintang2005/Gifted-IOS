// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "8def6850de0aa3fe796952902ce925c6"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: User.self)
    ModelRegistry.register(modelType: Reservations.self)
    ModelRegistry.register(modelType: Group.self)
    ModelRegistry.register(modelType: UserList.self)
    ModelRegistry.register(modelType: ListItem.self)
  }
}