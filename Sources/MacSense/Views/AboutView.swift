import SwiftUI
import MacSenseCore

enum SupportConfiguration {
    static var url: URL? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "MacSenseSupportURL") as? String,
              let url = URL(string: string), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}
struct SupportView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(L("Спасибо behruzinho за идею и создание MacSense.")).font(.system(size: 12))
            Link("behruzinho · GitHub", destination: URL(string: "https://github.com/behruzinho")!).font(.system(size: 11))
            Text(L("Нравится приложение? Поддержите его развитие чашкой кофе ☕")).font(.system(size: 11)).foregroundStyle(.secondary)
            Button(L("Угостить чашкой кофе"), systemImage: "cup.and.saucer.fill") {
                if let url = SupportConfiguration.url { NSWorkspace.shared.open(url) }
            }.disabled(SupportConfiguration.url == nil)
        }.padding(.vertical, 4)
    }
}
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 45, weight: .light)).foregroundStyle(Palette.blue)
                .frame(width: 94, height: 94).background(Palette.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 23))
            VStack(spacing: 7) {
                Text("MacSense").font(.system(size: 28, weight: .semibold))
                Text(L("Версия \(AppInfo.version)")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Link(L("Создано behruzinho"), destination: URL(string: "https://github.com/behruzinho")!).font(.system(size: 15, weight: .medium))
            Divider()
            SupportView().frame(maxWidth: .infinity, alignment: .leading)
            Text(L("Все данные остаются на Mac")).font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(35).frame(width: 420).background(Palette.background)
    }
}
struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L("О MacSense")) { openWindow(id: "about") }
        }
    }
}
