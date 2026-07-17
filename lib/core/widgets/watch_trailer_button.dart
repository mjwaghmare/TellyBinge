import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class WatchTrailerButton extends StatelessWidget {
  final Map<String, dynamic> trailer;

  const WatchTrailerButton({super.key, required this.trailer});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  void _showTrailerBottomSheet(BuildContext context, String videoKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TrailerBottomSheet(videoKey: videoKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (trailer['site'] == 'YouTube') {
          _showTrailerBottomSheet(context, trailer['key'] as String);
        } else {
          String urlStr = '';
          if (trailer['site'] == 'Vimeo') {
            urlStr = 'https://vimeo.com/${trailer['key']}';
          }
          if (urlStr.isNotEmpty) {
            final url = Uri.parse(urlStr);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.inAppWebView);
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://img.youtube.com/vi/${trailer['key']}/0.jpg',
                    width: 120,
                    height: 68,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 120,
                      height: 68,
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Watch trailer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trailer['name'] as String? ??
                        trailer['site'] as String? ??
                        'Trailer',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trailer['published_at'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(trailer['published_at'] as String),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerBottomSheet extends StatefulWidget {
  final String videoKey;
  const _TrailerBottomSheet({required this.videoKey});

  @override
  State<_TrailerBottomSheet> createState() => _TrailerBottomSheetState();
}

class _TrailerBottomSheetState extends State<_TrailerBottomSheet> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoKey,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          const SafeArea(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
