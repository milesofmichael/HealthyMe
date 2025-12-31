//
//  Double+Formatting.swift
//  HealthPanda
//
//  Formatting extensions for health metrics display.
//

import Foundation

extension Double {
    /// Formats as whole number (e.g., "72").
    var wholeNumber: String {
        String(format: "%.0f", self)
    }

    /// Formats as percentage change with sign (e.g., "+5.2%" or "-3.1%").
    var percentChangeText: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", self))%"
    }

    /// Formats as parenthetical change text (e.g., " (+5.2%)").
    var parentheticalChange: String {
        " (\(percentChangeText))"
    }
}

extension Optional where Wrapped == Double {
    /// Returns parenthetical change text or empty string if nil.
    var parentheticalChange: String {
        guard let value = self else { return "" }
        return value.parentheticalChange
    }
}
