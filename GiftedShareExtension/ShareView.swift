//
//  ShareView.swift
//  GiftedShareExtension
//

import SwiftUI
import UIKit

struct ShareView: View {
    @Bindable var model: ShareModel

    var body: some View {
        NavigationStack {
            Form {
                if let imageData = model.imageData, let image = UIImage(data: imageData) {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    }
                }

                Section {
                    TextField("What is it?", text: $model.title, axis: .vertical)
                        .font(.headline)
                    HStack {
                        Picker("Currency", selection: $model.currencyCode) {
                            ForEach(currencyCodes, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        TextField("Price", text: $model.priceText)
                            .keyboardType(.decimalPad)
                    }
                    TextField("Notes", text: $model.notes, axis: .vertical)
                } footer: {
                    if model.isFetchingDetails {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("Getting details from the page…")
                        }
                    } else if let host = model.link?.host() {
                        Text(host)
                    }
                }

                if model.lists.count > 1 {
                    Section {
                        Picker("Wishlist", selection: $model.selectedListID) {
                            ForEach(model.lists) { Text($0.name).tag($0.id) }
                        }
                    }
                }

                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Add to Gifted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: model.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: model.save)
                        .disabled(!model.canSave)
                }
            }
        }
        .tint(Color(red: 76 / 255, green: 159 / 255, blue: 148 / 255))
    }

    private var currencyCodes: [String] {
        var codes = ["AUD", "USD", "NZD", "GBP", "EUR", "CAD", "JPY", "CNY", "HKD", "SGD"]
        if !codes.contains(model.currencyCode) { codes.append(model.currencyCode) }
        return codes
    }
}
