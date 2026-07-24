import Foundation

/// Resolves resources from the .app bundle's Resources directory.
enum BundledResource {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
    }

    static func path(forResource name: String, ofType type: String) -> String? {
        Bundle.main.path(forResource: name, ofType: type)
    }
}
