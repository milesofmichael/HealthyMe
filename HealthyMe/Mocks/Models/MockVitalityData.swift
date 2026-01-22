//
//  MockVitalityData.swift
//  HealthyMe
//
//  Mock vitality data with healthy defaults for demo mode and unit tests.
//  Tests can override specific properties to test edge cases.
//

import Foundation

/// Mock vitality metrics with healthy defaults.
/// Demo mode uses defaults; tests override specific values as needed.
struct MockVitalityData {
    /// Body weight in pounds (default: average healthy adult)
    var weightLbs: Double = 165

    /// BMI (default: within healthy range 18.5-24.9)
    var bmi: Double? = 23.5

    /// Respiratory rate in breaths/min (default: normal range 12-20)
    var respiratoryRate: Double = 14

    /// Blood oxygen saturation as decimal (default: healthy 98%)
    var oxygenSaturation: Double = 0.98

    /// Wrist temperature deviation from baseline in Celsius (default: near baseline)
    var wristTempDeviation: Double? = 0.1

    /// Converts to VitalityData model for the given period
    func toVitalityData(for period: DateInterval) -> VitalityData {
        VitalityData(
            period: period,
            bodyMass: weightLbs / 2.205,  // Convert lbs to kg
            bodyMassIndex: bmi,
            respiratoryRate: respiratoryRate,
            oxygenSaturation: oxygenSaturation,
            wristTemperature: wristTempDeviation
        )
    }
}
