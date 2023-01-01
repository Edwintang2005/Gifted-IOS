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
    
    @State private var userProfile = User(Username: "NULL")
    @State private var NameOfUser = ""
    
    @State var listitems = [ListItem]()
    var listitemsLength = Int()
    @State var ImageCache = [String: UIImage]()
    
    // Variable for storing the User's username for use throughout the app
    @AppStorage("Username") var Username: String = ""
    @AppStorage("UserID") var UserID: String = ""
    
    var body: some View{
        VStack(alignment: .leading) {
            HStack {
                // Text that displays the User's name
                Text("Hello, \(NameOfUser)!").homepagename()
                    .padding(.horizontal)
                Spacer()
            }
            // replace below with Roger's design of Homescreen
            Text("Top Items:")
                .font(.title2)
                .padding([.top, .leading, .trailing])
            ScrollView(.horizontal, showsIndicators: false){
                HStack{
                    ForEach(listitems) { item in
                        DisplayCards(listItem: item).padding(6)
                    }
                }
            }
            .padding(.leading)
            Spacer()
        }
        .padding(.vertical)
        .navigationBarTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: (
            Button("Sign Out", action: sessionManager.signOut)
        ))
        .onAppear{
            fetchUserInfo()
            getListItem()
        }
    }
    
    func getImage(Imagekey: String?) {
        guard let Key = Imagekey else {return}
        Amplify.Storage.downloadData(key: Key) { result in
            switch result {
            case .success(let ImageData):
                print("Fetched ImageData")
                let image = UIImage(data: ImageData)
                DispatchQueue.main.async{
                    ImageCache[Key] = image
                }
                return
            case .failure(let error):
                print("Could not get Image URL - \(error)")
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
                dataStore.createUser(userID: UserID, username: Username)
                dataStore.createFirstList(userID: UserID, name: "\(Username)'s List")
            } else {
                print(userObject)
                userProfile = userObject
            }
        }
    }
    
    func getListItem() {
        Amplify.DataStore.query(ListItem.self) { result in
            switch result {
            case.success(let listitems):
                self.listitems = listitems
            case.failure(let error):
                print(error)
            }
        }
    }
}




//struct MainView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//    }
//}
