import WidgetKit
import SwiftUI
import AppIntents
import home_widget

// MARK: - Models
struct UpNextItem: Codable, Hashable {
    let showId: Int
    let showName: String
    let header: String
    let episodeTitle: String
    let episodeDetails: String
    let localPosterPath: String?
    var imageData: Data? = nil
    let episodeKey: String
}

// MARK: - Intents
@available(iOS 17.0, *)
struct MarkAsWatchedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark as Watched"
    
    @Parameter(title: "Show ID")
    var showId: Int
    
    @Parameter(title: "Episode Key")
    var episodeKey: String
    
    init() {}
    
    init(showId: Int, episodeKey: String) {
        self.showId = showId
        self.episodeKey = episodeKey
    }
    
    func perform() async throws -> some IntentResult {
        let urlString = "tvtimeapp://mark_watched?showId=\(showId)&episodeKey=\(episodeKey)"
        if let url = URL(string: urlString) {
            await HomeWidgetBackgroundWorker.run(url: url, appGroup: "group.tvtimeapp.widget")
        }
        return .result()
    }
}

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let dummy1 = UpNextItem(showId: 1, showName: "House of the Dragon", header: "NEXT SEASON", episodeTitle: "S3, E1", episodeDetails: "1h6m · Salt and Sea...", localPosterPath: nil, episodeKey: "S3E1")
        let dummy2 = UpNextItem(showId: 2, showName: "The Boys", header: "UPCOMING", episodeTitle: "S4, E8", episodeDetails: "1h · Season Finale", localPosterPath: nil, episodeKey: "S4E8")
        let dummy3 = UpNextItem(showId: 3, showName: "Severance", header: "NEXT SEASON", episodeTitle: "S2, E1", episodeDetails: "50m", localPosterPath: nil, episodeKey: "S2E1")
        return SimpleEntry(date: Date(), items: [dummy1, dummy2, dummy3])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let dummy1 = UpNextItem(showId: 1, showName: "House of the Dragon", header: "NEXT SEASON", episodeTitle: "S3, E1", episodeDetails: "1h6m · Salt and Sea...", localPosterPath: nil, episodeKey: "S3E1")
        let dummy2 = UpNextItem(showId: 2, showName: "The Boys", header: "UPCOMING", episodeTitle: "S4, E8", episodeDetails: "1h · Season Finale", localPosterPath: nil, episodeKey: "S4E8")
        let dummy3 = UpNextItem(showId: 3, showName: "Severance", header: "NEXT SEASON", episodeTitle: "S2, E1", episodeDetails: "50m", localPosterPath: nil, episodeKey: "S2E1")
        completion(SimpleEntry(date: Date(), items: [dummy1, dummy2, dummy3]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.tvtimeapp.widget")
        let jsonString = userDefaults?.string(forKey: "up_next_items") ?? "[]"
        
        var items: [UpNextItem] = []
        if let data = jsonString.data(using: .utf8) {
            items = (try? JSONDecoder().decode([UpNextItem].self, from: data)) ?? []
        }
        
        // Fetch images
        for i in 0..<items.count {
            if let urlString = items[i].localPosterPath, let url = URL(string: urlString) {
                items[i].imageData = try? Data(contentsOf: url)
            }
        }
        
        let entry = SimpleEntry(date: Date(), items: items)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let items: [UpNextItem]
}

// MARK: - Views
struct UpNextWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            if entry.items.isEmpty {
                VStack {
                    Text("Up Next")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("No shows to watch.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    let itemCount = CGFloat(entry.items.count)
                    let itemHeight = geometry.size.height / max(itemCount, 1)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(entry.items.enumerated()), id: \.offset) { index, item in
                            ItemRow(item: item)
                                .frame(height: itemHeight)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "tvtimeapp://"))
    }
}

struct ItemRow: View {
    let item: UpNextItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Poster
            Group {
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 55, height: 80)
            .cornerRadius(12)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.header)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.6))
                    .textCase(.uppercase)
                
                Text(item.showName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.bottom, 2)
                
                Text(item.episodeTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.episodeDetails)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Mark As Watched Button - only show if episode can be marked
            if !item.episodeKey.isEmpty {
                if #available(iOS 17.0, *) {
                    Button(intent: MarkAsWatchedIntent(showId: item.showId, episodeKey: item.episodeKey)) {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 24)
                } else {
                    // Fallback for iOS 16
                    Link(destination: URL(string: "tvtimeapp://show/\(item.showId)")!) {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                    .padding(.top, 24)
                }
            }
        }
        .frame(height: 80)
    }
}

@main
struct UpNextWidget: Widget {
    let kind: String = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                UpNextWidgetEntryView(entry: entry)
                    .containerBackground(Color(red: 32/255, green: 32/255, blue: 34/255), for: .widget)
            } else {
                UpNextWidgetEntryView(entry: entry)
                    .background(Color(red: 32/255, green: 32/255, blue: 34/255))
            }
        }
        .configurationDisplayName("Up Next")
        .description("Shows your next episodes to watch.")
        .supportedFamilies([.systemLarge]) // Force system large as requested
        .contentMarginsDisabled()
    }
}
