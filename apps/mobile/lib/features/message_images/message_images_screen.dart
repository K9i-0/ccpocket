import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../../models/messages.dart';
import '../../services/bridge_service.dart';
import '../../widgets/bubbles/image_preview.dart';

/// Screen that loads and displays images attached to a specific message.
///
/// On open it fires a `get_message_images` request to the Bridge, listens for
/// the response, and shows the images (or an error).
class MessageImagesScreen extends StatefulWidget {
  final BridgeService bridge;
  final String httpBaseUrl;
  final String claudeSessionId;
  final String messageUuid;
  final int imageCount;

  const MessageImagesScreen({
    super.key,
    required this.bridge,
    required this.httpBaseUrl,
    required this.claudeSessionId,
    required this.messageUuid,
    required this.imageCount,
  });

  @override
  State<MessageImagesScreen> createState() => _MessageImagesScreenState();
}

class _MessageImagesScreenState extends State<MessageImagesScreen> {
  List<ImageRef>? _images;
  String? _error;
  bool _loading = true;
  StreamSubscription<ServerMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _requestImages();
  }

  void _requestImages() {
    setState(() {
      _loading = true;
      _error = null;
      _images = null;
    });

    // Listen for the response.
    _sub = widget.bridge.messages
        .where((msg) =>
            msg is MessageImagesResultMessage &&
            msg.messageUuid == widget.messageUuid)
        .cast<MessageImagesResultMessage>()
        .first
        .asStream()
        .listen(
      (msg) {
        if (!mounted) return;
        if (msg.images.isEmpty) {
          setState(() {
            _loading = false;
            _error = '画像を取得できませんでした';
          });
        } else {
          setState(() {
            _loading = false;
            _images = msg.images;
          });
        }
      },
      onError: (Object err) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '画像の取得に失敗しました: $err';
        });
      },
    );

    // Fire the request.
    widget.bridge.requestMessageImages(
      claudeSessionId: widget.claudeSessionId,
      messageUuid: widget.messageUuid,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.imageCount > 1
              ? '添付画像 (${widget.imageCount})'
              : '添付画像',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white54,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _requestImages,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                label: const Text(
                  'リトライ',
                  style: TextStyle(color: Colors.white70),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final images = _images!;
    if (images.length == 1) {
      return _SingleImageView(
        url: '${widget.httpBaseUrl}${images.first.url}',
      );
    }

    // Multiple images: vertical list with tap-to-fullscreen.
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: images.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final url = '${widget.httpBaseUrl}${images[index].url}';
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FullScreenImageViewer(url: url),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ExtendedImage.network(
              url,
              fit: BoxFit.contain,
              cache: true,
              cacheMaxAge: const Duration(days: 7),
              loadStateChanged: (state) {
                switch (state.extendedImageLoadState) {
                  case LoadState.loading:
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    );
                  case LoadState.completed:
                    return state.completedWidget;
                  case LoadState.failed:
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// Single image with interactive zoom.
class _SingleImageView extends StatelessWidget {
  final String url;
  const _SingleImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: ExtendedImage.network(
          url,
          fit: BoxFit.contain,
          cache: true,
          cacheMaxAge: const Duration(days: 7),
          loadStateChanged: (state) {
            switch (state.extendedImageLoadState) {
              case LoadState.loading:
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              case LoadState.completed:
                return state.completedWidget;
              case LoadState.failed:
                return const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
