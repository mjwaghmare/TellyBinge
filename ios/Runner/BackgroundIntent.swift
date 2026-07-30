import AppIntents
import Foundation
import home_widget
import WidgetKit
import os.log

private let widgetLogger = Logger(subsystem: "tvtimeapp.widget", category: "UpNextWidget")

@available(iOS 17.0, *)
public struct MarkAsWatchedIntent: AppIntent {
    public static var title: LocalizedStringResource = "Mark as Watched"
    
    @Parameter(title: "Show ID")
    public var showId: Int
    
    @Parameter(title: "Episode Key")
    public var episodeKey: String
    
    public init() {}
    
    public init(showId: Int, episodeKey: String) {
        self.showId = showId
        self.episodeKey = episodeKey
    }
    
    public func perform() async throws -> some IntentResult {
        let rawShowId = String(showId)
        widgetLogger.notice("👉 [Widget Tap] MarkAsWatchedIntent triggered for showId: \(rawShowId, privacy: .public), episodeKey: \(episodeKey, privacy: .public)")
        var components = URLComponents(string: "tvtimeapp://mark_watched")
        components?.queryItems = [
            URLQueryItem(name: "showId", value: rawShowId),
            URLQueryItem(name: "episodeKey", value: episodeKey)
        ]
        if let url = components?.url {
            await HomeWidgetBackgroundWorker.run(url: url, appGroup: "group.tvtimeapp.widget")
        } else {
            widgetLogger.error("❌ [Widget Tap] Failed to construct mark_watched URL for showId: \(rawShowId, privacy: .public)")
        }
        
        // Give background Dart isolate 500ms to finish optimistic Firestore & UserDefaults write
        try? await Task.sleep(nanoseconds: 500_000_000)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
