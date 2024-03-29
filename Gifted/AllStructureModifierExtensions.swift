//
//  AllStructureModifierExtensions.swift
//  Gifted
//
//  Created by Edwin Tang on 4/12/2022.
//

import SwiftUI
import Foundation
import PhotosUI



// Visual Elements Extensions
extension Text{
    func pretty() -> some View{
        self.font(.title2)
            .multilineTextAlignment(.center)
            .padding(.all)
    }
    
    func colourGradient() -> some View{
        self.multilineTextAlignment(.leading)
            .font(.largeTitle
                .weight(.bold))
            .padding(.top)
            .foregroundStyle(
                LinearGradient(
                    colors: [.init(red: 0.196, green: 0.4, blue: 0.38), .init(red: 0.329, green: 0.698, blue: 0.643), .init(red: 0.701, green: 0.8509803922, blue: 0.466666667)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    func boldText() -> some View {
        self.font(.system(size: 15, weight: .bold, design: .default))
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
        
    }
    func itemText() -> some View{
        self.font(.system(size: 15, weight: .medium, design: .default))
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
            .multilineTextAlignment(.leading)
    }
    
    func subtitle() -> some View{
        self.font(.system(size: 24, weight: .medium, design: .default))
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
    }
    
    func title() -> some View{
        self.font(.system(size: 36, weight: .bold, design: .default))
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
    }
    
    func listtext() -> some View{
        self.font(.subheadline)
            .multilineTextAlignment(.leading)
    }
    
    func medium() -> some View{
        self.font(.footnote)
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
            .multilineTextAlignment(.center)
    }
    func large() -> some View{
        self.font(.callout)
            .multilineTextAlignment(.center)
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
    }
    func homepagename() -> some View{
        self.font(.headline)
            .foregroundColor(.secondary)
    }
    func verif() -> some View{
        self.font(.headline)
    }
}

extension HStack {
    func selected() -> some View{
        self.foregroundColor(Color(.sRGB, red: 37/255, green: 75/255, blue: 72/255))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(.white)
            .padding(.horizontal)
    }
    
    func unSelected() -> some View{
        self.foregroundColor(Color(.sRGB, red: 217/255, green: 217/255, blue: 217/255))
            .padding(.horizontal)
    }
}

extension TextField {
    func pretty() -> some View {
        self.padding()
            .frame(width: UIScreen.main.bounds.size.width*3/4, height: UIScreen.main.bounds.size.height*1/20)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.sRGB, red: 217/255, green: 217/255, blue: 217/255), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
            }
    }
}

extension SecureField {
    func pretty() -> some View {
        self.padding()
            .frame(width: UIScreen.main.bounds.size.width*3/4, height: UIScreen.main.bounds.size.height*1/20)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.sRGB, red: 217/255, green: 217/255, blue: 217/255), lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
            }
    }
}

extension Button {
    func pretty() -> some View {
        self.font(.headline)
            .padding(.all)
            .frame(width: UIScreen.main.bounds.size.width * 7/20, height: UIScreen.main.bounds.size.height * 1/25)
            .foregroundColor(Color(.white))
            .background(Color(.sRGB, red: 76/255, green: 159/255, blue: 148/255))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 2)
            .padding(.all)
    }
    
    func secondary() -> some View {
        self.font(.headline)
            .padding(.all)
            .frame(width: UIScreen.main.bounds.size.width * 7/20, height: UIScreen.main.bounds.size.height * 1/25)
            .foregroundColor(Color(.sRGB, red: 158/255, green: 159/255, blue: 161/255))
            .background(Color(.sRGB, red: 237/255, green: 240/255, blue: 241/255))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 2, y: 2)
            .padding(.all)
    }
    
    func long() -> some View {
        self.font(.headline)
            .padding(.all)
            .frame(width: UIScreen.main.bounds.size.width * 17/20, height: UIScreen.main.bounds.size.height * 1/25)
            .foregroundColor(Color(.sRGB, red: 158/255, green: 159/255, blue: 161/255))
            .border(Color(.sRGB, red: 217/255, green: 217/255, blue: 217/255), width: 1)
            .cornerRadius(10)
            .padding(.all)
    }
    
    func floaty() -> some View {
        self.font(.system(size:60))
            .foregroundColor(Color(.sRGB, red: 76/255, green: 159/255, blue: 148/255))
            .padding(.all)
    }
    func google() -> some View{
        self.font(.body.weight(.medium))
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .foregroundColor(Color(.systemBackground))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.clear.opacity(0.25), lineWidth: 0)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.displayP3, red: 219/255, green: 68/255, blue: 55/255)))
            }
    }
    func facebook() -> some View{
        self.font(.body.weight(.medium))
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .clipped()
            .foregroundColor(Color(.systemBackground))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.displayP3, red: 66/255, green: 103/255, blue: 178/255))
            }
    }
}

extension TextEditor{
    func pretty() -> some View{
        self.padding()
            .border(Color.gray)
            .cornerRadius(3)
    }
}

extension Link{
    func pretty() -> some View{
        self.font(.title3)
            .padding(.all)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(Color.blue)
            .cornerRadius(50)
            .shadow(color: Color.black.opacity(0.2), radius: 30, x: 2, y: 2)
            .padding(.all)
    }
}

extension Image{
    func floaty() -> some View{
        self.font(.system(size:60))
            .foregroundColor(Color(.sRGB, red: 76/255, green: 159/255, blue: 148/255))
            .padding(.all)
    }
    func Icon() -> some View{
        self.renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 50)
            .mask { RoundedRectangle(cornerRadius: 4, style: .continuous) }
    }
}

extension RoundedRectangle {
    func cardBackgroundandShadow(cornerRadius: Double) -> some View {
        self.foregroundColor(.white)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(.sRGB, red: 217/255, green: 217/255, blue: 217/255), lineWidth: 1)
            )
    }
}

extension VStack {
    func loadingFrame() -> some View {
        self.frame(maxWidth: UIScreen.main.bounds.size.width * 9/10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.displayP3, red: 239/255, green: 245/255, blue: 227/255))
            }
    }
}

// Attempted extension for overlay code of who has reserved, not working
//extension VStack{
//    func ImageOverlay(selfQuery: Bool) -> some View{
//        if selfQuery == true {
//            self.padding(.all)
//        } else {
//            self.padding(.all)
//            // Overlay of image to represent people who have reserved the item, No actual logic or data structure attatched to this yet
//                .overlay{
//                    HStack {
//                        Image(systemName: "a.circle.fill")
//                            .imageScale(.large)
//                    }
//                    .font(.title3)
//                    .padding(.horizontal)
//                }
//        }
//    }
//}

// Extension to AppStorage for reset
extension UserDefaults {
    func resetDefaults() {
        let dictionary = self.dictionaryRepresentation()
        let dictKeys = dictionary.keys.filter{ $0 != "AppOpening"}
        dictKeys.forEach({self.removeObject(forKey: $0)})
    }
}

// Code for Labelled Divider
struct LabelledDivider: View {

    let label: String
    let horizontalPadding: CGFloat
    let color: Color

    init(label: String, horizontalPadding: CGFloat = 20, color: Color = .gray) {
        self.label = label
        self.horizontalPadding = horizontalPadding
        self.color = color
    }

    var body: some View {
        HStack {
            line
            Text(label).foregroundColor(color)
            line
        }
    }

    var line: some View {
        VStack { Divider().background(color) }.padding(horizontalPadding)
    }
}

enum ImageType {
    case big
    case small
}

struct profilePicture: View {
    
    let LargeSize = UIScreen.main.bounds.size.width * 3/10
    let smallSize = UIScreen.main.bounds.size.height * 7/100
    
    @State var image: UIImage?
    let size: ImageType
    
    var body: some View {
        if size == .big {
            if let profileImage = image {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: LargeSize, height: LargeSize)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: LargeSize, height: LargeSize)
            }
        } else {
            if let profileImage = image {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: smallSize, height: smallSize)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: smallSize, height: smallSize)
            }
        }
    }
}

struct signoff: View {
    
    var body: some View {
        Text("Brought to you with ❤️ from Edwin, Roger and Michelle")
            .font(.caption)
            .foregroundColor(Color(.sRGB, red: 36/255, green: 74/255, blue: 71/255))
            .multilineTextAlignment(.center)
    }
    
}

//Code for Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}



// AWS Data structure Extensions
extension ListItem: Identifiable {}

extension ListItem: Equatable{
    public static func ==(lhs: ListItem, rhs: ListItem) -> Bool {
        lhs.id == rhs.id && lhs.Name == rhs.Name
    }
}

extension ListItem: Hashable{
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id + Name)
    }
}

extension Group: Identifiable {}

extension Group: Equatable {
    public static func == (lhs: Group, rhs: Group)
        -> Bool {
            lhs.id == rhs.id && lhs.ShortID == rhs.ShortID
    }
}

extension Group: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id + ShortID)
    }
}

extension UserProfile: Identifiable {}

extension UserProfile: Equatable{
    public static func ==(lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id && lhs.Username == rhs.Username
    }
}

extension UserProfile: Hashable{
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id + Username)
    }
}
