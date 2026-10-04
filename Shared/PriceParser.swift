//
//  PriceParser.swift
//  Gifted
//

import Foundation

nonisolated enum PriceParser {
    /// Parses prices as written on shop pages or typed by people, e.g. "$1,299.00",
    /// "1.299,00 €", "49.95", "1 299". Returns nil when there's no usable number.
    static func parse(_ text: String) -> Decimal? {
        let kept = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard kept.contains(where: \.isNumber) else { return nil }

        let lastDot = kept.lastIndex(of: ".")
        let lastComma = kept.lastIndex(of: ",")
        var normalised: String

        switch (lastDot, lastComma) {
        case let (dot?, comma?):
            // Both present: whichever comes last is the decimal separator.
            let decimalSeparator: Character = dot > comma ? "." : ","
            let groupingSeparator: Character = decimalSeparator == "." ? "," : "."
            normalised = kept.filter { $0 != groupingSeparator }
            if decimalSeparator == "," { normalised = normalised.replacingOccurrences(of: ",", with: ".") }
        case (nil, let comma?):
            // Only commas: "12,50" is a decimal, "1,299" or "1,299,000" are grouping.
            let digitsAfter = kept.distance(from: comma, to: kept.endIndex) - 1
            let commaCount = kept.filter { $0 == "," }.count
            if commaCount == 1 && digitsAfter != 3 {
                normalised = kept.replacingOccurrences(of: ",", with: ".")
            } else {
                normalised = kept.replacingOccurrences(of: ",", with: "")
            }
        case (_?, nil):
            // Only dots: "1.299.000" is grouping, "49.95" is a decimal.
            if kept.filter({ $0 == "." }).count > 1 {
                normalised = kept.replacingOccurrences(of: ".", with: "")
            } else {
                normalised = kept
            }
        case (nil, nil):
            normalised = kept
        }

        normalised = normalised.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return Decimal(string: normalised, locale: Locale(identifier: "en_US_POSIX"))
    }
}
