import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api_client.dart';

/// Loads an image from an authenticated backend path (e.g. /api/files/...).
///
/// The file endpoint requires the bearer token, which a plain [Image.network]
/// can't reliably attach on web. So we fetch the bytes through [ApiClient] and
/// render them with [Image.memory] — works identically on mobile and web.
class AuthImage extends StatefulWidget {
  final ApiClient apiClient;
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AuthImage({
    super.key,
    required this.apiClient,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.apiClient.get(widget.path);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _bytes = res.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_failed || _bytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    }
    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
