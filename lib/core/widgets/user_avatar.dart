import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final double? borderRadius;
  final Color? fallbackColor;
  final IconData fallbackIcon;
  final BoxBorder? border;

  // Cache giải mã base64 để tránh decode lại mỗi khi render lại widget (tránh giật lag khung hình)
  static final Map<String, Uint8List> _base64Cache = {};

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.size,
    this.borderRadius,
    this.fallbackColor,
    this.fallbackIcon = Icons.person_rounded,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;

    Widget buildContent() {
      final url = avatarUrl;
      if (url == null || url.trim().isEmpty) {
        return Icon(
          fallbackIcon,
          size: size * 0.55,
          color: fallbackColor ?? Colors.white,
        );
      }

      // 1. Base64 encoded image
      if (url.startsWith('data:image/')) {
        try {
          Uint8List? bytes = _base64Cache[url];
          if (bytes == null) {
            final base64Data = url.split(',').last;
            bytes = base64Decode(base64Data);
            _base64Cache[url] = bytes;
          }
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        } catch (e) {
          return _buildFallback();
        }
      }

      // 2. Preset asset image
      if (url.startsWith('assets/')) {
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.asset(
            url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
        );
      }

      // 3. Emoji character (if the length is short, e.g. <= 2 characters/emojis)
      if (url.runes.length <= 2) {
        return Center(
          child: Text(
            url,
            style: TextStyle(
              fontSize: size * 0.5,
              height: 1.1,
            ),
          ),
        );
      }

      // 4. Network image (just in case)
      if (url.startsWith('http')) {
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      }

      // Fallback
      return _buildFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: buildContent(),
      ),
    );
  }

  Widget _buildFallback() {
    return Icon(
      fallbackIcon,
      size: size * 0.55,
      color: fallbackColor ?? Colors.white,
    );
  }
}
