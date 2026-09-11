import Foundation

enum AvatarPresetGroup: String, CaseIterable, Identifiable {
    case parents = "Parents"
    case children = "Children"
    case extendedTribe = "Extended Tribe"
    case drivers = "Drivers"

    var id: String { rawValue }
}

struct AvatarPresetOption: Identifiable, Hashable {
    let key: String
    let group: AvatarPresetGroup

    var id: String { key }
    var assetName: String { AvatarPresetCatalog.assetName(for: key) }
}

enum AvatarPresetCatalog {
    static let parents: [AvatarPresetOption] = [
        AvatarPresetOption(key: "african_mother_happy", group: .parents),
        AvatarPresetOption(key: "african_father_happy", group: .parents),
        AvatarPresetOption(key: "european_mother_happy", group: .parents),
        AvatarPresetOption(key: "european_father_happy", group: .parents),
        AvatarPresetOption(key: "asian_mother_happy", group: .parents),
        AvatarPresetOption(key: "asian_father_happy", group: .parents)
    ]

    static let children: [AvatarPresetOption] = [
        AvatarPresetOption(key: "child_boy_4_6_happy", group: .children),
        AvatarPresetOption(key: "african_boy_4_6_happy", group: .children),
        AvatarPresetOption(key: "child_boy_6_10_happy", group: .children),
        AvatarPresetOption(key: "african_boy_7_10_happy", group: .children),
        AvatarPresetOption(key: "european_boy_11_14_happy", group: .children),
        AvatarPresetOption(key: "african_boy_11_14_happy", group: .children),
        AvatarPresetOption(key: "african_girl_4_6_happy", group: .children),
        AvatarPresetOption(key: "european_girl_4_6_happy", group: .children),
        AvatarPresetOption(key: "child_girl_6_10_happy", group: .children),
        AvatarPresetOption(key: "european_girl_7_10_happy", group: .children),
        AvatarPresetOption(key: "african_girl_11_14_happy", group: .children),
        AvatarPresetOption(key: "european_girl_11_14_happy", group: .children)
    ]

    static let extendedTribe: [AvatarPresetOption] = [
        AvatarPresetOption(key: "european_grandmother_happy", group: .extendedTribe),
        AvatarPresetOption(key: "african_grandmother_happy", group: .extendedTribe),
        AvatarPresetOption(key: "granddad_cap_happy", group: .extendedTribe),
        AvatarPresetOption(key: "african_grandfather_happy", group: .extendedTribe)
    ]

    static let drivers: [AvatarPresetOption] = [
        AvatarPresetOption(key: "driver_male_happy", group: .drivers),
        AvatarPresetOption(key: "african_father_happy", group: .drivers),
        AvatarPresetOption(key: "european_father_happy", group: .drivers),
        AvatarPresetOption(key: "asian_father_happy", group: .drivers)
    ]

    static var allOptions: [AvatarPresetOption] {
        parents + children + extendedTribe + drivers
    }

    static var groupedSections: [(group: AvatarPresetGroup, options: [AvatarPresetOption])] {
        AvatarPresetGroup.allCases.map { group in
            (group, allOptions.filter { $0.group == group })
        }
    }

    static let defaultChildKey = "child_boy_6_10_happy"
    static let defaultAdultKey = "european_mother_happy"
    static let defaultExtendedTribeKey = "european_grandmother_happy"
    static let defaultDriverKey = "driver_male_happy"

    static func assetName(for key: String) -> String {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("preset_") {
            return normalized
        }
        if normalized.hasPrefix("avatar_") {
            return normalized
        }
        return "preset_\(normalized)"
    }

    static func isKnownPresetKey(_ key: String?) -> Bool {
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return false
        }
        return allOptions.contains(where: { $0.key == key })
    }

    static func defaultKey(for memberType: MemberType) -> String {
        memberType == .child ? defaultChildKey : defaultAdultKey
    }

    static func options(for memberType: MemberType, isDriver: Bool = false) -> [AvatarPresetOption] {
        switch memberType {
        case .child:
            return children
        case .adult:
            if isDriver {
                return drivers + parents
            }
            return parents + extendedTribe
        }
    }

    // MARK: - Child avatar picker (Add Child flow)

    static let childAvatarOptions: [ChildAvatarOption] = [
        ChildAvatarOption(key: "child_boy_4_6_happy", displayName: "Classic", gender: .boy, ageBand: .fourToSix),
        ChildAvatarOption(key: "african_boy_4_6_happy", displayName: "African", gender: .boy, ageBand: .fourToSix),
        ChildAvatarOption(key: "child_boy_6_10_happy", displayName: "Classic", gender: .boy, ageBand: .sixToTen),
        ChildAvatarOption(key: "african_boy_7_10_happy", displayName: "African", gender: .boy, ageBand: .sixToTen),
        ChildAvatarOption(key: "european_boy_11_14_happy", displayName: "European", gender: .boy, ageBand: .nineToTwelve),
        ChildAvatarOption(key: "african_boy_11_14_happy", displayName: "African", gender: .boy, ageBand: .nineToTwelve),
        ChildAvatarOption(key: "african_girl_4_6_happy", displayName: "African", gender: .girl, ageBand: .fourToSix),
        ChildAvatarOption(key: "european_girl_4_6_happy", displayName: "European", gender: .girl, ageBand: .fourToSix),
        ChildAvatarOption(key: "child_girl_6_10_happy", displayName: "Classic", gender: .girl, ageBand: .sixToTen),
        ChildAvatarOption(key: "european_girl_7_10_happy", displayName: "European", gender: .girl, ageBand: .sixToTen),
        ChildAvatarOption(key: "african_girl_11_14_happy", displayName: "African", gender: .girl, ageBand: .nineToTwelve),
        ChildAvatarOption(key: "european_girl_11_14_happy", displayName: "European", gender: .girl, ageBand: .nineToTwelve)
    ]

    static func childAvatarSections() -> [(title: String, options: [ChildAvatarOption])] {
        ChildAvatarGender.allCases.flatMap { gender in
            ChildAvatarAgeBand.allCases.compactMap { band in
                let options = childAvatarOptions.filter { $0.gender == gender && $0.ageBand == band }
                guard !options.isEmpty else { return nil }
                return ("\(gender.sectionTitle) \(band.title)", options)
            }
        }
    }

    static func defaultChildAvatarKey(for dateOfBirth: Date?) -> String {
        guard let dateOfBirth else { return defaultChildKey }
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 8
        switch age {
        case ...6:
            return "child_boy_4_6_happy"
        case 7...10:
            return defaultChildKey
        default:
            return "european_boy_11_14_happy"
        }
    }

    static func childAvatarOption(for key: String) -> ChildAvatarOption? {
        childAvatarOptions.first { $0.key == key }
    }
}

enum ChildAvatarGender: String, CaseIterable, Hashable {
    case boy
    case girl

    var sectionTitle: String {
        switch self {
        case .boy: return "Boys"
        case .girl: return "Girls"
        }
    }
}

enum ChildAvatarAgeBand: String, CaseIterable, Hashable {
    case fourToSix
    case sixToTen
    case nineToTwelve

    var title: String {
        switch self {
        case .fourToSix: return "4–6"
        case .sixToTen: return "6–10"
        case .nineToTwelve: return "9–12"
        }
    }
}

struct ChildAvatarOption: Identifiable, Hashable {
    let key: String
    let displayName: String
    let gender: ChildAvatarGender
    let ageBand: ChildAvatarAgeBand

    var id: String { key }
    var assetName: String { AvatarPresetCatalog.assetName(for: key) }
    var accessibilityLabel: String {
        "\(displayName) \(gender.sectionTitle.lowercased()) \(ageBand.title)"
    }
}
