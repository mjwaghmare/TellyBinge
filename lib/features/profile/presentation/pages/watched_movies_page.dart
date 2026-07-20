import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import 'profile_page.dart'; // For HorizontalItem
import '../../../../features/explore/presentation/pages/movie_details_page.dart';

class WatchedMoviesPage extends StatelessWidget {
  final List<HorizontalItem> watchedMovies;
  final String title;

  const WatchedMoviesPage({
    super.key,
    required this.watchedMovies,
    this.title = 'Watched movies',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.bodyLarge?.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        itemCount: watchedMovies.length,
        itemBuilder: (context, index) {
          final movie = watchedMovies[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsPage(movieId: movie.movieId),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.light ? Colors.grey[300] : AppColors.surfaceLight,
                      width: double.infinity,
                      child: movie.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: movie.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Center(
                                    child: Icon(
                                      Icons.movie_creation_outlined,
                                      size: 32,
                                      color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                                    ),
                                  ),
                            )
                          : Center(
                              child: Icon(
                                Icons.movie_creation_outlined,
                                size: 32,
                                color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Title
                Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                // Rating & Year row
                Row(
                  children: [
                    if (movie.voteAverage > 0.0) ...[
                      Icon(Icons.star, color: AppColors.primary, size: 10.0),
                      const SizedBox(width: 3),
                      Text(
                        movie.voteAverage.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 10.0,
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                        ),
                      ),
                      if (_getYear(movie.releaseDate).isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getYear(movie.releaseDate),
                          style: TextStyle(
                            fontSize: 10.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ] else if (_getYear(movie.releaseDate).isNotEmpty) ...[
                      Text(
                        _getYear(movie.releaseDate),
                        style: TextStyle(
                          fontSize: 10.0,
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getYear(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      return DateTime.parse(dateStr).year.toString();
    } catch (_) {
      if (dateStr.length >= 4) {
        return dateStr.substring(0, 4);
      }
      return '';
    }
  }
}
