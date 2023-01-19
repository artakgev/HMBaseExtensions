import Foundation
import RxSwift
import RxCocoa

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
}

extension String {
    public var localized: String {
        return LanguageManager.localizedstring(self)
    }
}

