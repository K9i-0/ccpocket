import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../services/cached_network_image_provider.dart';

/// Displays a network image using [CachedNetworkImageProvider] (disk-cached on
/// native platforms, plain HTTP on web).
class CachedNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final String? cacheKey;
  final Duration cacheMaxAge;
  final Map<String, String>? headers;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final bool gaplessPlayback;
  final double scale;
  final http.Client? httpClient;
  final String? cacheDirectoryPath;

  const CachedNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.cacheKey,
    this.cacheMaxAge = CachedNetworkImageProvider.defaultCacheMaxAge,
    this.headers,
    this.loadingBuilder,
    this.errorBuilder,
    this.gaplessPlayback = false,
    this.scale = 1.0,
    this.httpClient,
    this.cacheDirectoryPath,
  });

  @override
  Widget build(BuildContext context) {
    return Image(
      image: CachedNetworkImageProvider(
        url,
        scale: scale,
        cacheKey: cacheKey,
        cacheMaxAge: cacheMaxAge,
        headers: headers,
        httpClient: httpClient,
        cacheDirectoryPath: cacheDirectoryPath,
      ),
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      gaplessPlayback: gaplessPlayback,
    );
  }
}
