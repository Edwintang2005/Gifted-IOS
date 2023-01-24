//
//  GroupCardView.swift
//  Gifted
//
//  Created by Roger Yao on 23/1/2023.
//

import Foundation
import SwiftUI

struct GroupCardView: View {
    @State var group: Group
    
    let groupCardWidth = UIScreen.main.bounds.size.width * 1/2
    let groupCardHeight = UIScreen.main.bounds.size.width * 15/100
    let cornerRadius = 10.0


    var body: some View {
        if let groupPhoto = group.ImageKey {
            VStack(alignment: .leading) {
                Image(groupPhoto) //This should be changed to show the photo of the group
                    .resizable()
                    .frame(width: groupCardWidth, height: groupCardHeight)
                    .overlay(alignment: .bottomLeading) {
                        VStack{
                            Text("\(group.Name)").subtitle()
                            Text("\(group.id)").font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
                        }
                    }
                
            }
        } else {
            VStack(alignment: .leading) {
                Text(group.Name)
            }
        }
        
        
    }
}
