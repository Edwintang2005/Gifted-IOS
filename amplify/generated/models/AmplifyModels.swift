// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "1d130a8683a54db419c49c77f365051a"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: ListItem.self)
    ModelRegistry.register(modelType: Images.self)
    ModelRegistry.register(modelType: User.self)
  }
}