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
            // Await completion of background Dart/native work (Firebase and UserDefaults writes)
            await HomeWidgetBackgroundWorker.run(url: url, appGroup: "group.tvtimeapp.widget")
        } else {
            widgetLogger.error("❌ [Widget Tap] Failed to construct mark_watched URL for showId: \(rawShowId, privacy: .public)")
        }
        
        // Reload timelines immediately upon completion signal
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Required so the intent is performed in the *app* process rather than the
/// widget extension. HomeWidgetBackgroundWorker's Flutter engine and method
/// channel are only ever set up by registerInteractivityCallback, which runs in
/// the app. Without this conformance the extension gets the intent, finds
/// isSetupCompleted == false, and awaits a continuation nothing will resume —
/// perform() hangs, reloadAllTimelines() never fires, and the tap does nothing.
/// The iOSApplicationExtension-unavailable attribute keeps the widget target
/// compiling with the same source file.
@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension MarkAsWatchedIntent: ForegroundContinuableIntent {}
