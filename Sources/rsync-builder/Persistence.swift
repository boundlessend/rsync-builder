import Defaults

// профили серверов хранятся в UserDefaults через Defaults (Codable-бридж)
extension ServerProfile: Defaults.Serializable {}

extension Defaults.Keys {
    static let profiles = Key<[ServerProfile]>("profiles", default: defaultProfiles)
}
