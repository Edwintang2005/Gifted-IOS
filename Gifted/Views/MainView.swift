//
//  MainView.swift
//  Gifted
//
//  Created by Edwin Tang on 31/12/2022.
//

import SwiftUI
import Amplify

// Object for the Main view or what is essentially our home screen
struct MainView: View {
    
    @ObservedObject var dataStore = DataStore()
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var userProfile = UserProfile(Username: "NULL", Name: String())
    
    @State var listitems = [ListItem]()
    var listitemsLength = Int()
    @State var ImageCache = [String: UIImage]()
    
    @AppStorage("NameOfUser") var NameOfUser: String = ""
    
    // Variable for storing the User's username for use throughout the app
    @AppStorage("Username") var Username: String = ""
    @AppStorage("UserID") var UserID: String = ""
    
    private let adaptiveColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View{
        NavigationView {
            VStack{
                HStack (alignment: .top) {
                    // Text that displays the User's name
                    Text("Welcome back, \n\(NameOfUser)!")
                        .colourGradient()
                        .font(.largeTitle)
                    Spacer()
                }
                .padding(.bottom)
                HStack{
                    Text("Your Wishlist:")
                        .subtitle()
                        .padding(.horizontal)
                    Spacer()
                    NavigationLink {
                        ListView(QueryID: UserID)
                    } label: {
                        Text("See All")
                            .small()
                    }
                }
                VStack{
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: adaptiveColumns, spacing: 20) {
                            ForEach(listitems) { item in
                                DisplayCards(listItem: item)
                                    .padding(.all)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.all)
            .onAppear{
                fetchUserInfo()
                getListItem()
            }
        }
    }
    
    func getImage(Imagekey: String?) {
        guard let Key = Imagekey else {return}
        let fetchedImage = dataStore.getImage(ImageKey: Key)
        if fetchedImage != UIImage() {
            DispatchQueue.main.async{
                ImageCache[Key] = fetchedImage
            }
        }
    }
    
    
    func fetchUserInfo() {
        Amplify.Auth.fetchUserAttributes() { result in
            switch result {
            case .success(let attributes):
                let name = attributes.filter {$0.key == .name}
                NameOfUser = name.first?.value ?? ""
            case .failure(let error):
                print("Fetching user attributes failed with error \(error)")
            }
        }
        
        //Get Username and create/check for user object - need to resolve occassional query return empty issue
        
        if let user = Amplify.Auth.getCurrentUser() {
            Username = user.username
            UserID = user.userId
            print(Username)
            
            let userObject = dataStore.fetchUser(userID: UserID)
            if userObject.Username == "NULL" {
                dataStore.createUser(userID: UserID, username: Username, nameofUser: NameOfUser)
            } else {
                print(userObject)
                userProfile = userObject
            }
        }
    }
    
    func getListItem() {
        listitems = dataStore.allItemsQuery()
    }
}




//struct MainView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//    }
//}
