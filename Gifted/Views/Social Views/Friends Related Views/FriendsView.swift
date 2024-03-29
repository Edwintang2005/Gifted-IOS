//
//  FriendsView.swift
//  Gifted
//
//  Created by Edwin Tang on 3/12/2022.
//


import Amplify
import Combine
import SwiftUI

// Page for friends lists, not yet built although buttons and structures are all done, just need backend functionality
struct FriendsView: View {
    
    @ObservedObject var dataStore = DataStore()
    @EnvironmentObject var sessionManager: SessionManager
    
    @Binding var ImageCache: [String: UIImage]
    @Binding var displayPopup: popupState
    
    let username = UserDefaults.standard.string(forKey: "Username") ?? "NullUser"
    let userID = UserDefaults.standard.string(forKey: "UserID") ?? "NullUser"
    
    @State var Friends = [UserProfile]()
    @State var FriendsLength = Int()
    @Binding var displayedProfile : UserProfile
    
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Text("CONTACTS").boldText()
                        .padding(.horizontal)
                    Spacer()
                    Button {
                        displayPopup = popupState.addFriend
                    } label: {
                        Image(systemName:"person.badge.plus")
                            .imageScale(.large)
                    }
                }
                .padding(.all)
                
                if FriendsLength == 0 {
                    Spacer()
                    Text("Hopefully it's not normally like this... \n Add some friends!")
                        .multilineTextAlignment(.center)
                    Spacer()
                } else {
                    ScrollView {
                        ForEach(Friends) {
                            Friend in Button{
                                displayedProfile = Friend
                                displayPopup = .friendInfo
                            } label: {
                                FriendDisplayCards(friend: Friend, ImageCache: $ImageCache)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear{
            getFriends()
            FriendsLength = Friends.count
        }
        .onChange(of: displayPopup) { _ in
            getFriends()
            FriendsLength = Friends.count
        }
    }
    
    func getFriends() {
        Friends = dataStore.fetchFriends(userID: userID)
    }
}






//struct FriendsView_Previews: PreviewProvider {
//    static var previews: some View {
//        FriendsView()
//    }
//}
