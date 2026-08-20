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

  /// Penanda permintaan termuda. Ketukan cepat berpindah-pindah gambar bisa
  /// membuat respons LAMA tiba belakangan; tanpa penanda ini, gambar yang tampil
  /// ditentukan oleh jaringan mana yang kebetulan lebih lambat.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Muat ulang saat [AuthImage.path] berganti.
  ///
  /// Tanpa ini gambar TIDAK pernah berubah selama widget-nya dipakai ulang di
  /// posisi yang sama — Flutter mempertahankan State-nya, dan State ini hanya
  /// memuat sekali di [initState]. Gejalanya: menekan pin/kartu lain sementara
  /// preview-nya masih memperlihatkan gambar yang tadi.
  @override
  void didUpdateWidget(covariant AuthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        !identical(oldWidget.apiClient, widget.apiClient)) {
      setState(() {
        _bytes = null;
        _failed = false;
        _loading = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    try {
      final res = await widget.apiClient.get(widget.path);
      // Sudah ada permintaan yang lebih baru → hasil ini milik gambar yang sudah
      // tidak diminta lagi; membuangnya, bukan menampilkannya.
      if (!mounted || requestId != _requestId) return;
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
      if (!mounted || requestId != _requestId) return;
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
