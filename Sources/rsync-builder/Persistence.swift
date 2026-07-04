import Defaults

// профили серверов и исключения хранятся в UserDefaults через Defaults (Codable-бридж)
extension ServerProfile: Defaults.Serializable {}
extension ExcludeItem: Defaults.Serializable {}

extension Defaults.Keys {
    static let profiles = Key<[ServerProfile]>("profiles", default: defaultProfiles)
    static let excludes = Key<[ExcludeItem]>("excludes", default: defaultExcludes)
}
