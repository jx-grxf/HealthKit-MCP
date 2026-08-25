import Foundation
import HealthKit

/// Maps the catalog's canonical unit strings to HealthKit units.
///
/// Deliberately an explicit table rather than `HKUnit(from:)`: that initialiser
/// raises an Objective-C exception on an unrecognised string, which Swift
/// cannot catch, so one bad catalog entry would crash the sync. Returning nil
/// lets an unmappable metric be skipped instead.
enum MetricUnits {
    static func hkUnit(for canonical: String?) -> HKUnit? {
        guard let canonical else { return nil }
        switch canonical {
        case "count":        return .count()
        case "effortScore":
            if #available(iOS 18.0, *) { return .appleEffortScore() } else { return nil }
        case "kcal":         return .kilocalorie()
        case "m":            return .meter()
        case "cm":           return .meterUnit(with: .centi)
        case "min":          return .minute()
        case "ms":           return .secondUnit(with: .milli)
        // HealthKit's percent unit yields a 0–1 ratio; see `scale`.
        case "%":            return .percent()
        case "degC":         return .degreeCelsius()
        case "kg":           return .gramUnit(with: .kilo)
        case "g":            return .gram()
        case "mg":           return .gramUnit(with: .milli)
        case "mcg":          return .gramUnit(with: .micro)
        case "mL":           return .literUnit(with: .milli)
        case "L":            return .liter()
        case "mmHg":         return .millimeterOfMercury()
        case "IU":           return .internationalUnit()
        case "W":            return .watt()
        case "siemens":      return .siemen()
        case "dBASPL":       return .decibelAWeightedSoundPressureLevel()
        case "count/min":    return HKUnit.count().unitDivided(by: .minute())
        case "L/min":        return HKUnit.liter().unitDivided(by: .minute())
        case "m/s":          return HKUnit.meter().unitDivided(by: .second())
        case "mg/dL":
            return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case "mL/kg*min":
            return HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        case "kcal/kg*hr":
            return HKUnit.kilocalorie()
                .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour()))
        default:
            return nil
        }
    }

    /// Factor applied to HealthKit's raw value before storing.
    ///
    /// `HKUnit.percent()` measures a fraction, so oxygen saturation comes back
    /// as 0.97 and double-support as 0.27. Stored unscaled next to a unit
    /// labelled "%", that reads as 0.27 % — off by two orders of magnitude.
    static func scale(for canonical: String?) -> Double {
        canonical == "%" ? 100 : 1
    }

    /// Whole-number metrics. Cumulative sums are apportioned across day
    /// boundaries, which yields things like 8117.6068 steps.
    static func isWholeNumber(_ canonical: String?) -> Bool {
        canonical == "count"
    }

    /// Which statistic HealthKit should compute for a metric.
    static func statisticsOptions(for aggregation: MetricAggregation) -> HKStatisticsOptions? {
        switch aggregation {
        case .sum:   return .cumulativeSum
        case .avg:   return [.discreteAverage, .discreteMin, .discreteMax]
        case .max:   return .discreteMax
        case .latest: return .mostRecent
        // Category types are not quantities and are handled separately.
        case .duration, .count: return nil
        }
    }
}
