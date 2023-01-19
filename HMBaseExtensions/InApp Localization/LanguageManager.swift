import Foundation
import RxSwift
import RxCocoa

enum AppLanguages: String, CaseIterable {
    case english = "en"
    case armenian = "hy"
    case russian = "ru"
}

private struct AssociatedKeys {
    static var bundle = "_bundle"
}

public let languageChangeNotification = Notification.Name("am.hovhannes.personal.language.manager.language.change")

open class LanguageManager {
    private enum Keys: String {
        case current
    }
    // Test
    static let sInstance = LanguageManager()
    private static let localization = "am.hovhannes.personal.language.manager"
    private let userDefaults = UserDefaults(suiteName: "am.hovhannes.personal.language.manager.userdefaults")
    private lazy var supportedLanguages = Bundle.main.localizations
    
    private init() {
        if userDefaults?.string(forKey: Keys.current.rawValue) == nil {
            userDefaults?.set(Bundle.main.preferredLocalizations.first, forKey: Keys.current.rawValue)
        }
    }
    
    public var languageChange: PublishRelay<String?> = PublishRelay()
    public var currentLocalized: String? {
        let identifier = LanguageManager.current().valueOr("en")
        let locale = NSLocale(localeIdentifier: identifier)
        return locale.displayName(forKey: NSLocale.Key.identifier, value: identifier)
    }
    
    public static func current() -> String? {
        return sInstance.userDefaults?.string(forKey: Keys.current.rawValue)
    }
    
    public static func setCurrent(_ value: String?) {
        if let lang = value {
            sInstance.userDefaults?.set(lang, forKey: Keys.current.rawValue)
            // important to post value after set in userDefaults
            sInstance.languageChange.accept(lang)
        } else {
            let lang = Bundle.main.preferredLocalizations.first
            sInstance.userDefaults?.set(lang, forKey: Keys.current.rawValue)
            // important to post value after set in userDefaults
            sInstance.languageChange.accept(lang)
        }
        NotificationCenter.default.post(name: languageChangeNotification, object: self)
    }
    
    public static func setCurrent(_ index: Int) {
        let lang = sInstance.supportedLanguages[index]
        sInstance.userDefaults?.set(lang, forKey: Keys.current.rawValue)
        // important to post value after set in userDefaults
        sInstance.languageChange.accept(lang)
        NotificationCenter.default.post(name: languageChangeNotification, object: self)
    }
    
    public static func localizedstring(_ key: String, comment: String = "") -> String {
        let bundle = Bundle.main
        guard let countryCode = current(),
            let path = bundle.path(forResource: countryCode, ofType: "lproj"),
            let string = Bundle(path: path)?.localizedString(forKey: key, value: "", table: "") else {
                return NSLocalizedString(key, comment: comment)
        }
        return string
    }
    
    public static func localizedIdentifiers() -> [String] {
        var identifiers = [String]()
        guard let current = LanguageManager.current() else {
            return identifiers
        }
        let languages = sInstance.supportedLanguages
        let locale = NSLocale(localeIdentifier: current)
        for language in languages {
            if let name = locale.displayName(forKey: NSLocale.Key.identifier, value: language) {
                identifiers.append(name)
            }
        }
        return identifiers
    }
    
    func replaceTranslations(pairs: [String: String], for language: String) {
        Bundle.replaceTranslations(pairs: pairs, for: language)
    }
}

extension String {
    public var localized: String {
        return LanguageManager.localizedstring(self)
    }
}

private class BundleEx: Bundle {
    static var currentLangauge: AppLanguages = .english
    static var replacedTranslations: [String: [String: String]] = [:]
    
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if
            let languageDic = BundleEx.replacedTranslations[BundleEx.currentLangauge.rawValue],
            let val = languageDic[key] {
            return val
        }
        if let bundle = objc_getAssociatedObject(self, &AssociatedKeys.bundle) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        } else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
    }
}

extension Bundle {
    private class DispatchOnce {
        static let initialize: Void = {
            _ = exchangeBundles
            _ = copyBundlesToDocuments
        } ()
        
        static let exchangeBundles: Any? = {object_setClass(Bundle.main, BundleEx.self)}()
        static let copyBundlesToDocuments: Any? = {
            AppLanguages.allCases.map { $0.rawValue }.forEach { try? copyLPROJToDocumentsDir($0) }
        }()
    }
    
    static func setLanguage(_ language: AppLanguages) {
        BundleEx.currentLangauge = language
        setLanguage(language.rawValue)
    }
    
    static func setLanguage(_ name: String) {
        _ = DispatchOnce.initialize
        guard let documentsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let url = documentsURL.appendingPathComponent(name + ".lproj")
        let value = Bundle(url: url)
        objc_setAssociatedObject(Bundle.main, &AssociatedKeys.bundle, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    static func replaceTranslations(pairs: [String: String], for language: String) {
        DispatchOnce.initialize
        var dic = BundleEx.replacedTranslations[language] ?? [:]
        for (key, value) in pairs {
            dic[key] = value
        }
        BundleEx.replacedTranslations[language] = dic
    }
}

private func copyLPROJToDocumentsDir(_ name: String) throws {
    guard
        let url = Bundle.main.url(forResource: name, withExtension: "lproj"),
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    
    if !FileManager.default.fileExists(atPath: appSupportURL.path) {
        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    let destination = appSupportURL.appendingPathComponent(url.lastPathComponent)
    
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.copyItem(at: url, to: destination)
}


