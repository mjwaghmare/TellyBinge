import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../models/enriched_show.dart';

class UpcomingEpisodeCard extends StatelessWidget {
  final EnrichedShow enrichedShow;

  const UpcomingEpisodeCard({super.key, required this.enrichedShow});

  Widget _buildPillBadge(String label, bool isYellow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 8.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRightSide() {
    final daysLeft = enrichedShow.upcomingDaysLeft;
    final networkName = enrichedShow.upcomingNetworkName;

    if (daysLeft != null && daysLeft >= 7) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$daysLeft',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            daysLeft == 1 ? 'DAY' : 'DAYS',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10.0,
              letterSpacing: 1.0,
            ),
          ),
        ],
      );
    } else if (networkName != null && networkName.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 12),
          Text(
            networkName,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11.0,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final show = enrichedShow;
    final isDummy = show.rawShowData['id'] == -1;
    final showTitle = (show.rawShowData['name'] ?? 'Unknown').toUpperCase();

    final imageUrl =
        show.rawShowData['backdropPath'] != null &&
            show.rawShowData['backdropPath'].toString().isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500${show.rawShowData['backdropPath']}'
        : (show.rawShowData['posterPath'] != null &&
                  show.rawShowData['posterPath'].toString().isNotEmpty
              ? 'https://image.tmdb.org/t/p/w500${show.rawShowData['posterPath']}'
              : '');

    final bool hasChips = show.upcomingIsPremiere || show.upcomingIsNew;
    final double cardHeight = hasChips ? 115.0 : 96.0;

    return GestureDetector(
      onTap: () {
        if (isDummy) return;
        final showId = show.rawShowData['id'];
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                BlocProvider<ShowDetailsCubit>(
                  create: (context) =>
                      ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
                  child: ShowDetailsPage(
                    mediaId: showId,
                    mediaType: 'tv',
                    title: show.rawShowData['name'] ?? '',
                  ),
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        clipBehavior: Clip.antiAlias,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 130,
                height: cardHeight,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 130,
                  height: cardHeight,
                  color: AppColors.surfaceLight,
                  child: const Icon(Icons.tv, color: AppColors.textTertiary),
                ),
                placeholder: (context, url) => Container(
                  width: 130,
                  height: cardHeight,
                  color: AppColors.surfaceLight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                  bottom: 8.0,
                  right: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: isDummy
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 4.0,
                            ),
                      decoration: BoxDecoration(
                        border: isDummy
                            ? null
                            : Border.all(color: Colors.white, width: 1.0),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              showTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          if (!isDummy) const SizedBox(width: 4),
                          if (!isDummy)
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 14,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      show.upcomingEpisodeCode,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      show.upcomingEpisodeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                    if (hasChips) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (show.upcomingIsPremiere)
                            _buildPillBadge('PREMIERE', false),
                          if (show.upcomingIsPremiere && show.upcomingIsNew)
                            const SizedBox(width: 6),
                          if (show.upcomingIsNew)
                            _buildPillBadge('LATEST', false),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _buildRightSide(),
            ),
          ],
        ),
      ),
    );
  }
}
