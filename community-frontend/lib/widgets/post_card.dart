import 'package:community_frontend/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

class PostCard extends StatefulWidget {
  final int userId;
  final String authorName;
  final String? authorImageUrl;
  final String timeAgo;
  final String content;
  final dynamic mediaUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const PostCard({
    super.key,
    required this.userId,
    required this.authorName,
    this.authorImageUrl,
    required this.timeAgo,
    required this.content,
    this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isFullScreen = false;
  bool _isMediaLoading = true;
  ImageProvider? _imageProvider;
  double _aspectRatio = 16 / 9; // Default aspect ratio

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    final mediaUrls = _getMediaUrls();
    if (mediaUrls.isEmpty) return;

    final url = mediaUrls[0];
    final fullUrl = url.startsWith('/') ? '$baseUrl$url' : url;

    if (_isVideoUrl(url)) {
      await _initializeVideoPlayer(fullUrl);
    } else {
      // Preload image and get its dimensions
      _preloadImage(fullUrl);
    }
  }

  void _preloadImage(String url) {
    final imageProvider = NetworkImage(url);
    _imageProvider = imageProvider;

    // Get image dimensions to calculate aspect ratio
    final imageStream = imageProvider.resolve(const ImageConfiguration());
    imageStream.addListener(ImageStreamListener((info, _) {
      if (!mounted) return;

      final aspectRatio = info.image.width / info.image.height;
      setState(() {
        _aspectRatio = aspectRatio;
        _isMediaLoading = false;
      });
    }, onError: (exception, stackTrace) {
      debugPrint('Error loading image: $exception');
      if (mounted) {
        setState(() {
          _isMediaLoading = false;
        });
      }
    }));
  }

  Future<void> _initializeVideoPlayer(String fullUrl) async {
    try {
      _videoController = VideoPlayerController.network(fullUrl);
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _aspectRatio = _videoController!.value.aspectRatio;
          _isMediaLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isMediaLoading = false;
        });
      }
    }
  }

  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.mp4') ||
        lowercaseUrl.endsWith('.webm') ||
        lowercaseUrl.endsWith('.mov');
  }

  List<String> _getMediaUrls() {
    if (widget.mediaUrl == null) return [];

    // Handle case when mediaUrl is already a List
    if (widget.mediaUrl is List) {
      return widget.mediaUrl.cast<String>();
    }

    // Handle case when mediaUrl is a JSON string
    if (widget.mediaUrl is String) {
      try {
        if (widget.mediaUrl.startsWith('[') && widget.mediaUrl.endsWith(']')) {
          // Parse JSON array
          final List<dynamic> parsed = jsonDecode(widget.mediaUrl);
          return parsed.map((e) => e.toString()).toList();
        } else if (widget.mediaUrl.isNotEmpty) {
          // Single URL as string
          return [widget.mediaUrl];
        }
      } catch (e) {
        // If parsing fails, treat as a single URL
        if (widget.mediaUrl.isNotEmpty) {
          return [widget.mediaUrl];
        }
      }
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = _getMediaUrls();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildContent(),
            if (mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPostMedia(mediaUrls),
            ],
            const SizedBox(height: 12),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/user-profile', arguments: {
              'userId': widget.userId,
              'userName': widget.authorName,
              'avatarUrl': widget.authorImageUrl,
            });
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            backgroundImage: (widget.authorImageUrl != null &&
                    widget.authorImageUrl!.isNotEmpty)
                ? NetworkImage(widget.authorImageUrl!)
                : null,
            child: (widget.authorImageUrl == null ||
                    widget.authorImageUrl!.isEmpty)
                ? Text(
                    widget.authorName.isNotEmpty
                        ? widget.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.black),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/user-profile', arguments: {
                'userId': widget.userId,
                'userName': widget.authorName,
                'avatarUrl': widget.authorImageUrl,
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.timeAgo,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Text(
      widget.content,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
    );
  }

  Widget _buildPostMedia(List<String> urls) {
    if (urls.isEmpty) return const SizedBox();

    // For now, just display the first image/video
    final url = urls[0];
    final isVideo = _isVideoUrl(url);

    // Ensure the URL has the base URL if it's a relative path
    String fullUrl = url;
    if (url.startsWith('/')) {
      fullUrl = '$baseUrl$url';
    }

    return GestureDetector(
      onTap: () => _openMediaFullscreen(fullUrl, isVideo),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          // Fixed height for Twitter-like cropped preview
          final previewHeight = maxWidth * 0.6;

          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: maxWidth,
              height: previewHeight,
              color: Colors.black26,
              child: Stack(
                children: [
                  // Media content
                  if (_isMediaLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (isVideo &&
                      _isVideoInitialized &&
                      _videoController != null)
                    _buildCroppedVideo(maxWidth, previewHeight)
                  else if (!isVideo && _imageProvider != null)
                    _buildCroppedImage(fullUrl, maxWidth, previewHeight)
                  else
                    const Center(
                      child: Text("Media failed to load",
                          style: TextStyle(color: Colors.grey)),
                    ),

                  // Overlay indicator for videos
                  if (isVideo && _isVideoInitialized)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                  // Fullscreen indicator
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCroppedVideo(double width, double height) {
    // Center-crop the video
    return Center(
      child: AspectRatio(
        aspectRatio: width / height,
        child: Transform.scale(
          scale: _getCropScale(width / height),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
      ),
    );
  }

  Widget _buildCroppedImage(String url, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Image(
        image: _imageProvider!,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return child;
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  // Calculate scale factor for center-cropping
  double _getCropScale(double containerAspectRatio) {
    if (_aspectRatio > containerAspectRatio) {
      // Video is wider than container, scale to match height
      return 1 / (containerAspectRatio / _aspectRatio);
    } else {
      // Video is taller than container, scale to match width
      return 1.0;
    }
  }

  Future<void> _openMediaFullscreen(String url, bool isVideo) async {
    if (isVideo) {
      // For videos, use the existing fullscreen method
      _enterFullScreen(url);
    } else {
      // For images, open a fullscreen image viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullscreenMediaViewer(
            mediaUrl: url,
            isVideo: false,
          ),
        ),
      );
    }
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (!_isVideoInitialized || _videoController == null) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white.withOpacity(0.7),
                      size: 60,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        VideoProgressIndicator(
          _videoController!,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          colors: const VideoProgressColors(
            playedColor: Colors.blue,
            bufferedColor: Colors.grey,
            backgroundColor: Colors.black45,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: () => _enterFullScreen(videoUrl),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _enterFullScreen(String videoUrl) async {
    // Pause current video
    _videoController?.pause();

    // Set device to landscape orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Navigate to full screen video page
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenMediaViewer(
          mediaUrl: videoUrl,
          isVideo: true,
        ),
      ),
    );

    // Reset orientation when returning
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Widget _buildActions(BuildContext context) {
    final mediaUrls = _getMediaUrls();
    final firstUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionButton(
          icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
          label: widget.likeCount.toString(),
          onTap: widget.onLike,
        ),
        _actionButton(
          icon: Icons.comment_outlined,
          label: widget.commentCount.toString(),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comment feature coming soon')),
            );
            widget.onComment();
          },
        ),
        _actionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {
            final text = widget.content;
            if (firstUrl != null) {
              final fullUrl =
                  firstUrl.startsWith('/') ? '$baseUrl$firstUrl' : firstUrl;
              Share.share('$text\n\nCheck this out: $fullUrl');
            } else {
              Share.share(text);
            }
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class FullscreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const FullscreenMediaViewer({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    } else {
      _loadImage();
    }
  }

  void _loadImage() {
    _imageProvider = NetworkImage(widget.mediaUrl);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.mediaUrl);
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          _controller.play();
        });
      }
    } catch (e) {
      debugPrint('Error initializing fullscreen video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.isVideo) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : widget.isVideo
                    ? _buildFullscreenVideo(isLandscape)
                    : _buildFullscreenImage(),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Video controls
          if (widget.isVideo && _isInitialized)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.blue,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ),

                  // Play/pause button
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullscreenVideo(bool isLandscape) {
    if (!_isInitialized) {
      return const Center(
        child:
            Text('Failed to load video', style: TextStyle(color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildFullscreenImage() {
    if (_imageProvider == null) {
      return const Center(
        child:
            Text('Failed to load image', style: TextStyle(color: Colors.white)),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Image(
        image: _imageProvider!,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          return child;
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 50),
        ),
      ),
    );
  }
}
