import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/feedback_item.dart';

/// Shared helper widget that handles image loading across all platforms:
/// - Local media on Web: `Image.network`
/// - Local media on Native: `Image.file`
/// - Remote media: `CachedNetworkImage` with disk caching
class FeedbackMediaImage extends StatelessWidget {
  final FeedbackMedia media;
  final BoxFit fit;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorBuilder;

  const FeedbackMediaImage({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isLocal) {
      if (kIsWeb) {
        return Image.network(
          media.path,
          fit: fit,
          errorBuilder: errorBuilder != null
              ? (context, _, _) => errorBuilder!(context)
              : null,
        );
      }
      return Image.file(
        File(media.path),
        fit: fit,
        errorBuilder: errorBuilder != null
            ? (context, _, _) => errorBuilder!(context)
            : null,
      );
    }

    return CachedNetworkImage(
      imageUrl: media.path,
      fit: fit,
      placeholder: placeholder != null
          ? (context, _) => placeholder!(context)
          : null,
      errorWidget: errorBuilder != null
          ? (context, _, _) => errorBuilder!(context)
          : null,
    );
  }
}
