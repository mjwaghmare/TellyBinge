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
    /// Drives the push transition when a row swaps to a different episode.
    /// `episodeKey` is empty for upcoming (unaired) entries, so the episode code
    /// is folded in to keep the identity distinct across those swaps too.
    var episodeIdentity: String { "\(episodeKey)|\(episodeTitle)" }

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

struct ProfileStats: Codable, Hashable {
    let userName: String
    let showsCount: Int
    let episodesCount: Int
    let showsFormattedTime: String
    let moviesCount: Int
    let moviesFormattedTime: String

    var formattedShowsCount: String {
        formatCompact(showsCount)
    }

    var formattedEpisodesCount: String {
        formatCompact(episodesCount)
    }

    var formattedMoviesCount: String {
        formatCompact(moviesCount)
    }

    private func formatCompact(_ number: Int) -> String {
        if number >= 1_000_000 {
            let num = Double(number) / 1_000_000.0
            return String(format: "%.1fM", num).replacingOccurrences(of: ".0", with: "")
        } else if number >= 1_000 {
            let num = Double(number) / 1_000.0
            return String(format: "%.1fk", num).replacingOccurrences(of: ".0", with: "")
        }
        return "\(number)"
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let items: [UpNextItem]
    let stats: ProfileStats?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            items: previewItems,
            stats: ProfileStats(
                userName: "PopVerse User",
                showsCount: 14,
                episodesCount: 128,
                showsFormattedTime: "12d 4h",
                moviesCount: 48,
                moviesFormattedTime: "5d 18h"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: WidgetConstants.appGroup)
        let jsonString = userDefaults?.string(forKey: "up_next_items") ?? "[]"

        var items: [UpNextItem] = []
        if let data = jsonString.data(using: .utf8) {
            items = (try? JSONDecoder().decode([UpNextItem].self, from: data)) ?? []
        }

        let userName = userDefaults?.string(forKey: "stats_user_name") ?? "PopVerse User"
        let showsCount = userDefaults?.integer(forKey: "stats_shows_count") ?? 0
        let episodesCount = userDefaults?.integer(forKey: "stats_episodes_count") ?? 0
        let showsTime = userDefaults?.string(forKey: "stats_shows_time") ?? "0m"
        let moviesCount = userDefaults?.integer(forKey: "stats_movies_count") ?? 0
        let moviesTime = userDefaults?.string(forKey: "stats_movies_time") ?? "0m"

        let stats = ProfileStats(
            userName: userName.isEmpty ? "PopVerse User" : userName,
            showsCount: showsCount,
            episodesCount: episodesCount,
            showsFormattedTime: showsTime.isEmpty ? "0m" : showsTime,
            moviesCount: moviesCount,
            moviesFormattedTime: moviesTime.isEmpty ? "0m" : moviesTime
        )

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

            let entry = SimpleEntry(date: Date(), items: loadedItems, stats: stats)

            let tomorrow = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            )
            let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
            completion(timeline)
        }
    }
}

// MARK: - Views
struct MediumStatsWidgetView: View {
    let stats: ProfileStats

    // App Theme Brand Colors from AppColors
    private let primaryAmber = Color(red: 255/255, green: 193/255, blue: 7/255) // #FFC107
    private let primaryDarkAmber = Color(red: 255/255, green: 143/255, blue: 0/255) // #FF8F00
    private let airingBlue = Color(red: 33/255, green: 150/255, blue: 243/255) // #2196F3

    var body: some View {
        VStack(spacing: 8) {
            // Header Row: Avatar circle + User Name + STATS badge
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [primaryAmber, primaryDarkAmber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    Text(String(stats.userName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }

                Text(stats.userName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                        .foregroundColor(primaryAmber)
                    Text("STATS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(primaryAmber)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(primaryAmber.opacity(0.18))
                .cornerRadius(6)
            }

            Divider()
                .background(Color.white.opacity(0.15))

            // Stat Cards Row
            HStack(spacing: 8) {
                // TV Shows Card (Airing Blue Theme)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 11))
                            .foregroundColor(airingBlue)
                        Text("SHOWS ADDED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(stats.formattedShowsCount)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("(\(stats.formattedEpisodesCount) eps)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.6))
                        Text(stats.showsFormattedTime)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(airingBlue.opacity(0.3), lineWidth: 1)
                )

                // Movies Card (Primary Amber Gold Theme)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "film.fill")
                            .font(.system(size: 11))
                            .foregroundColor(primaryAmber)
                        Text("MOVIES WATCHED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }

                    Text(stats.formattedMoviesCount)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.6))
                        Text(stats.moviesFormattedTime)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(primaryAmber.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

struct UpNextWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        Group {
            if family == .systemMedium {
                MediumStatsWidgetView(stats: entry.stats ?? ProfileStats(
                    userName: "PopVerse User",
                    showsCount: 0,
                    episodesCount: 0,
                    showsFormattedTime: "0m",
                    moviesCount: 0,
                    moviesFormattedTime: "0m"
                ))
            } else {
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
                } else {
                    let visibleItems = Array(entry.items.prefix(4))
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(visibleItems, id: \.showId) { item in
                            ItemRow(item: item)
                                .frame(maxHeight: .infinity)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(12)
        .widgetURL(URL(string: "tvtimeapp://"))
    }
}

// MARK: - Episode swap animation
/// Slides the outgoing episode off to the trailing edge while the incoming one
/// pushes in from the leading edge.
///
/// The `.id()` is what makes this fire at all — without an identity change
/// SwiftUI just redraws the same text in place and nothing animates. It has to
/// stay *outside* the transition so the identity change removes the whole
/// subtree the transition is attached to.
///
/// Guarded at iOS 17 on purpose: WidgetKit only animates timeline entry changes
/// from 17 onward, and `.push(from:)` itself needs 16 while this target deploys
/// to 15. Below 17 the content simply swaps with no animation.
private struct EpisodeSwapTransition: ViewModifier {
    let identity: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .transition(.push(from: .leading))
                .id(identity)
        } else {
            content
        }
    }
}

private extension View {
    func episodeSwapTransition(identity: String) -> some View {
        modifier(EpisodeSwapTransition(identity: identity))
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
            // Only the text pushes — the poster is the show's, not the
            // episode's, so anchoring it reads as "same show, next episode".
            // (The row itself is keyed by showId in the ForEach, so a different
            // show never reuses this row.)
            .episodeSwapTransition(identity: item.episodeIdentity)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Tapping poster or title navigates to the show detail page
            if let showURL = item.showURL {
                Link(destination: showURL) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                rowContent
            }
            
            Spacer(minLength: 4)
            
            // Mark As Watched Button — OUTSIDE the Link so intent fires directly without opening app
            if !item.episodeKey.isEmpty {
                if #available(iOS 17.0, *) {
                    Button(intent: MarkAsWatchedIntent(showId: item.showId, episodeKey: item.episodeKey)) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color.blue.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 44, height: 44)
                    .zIndex(1)
                } else {
                    if let markWatchedURL = item.markWatchedURL {
                        Link(destination: markWatchedURL) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(Color.blue.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 44, height: 44)
                        .zIndex(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Main Configuration
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
