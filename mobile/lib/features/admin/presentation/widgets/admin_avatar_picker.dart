import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';

class AdminAvatarPicker extends StatefulWidget {
  const AdminAvatarPicker({
    super.key,
    required this.imageBase64,
    required this.onChanged,
    this.size = 108,
    this.label = 'Tap to add photo',
    this.sheetTitle = 'Profile Photo',
  });

  final String? imageBase64;
  final ValueChanged<String?> onChanged;
  final double size;
  final String label;
  final String sheetTitle;

  @override
  State<AdminAvatarPicker> createState() => _AdminAvatarPickerState();
}

class _AdminAvatarPickerState extends State<AdminAvatarPicker> {
  MemoryImage? _cachedImage;

  @override
  void didUpdateWidget(covariant AdminAvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBase64 != widget.imageBase64) {
      _cachedImage = _decode(widget.imageBase64);
    }
  }

  @override
  void initState() {
    super.initState();
    _cachedImage = _decode(widget.imageBase64);
  }

  MemoryImage? _decode(String? data) {
    if (data == null || !data.startsWith('data:')) return null;
    try {
      final raw = data.split(',').last;
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 68,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 280000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large. Choose a smaller photo.'),
          ),
        );
      }
      return;
    }
    final mime = file.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    widget.onChanged('data:$mime;base64,${base64Encode(bytes)}');
  }

  void _showOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.sheetTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(ImageSource.gallery);
                },
              ),
              if (widget.imageBase64 != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onChanged(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _cachedImage;

    return Column(
      children: [
        GestureDetector(
          onTap: _showOptions,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: widget.size,
                width: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F4FF),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  image: provider != null
                      ? DecorationImage(image: provider, fit: BoxFit.cover)
                      : null,
                ),
                child: provider == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
