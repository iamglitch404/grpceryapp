// Image picker card widget for submit product page.
// Extracted from submitProductPage.dart to reduce its size.
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/features/customer/submissions/providers/submissionProviders.dart';

class SubmitProductImagePickerCard extends ConsumerStatefulWidget {
  const SubmitProductImagePickerCard({super.key});

  @override
  ConsumerState<SubmitProductImagePickerCard> createState() => _SubmitProductImagePickerCardState();
}

class _SubmitProductImagePickerCardState extends ConsumerState<SubmitProductImagePickerCard> {
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1000,
    );
    if (image != null && mounted) {
      ref.read(submitProductSelectedImageProvider.notifier).state = image;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedImage = ref.watch(submitProductSelectedImageProvider);
    final imageUrl = ref.watch(submitProductImageUrlProvider);
    final hasImage = selectedImage != null || (imageUrl != null && imageUrl.isNotEmpty);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (hasImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: selectedImage != null
                        ? (kIsWeb
                            ? Image.network(selectedImage.path, fit: BoxFit.cover)
                            : Image.file(File(selectedImage.path), fit: BoxFit.cover))
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 40, color: Color(0xFF94A3B8)),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () {
                      ref.read(submitProductSelectedImageProvider.notifier).state = null;
                      ref.read(submitProductImageUrlProvider.notifier).state = null;
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF185B3A)),
                    label: Text(
                      hasImage ? 'Change Photo' : 'Gallery',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF185B3A)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF185B3A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
                    label: Text(
                      'Camera',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
