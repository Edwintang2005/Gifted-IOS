//
//  LoginView.swift
//  Gifted
//
//  Created by Edwin Tang on 3/12/2022.
//

import SwiftUI

struct LoginView: View {
    
    
    // Variables for the input fields to satisfy login functionality
    @State var username = ""
    @State var password = ""
    
    var body: some View {
        VStack {
            // Username signin functionality
            VStack {
                Spacer()
                Text("Welcome to \n Gifted!")
                    .pretty()
                Spacer()
                TextField("Username", text: $username).pretty()
                SecureField("Password", text: $password).pretty()
                Button {
                    
                    print("logged in")
                } label: {
                    Text("Login")
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                }.pretty()
            }
            .padding(.horizontal)
            // The Big line with an or in the middle, for appearances
            LabelledDivider(label: "OR")
            // vertical stack created for easier button placement
            VStack(spacing: 8) {
                HStack{
                    // Button for Gmail Signin
                    Button{ print("LMAO")
                    } label: {
                        HStack{
                            Image(systemName: "envelope.fill")
                                .imageScale(.medium)
                            Text(" Gmail")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }.google()
                    // Button for Facebook signin
                    Button {
                        print("LMAO")
                    } label: {
                        HStack{
                            Image(systemName: "f.cursive")
                                .imageScale(.medium)
                            Text(" Facebook")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }.facebook()
                }
                Spacer()
                Button{print("Show SIgnuop")} label: {Text("Don't have an account? Sign up.")}
                Spacer()
                Text("Brought to you with ❤️ from Edwin Tang and Roger Yao").small()
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Display view (temporary) for unavailable views
struct TempUnavailable: View {

    
    var body: some View{
        VStack{
            Spacer()
            Text("Unfortunately This feature isn't yet Available 😩 \n \n Perhaps in the next Update??").pretty()
            Spacer()
            Text("Or you could just donate to us devs to speed things along, button below!").small()
            Spacer()
            Link("Donate Here!", destination: URL(string:"https://www.youtube.com/watch?v=dQw4w9WgXcQ")!).pretty()
            Button{
                print("Show Login")
            } label: {
                Text("Back to Login")
            }
            Spacer()
        }
    }
}

// Ignore below, simulator code


//struct LoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        LoginView()
//    }
//}


