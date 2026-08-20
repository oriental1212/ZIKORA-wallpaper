import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct LocalizationTests {
    @Test("Every user message key resolves in English and Simplified Chinese")
    func userMessagesResolve() throws {
        let english = try localizedBundle(language: "en")
        let chinese = try localizedBundle(language: "zh-Hans")

        for key in UserMessageKey.allCases {
            let englishValue = english.localizedString(forKey: key.rawValue, value: nil, table: nil)
            let chineseValue = chinese.localizedString(forKey: key.rawValue, value: nil, table: nil)

            #expect(englishValue != key.rawValue)
            #expect(chineseValue != key.rawValue)
            #expect(!englishValue.isEmpty)
            #expect(!chineseValue.isEmpty)
        }
    }

    @Test("Product terminology stays consistent in Simplified Chinese")
    func terminology() throws {
        let chinese = try localizedBundle(language: "zh-Hans")

        #expect(chinese.localizedString(forKey: "action.update-now", value: nil, table: nil) == "立即更新")
        #expect(chinese.localizedString(forKey: "action.next-wallpaper", value: nil, table: nil) == "换一张")
        #expect(chinese.localizedString(forKey: "dashboard.title", value: nil, table: nil) == "仪表盘")
        #expect(chinese.localizedString(forKey: "menu.quit", value: nil, table: nil) == "退出")
        #expect(chinese.localizedString(forKey: "onboarding.welcome", value: nil, table: nil) == "欢迎使用 ZIKORA")
    }

    private func localizedBundle(language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}
