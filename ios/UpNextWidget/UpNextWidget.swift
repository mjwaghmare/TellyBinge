import WidgetKit
import SwiftUI
import AppIntents
import home_widget
import os.log

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

extension UpNextItem {
    var showURL: URL? {
        guard showId > 0 else { return nil }
        return URL(string: "tvtimeapp://show/\(showId)")
    }
    
    var markWatchedURL: URL? {
        guard showId > 0, !episodeKey.isEmpty else { return nil }
        var components = URLComponents(string: "tvtimeapp://mark_watched")
        components?.queryItems = [
            URLQueryItem(name: "showId", value: String(showId)),
            URLQueryItem(name: "episodeKey", value: episodeKey)
        ]
        return components?.url
    }
}


// MARK: - Constants & Logging
enum WidgetConstants {
    static let appGroup = "group.tvtimeapp.widget"
    static let widgetKind = "UpNextWidget"
    static let backgroundColor = Color(red: 32/255, green: 32/255, blue: 34/255)
}

private let widgetLogger = Logger(subsystem: "tvtimeapp.widget", category: "UpNextWidget")

// MARK: - Image loading
enum PosterImageLoader {
    /// Widget timeline providers get a tight execution budget — keep this
    /// well under iOS's kill threshold for widget extensions.
    private static let requestTimeout: TimeInterval = 4

    /// Simple on-disk cache inside the shared app group container so repeat
    /// timeline reloads don't re-download the same poster every time.
    private static var cacheDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetConstants.appGroup)?
            .appendingPathComponent("poster_cache", isDirectory: true)
    }

    private static func cacheFileURL(for remoteURL: URL) -> URL? {
        guard let dir = cacheDirectory else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = remoteURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return dir.appendingPathComponent(filename)
    }

    static func loadData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else {
            widgetLogger.error("Invalid poster URL: \(urlString)")
            return nil
        }

        // Local file (already-downloaded path), not a network fetch.
        if url.isFileURL {
            return try? Data(contentsOf: url)
        }

        // Serve from cache if present — avoids network entirely on repeat reloads.
        if let cacheURL = cacheFileURL(for: url),
           let cached = try? Data(contentsOf: cacheURL) {
            return cached
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                widgetLogger.error("Poster fetch non-200 for \(url.absoluteString)")
                return nil
            }
            if let cacheURL = cacheFileURL(for: url) {
                try? data.write(to: cacheURL)
            }
            return data
        } catch {
            widgetLogger.error("Poster fetch failed for \(url.absoluteString): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Provider
let previewItems: [UpNextItem] = [
    UpNextItem(showId: 1, showName: "House of the Dragon", header: "NEXT SEASON", episodeTitle: "S3, E1", episodeDetails: "1h6m · Salt and Sea...", localPosterPath: nil, episodeKey: "S3E1"),
    UpNextItem(showId: 2, showName: "The Boys", header: "UPCOMING", episodeTitle: "S4, E8", episodeDetails: "1h · Season Finale", localPosterPath: nil, episodeKey: "S4E8"),
    UpNextItem(showId: 3, showName: "Severance", header: "NEXT SEASON", episodeTitle: "S2, E1", episodeDetails: "50m", localPosterPath: nil, episodeKey: "S2E1"),
    UpNextItem(showId: 4, showName: "The Bear", header: "WATCH NEXT", episodeTitle: "S3, E1", episodeDetails: "30m", localPosterPath: nil, episodeKey: "S3E1")
]

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), items: previewItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), items: previewItems))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: WidgetConstants.appGroup)
        let jsonString = userDefaults?.string(forKey: "up_next_items") ?? "[]"

        var items: [UpNextItem] = []
        if let data = jsonString.data(using: .utf8) {
            items = (try? JSONDecoder().decode([UpNextItem].self, from: data)) ?? []
        }

        // Pre-load all poster images in parallel so they all render immediately.
        // Sequential loading (3 × 4s timeout) can hit the widget extension kill budget;
        // parallel loading caps at a single 4-second round-trip regardless of count.
        Task {
            var loadedItems = items
            await withTaskGroup(of: (Int, Data?).self) { group in
                for i in loadedItems.indices {
                    let index = i
                    let path = loadedItems[i].localPosterPath
                    group.addTask {
                        let data: Data?
                        if let path = path {
                            data = await PosterImageLoader.loadData(from: path)
                        } else {
                            data = nil
                        }
                        return (index, data)
                    }
                }
                for await (index, data) in group {
                    loadedItems[index].imageData = data
                }
            }

            let entry = SimpleEntry(date: Date(), items: loadedItems)

            // Refresh at midnight so countdown text ("In 3 days") stays accurate
            let tomorrow = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            )
            let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let items: [UpNextItem]
}

// MARK: - Views
struct UpNextWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            if entry.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                    Text("Watch Next")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("No shows to watch.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if family == .systemMedium {
                // Medium: show first item in a compact horizontal layout
                if let item = entry.items.first {
                    MediumItemRow(item: item)
                }
            } else {
                // Large: show up to 4 items evenly distributed to fill the entire container height
                let visibleItems = Array(entry.items.prefix(4))
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(visibleItems, id: \.showId) { item in
                        ItemRow(item: item)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .widgetURL(URL(string: "tvtimeapp://"))
    }
}

struct ItemRow: View {
    let item: UpNextItem
    
    @ViewBuilder
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 10) {
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
            .frame(width: 44, height: 62)
            .cornerRadius(6)
            .clipped()
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.header)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(white: 0.6))
                    .textCase(.uppercase)
                
                Text(item.showName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.episodeTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.episodeDetails)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var markWatchedButtonContent: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.7)
        }
        .frame(width: 38, height: 38)
        .contentShape(Rectangle())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Tapping poster or title navigates to the show detail page
            if let showURL = item.showURL {
                Link(destination: showURL) {
                    rowContent
                }
            } else {
                rowContent
            }
            
            Spacer(minLength: 4)
            
            // Mark As Watched Button — OUTSIDE the Link so intent fires directly without opening app
            if !item.episodeKey.isEmpty {
                if #available(iOS 17.0, *) {
                    Button(intent: MarkAsWatchedIntent(showId: item.showId, episodeKey: item.episodeKey)) {
                        markWatchedButtonContent
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 40, height: 40)
                } else {
                    if let markWatchedURL = item.markWatchedURL {
                        Link(destination: markWatchedURL) {
                            markWatchedButtonContent
                        }
                        .frame(width: 40, height: 40)
                    } else {
                        markWatchedButtonContent
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget Row
struct MediumItemRow: View {
    let item: UpNextItem
    
    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 14) {
            // Poster — only use pre-loaded imageData; AsyncImage is unreliable
            // in widget extensions due to their tight execution budget.
            Group {
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 65, height: 95)
            .cornerRadius(12)
            .clipped()
            
            // Details
            VStack(alignment: .leading, spacing: 3) {
                Text(item.header)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.6))
                    .textCase(.uppercase)
                
                Text(item.showName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.episodeTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.episodeDetails)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var markWatchedButtonContent: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.7)
        }
        .frame(width: 38, height: 38)
        .contentShape(Rectangle())
    }

    var body: some View {
        HStack(spacing: 14) {
            // Tapping poster or title navigates to the show detail page
            if let showURL = item.showURL {
                Link(destination: showURL) {
                    rowContent
                }
            } else {
                rowContent
            }
            
            Spacer(minLength: 4)
            
            // Mark As Watched Button
            if !item.episodeKey.isEmpty {
                if #available(iOS 17.0, *) {
                    Button(intent: MarkAsWatchedIntent(showId: item.showId, episodeKey: item.episodeKey)) {
                        markWatchedButtonContent
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 40, height: 40)
                } else {
                    if let markWatchedURL = item.markWatchedURL {
                        Link(destination: markWatchedURL) {
                            markWatchedButtonContent
                        }
                        .frame(width: 40, height: 40)
                    } else {
                        markWatchedButtonContent
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .configurationDisplayName("Watch Next")
        .description("Shows your next episodes to watch.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
