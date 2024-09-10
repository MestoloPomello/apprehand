/*import SwiftUI

let defaults = UserDefaults.standard
var chosenLanguage: String =  defaults.string(forKey: "language") ?? "italian"
func getTranslatedText() -> [String: String] {
    switch(chosenLanguage) {
        case "english":
            return EN_TRANSLATED_TEXT
        case "french":
            return FR_TRANSLATED_TEXT
        case "spanish":
            return ES_TRANSLATED_TEXT
        default:
            return IT_TRANSLATED_TEXT
    }
}

class LanguageManager: ObservableObject {
    @Published var translatedText: [String: String] = [:]
    
    init() {
        loadTranslatedText()
    }
    
    func loadTranslatedText() {
        translatedText = getTranslatedText()
    }
    
    func changeLanguage(to language: String) {
        UserDefaults.standard.setValue(language, forKey: "language")
        loadTranslatedText()
    }
}
*/
