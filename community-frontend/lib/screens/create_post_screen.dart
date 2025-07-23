import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../constants/constants.dart';
import 'package:path_provider/path_provider.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<File> _mediaFiles = []; // image/video files
  final Map<String, VideoPlayerController> _videoControllers = {};
  bool isPosting = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _profileImageUrl = prefs.getString('profileImageUrl');
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final compressed = await _compressImage(File(picked.path));
      setState(() => _mediaFiles.add(compressed));
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => isPosting = true); // Show loading while compressing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing video... Please wait.')),
      );

      try {
        final compressed = await _compressVideo(File(picked.path));
        if (compressed != null) {
          // Initialize video player controller
          final controller = VideoPlayerController.file(compressed);
          await controller.initialize();
          _videoControllers[compressed.path] = controller;
          setState(() => _mediaFiles.add(compressed));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing video: ${e.toString()}')),
        );
      } finally {
        setState(() => isPosting = false);
      }
    }
  }

  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory(); // Use app temp directory
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 85,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null) {
      throw Exception('Image compression failed');
    }

    final compressedFile = File(targetPath);
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }

  Future<File?> _compressVideo(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return info?.file;
    } catch (e) {
      debugPrint('Video compression error: $e');
      // If compression fails, return the original file
      return file;
    }
  }

  Future<void> _submitPost() async {
    if (_controller.text.trim().isEmpty && _mediaFiles.isEmpty) return;

    setState(() => isPosting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/posts/create'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = _controller.text.trim();

      for (final file in _mediaFiles) {
        final filename = file.path.split('/').last;
        debugPrint('Adding file to request: $filename');
        request.files.add(await http.MultipartFile.fromPath('media', file.path,
            filename: filename));
      }

      debugPrint('Sending request to ${request.url}');
      debugPrint('Request headers: ${request.headers}');
      debugPrint('Request fields: ${request.fields}');
      debugPrint('Request files count: ${request.files.length}');

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${streamedResponse.statusCode}');

      setState(() => isPosting = false);

      if (streamedResponse.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        final respStr = await streamedResponse.stream.bytesToString();
        debugPrint('Response body: $respStr');
        String errorMsg = 'Post failed';
        try {
          errorMsg = jsonDecode(respStr)['message'] ?? errorMsg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } on SocketException {
      setState(() => isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection.')),
      );
    } on TimeoutException {
      setState(() => isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request timed out. Please try again.')),
      );
    } catch (e) {
      setState(() => isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Widget _buildVideoPreview(File file) {
    final controller = _videoControllers[file.path];
    if (controller == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        width: double.infinity,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            });
          },
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 60,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: isPosting ? null : _submitPost,
            child: isPosting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Post", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: _profileImageUrl != null &&
                              _profileImageUrl!.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(_profileImageUrl!))
                          : const CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, color: Colors.grey),
                            ),
                      title: const Text('You',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: const Text('What do you want to talk about?',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write something...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_mediaFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: _mediaFiles.map((file) {
                            final isVideo =
                                file.path.toLowerCase().endsWith('.mp4') ||
                                    file.path.toLowerCase().endsWith('.webm');
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: isVideo
                                      ? _buildVideoPreview(file)
                                      : Image.file(
                                          file,
                                          fit: BoxFit.contain,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.4,
                                          width: double.infinity,
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _mediaFiles.remove(file)),
                                    child: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.black87,
                                      child: Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconButton(Icons.image, 'Photo', _pickImage),
                  _iconButton(Icons.video_library, 'Video', _pickVideo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
