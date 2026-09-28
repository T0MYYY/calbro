import Foundation
import HealthKit

struct HealthBodyMetrics: Equatable, Sendable {
    var weightKilograms: Double?
    var heightCentimeters: Double?
    var age: Int?
    var sex: BiologicalSex?

    var isEmpty: Bool { weightKilograms == nil && heightCentimeters == nil && age == nil && sex == nil }
}

protocol HealthDataProviding: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization(for settings: HealthSettings) async throws
    func bodyMetrics() async -> HealthBodyMetrics
    func weightHistory(days: Int) async -> [WeightEntry]
    func activeEnergyToday() async -> Int?
    func saveMeal(_ meal: LoggedMeal) async throws
    func deleteMeal(id: UUID) async throws
}

final class HealthKitService: HealthDataProviding, @unchecked Sendable {
    private let store = HKHealthStore()
    private static let mealIDKey = "CalBroMealID"

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    nonisolated(unsafe) private static let dietaryTypes: [(HKQuantityTypeIdentifier, HKUnit, KeyPath<LoggedMeal, Int>)] = [
        (.dietaryEnergyConsumed, .kilocalorie(), \.adjustedCalories),
        (.dietaryProtein, .gram(), \.adjustedProtein),
        (.dietaryCarbohydrates, .gram(), \.adjustedCarbs),
        (.dietaryFatTotal, .gram(), \.adjustedFat)
    ]

    func requestAuthorization(for settings: HealthSettings) async throws {
        var read = Set<HKObjectType>()
        var share = Set<HKSampleType>()
        if settings.readBody {
            read.formUnion([HKQuantityType(.bodyMass), HKQuantityType(.height),
                            HKCharacteristicType(.dateOfBirth), HKCharacteristicType(.biologicalSex)])
        }
        if settings.useActiveEnergy {
            read.insert(HKQuantityType(.activeEnergyBurned))
        }
        if settings.writeMeals {
            share.formUnion(Self.dietaryTypes.map { HKQuantityType($0.0) })
        }
        guard !read.isEmpty || !share.isEmpty else { return }
        try await store.requestAuthorization(toShare: share, read: read)
    }

    func bodyMetrics() async -> HealthBodyMetrics {
        var metrics = HealthBodyMetrics()
        metrics.weightKilograms = await latestValue(.bodyMass, unit: .gramUnit(with: .kilo))
        metrics.heightCentimeters = await latestValue(.height, unit: .meterUnit(with: .centi))
        if let comps = try? store.dateOfBirthComponents(),
           let birth = Calendar.current.date(from: comps),
           let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year,
           (13...110).contains(years) {
            metrics.age = years
        }
        switch (try? store.biologicalSex())?.biologicalSex {
        case .male:   metrics.sex = .male
        case .female: metrics.sex = .female
        case .other:  metrics.sex = .other
        default:      break
        }
        return metrics
    }

    func weightHistory(days: Int) async -> [WeightEntry] {
        let start = Date().adding(days: -days)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        return samples.map {
            WeightEntry(date: $0.endDate, kilograms: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)), source: .health)
        }
    }

    func activeEnergyToday() async -> Int? {
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.activeEnergyBurned), predicate: predicate),
            options: .cumulativeSum
        )
        guard let stats = try? await descriptor.result(for: store),
              let sum = stats.sumQuantity() else { return nil }
        return Int(sum.doubleValue(for: .kilocalorie()).rounded())
    }

    /// Writes (or overwrites, via sync identifiers) the meal's energy and macros.
    func saveMeal(_ meal: LoggedMeal) async throws {
        let version = Int(Date().timeIntervalSince1970)
        let samples: [HKQuantitySample] = Self.dietaryTypes.map { id, unit, value in
            HKQuantitySample(
                type: HKQuantityType(id),
                quantity: HKQuantity(unit: unit, doubleValue: Double(meal[keyPath: value])),
                start: meal.timestamp, end: meal.timestamp,
                metadata: [
                    HKMetadataKeyFoodType: meal.name,
                    HKMetadataKeySyncIdentifier: "\(meal.id.uuidString).\(id.rawValue)",
                    HKMetadataKeySyncVersion: version,
                    Self.mealIDKey: meal.id.uuidString
                ]
            )
        }
        try await store.save(samples)
    }

    func deleteMeal(id: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: Self.mealIDKey, allowedValues: [id.uuidString])
        for (type, _, _) in Self.dietaryTypes {
            _ = try await store.deleteObjects(of: HKQuantityType(type), predicate: predicate)
        }
    }

    private func latestValue(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return (try? await descriptor.result(for: store))?.first?.quantity.doubleValue(for: unit)
    }
}
