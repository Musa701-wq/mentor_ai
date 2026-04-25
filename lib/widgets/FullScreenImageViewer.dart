import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final Uint8List? imageBytes;
  final File? imageFile;
  final String title;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  const FullScreenImageViewer({
    super.key,
    this.imageBytes,
    this.imageFile,
    this.title = 'Infographic Full View',
    this.onDownload,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        actions: [
          if (onDownload != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: onDownload,
            ),
          if (onShare != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: onShare,
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'infographic_full_view',
            child: _buildImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (imageFile != null) {
      return Image.file(
        imageFile!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image_not_supported_rounded, color: Colors.white54, size: 64),
          SizedBox(height: 16),
          Text(
            "Image not found or still loading...",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }
  }
}
