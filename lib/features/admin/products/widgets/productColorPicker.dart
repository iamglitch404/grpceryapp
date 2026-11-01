import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

/// Self-contained RGB color picker dialog widget.
/// Extracted from ProductsPage to reduce its size.
class RgbColorPickerDialog extends StatelessWidget {
  final String? initialHex;
  final ValueChanged<String?> onSelected;

  const RgbColorPickerDialog({super.key, required this.initialHex, required this.onSelected});

  // ── Hex/RGB conversion utilities ──

  static Color parseHexColor(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
    }
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    } else if (cleaned.length != 8) {
      return const Color(0xFF185B3A);
    }
    return Color(int.tryParse(cleaned, radix: 16) ?? 0xFF185B3A);
  }

  static int colorR(Color c) => (c.r * 255.0).round().clamp(0, 255);
  static int colorG(Color c) => (c.g * 255.0).round().clamp(0, 255);
  static int colorB(Color c) => (c.b * 255.0).round().clamp(0, 255);

  static String rgbToHex(int r, int g, int b) {
    final rs = r.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final gs = g.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final bs = b.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$rs$gs$bs'.toUpperCase();
  }

  // ── RGB slider row ──

  static Widget _buildRgbSlider({
    required String label,
    required Color labelColor,
    required int value,
    required LinearGradient gradient,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(
            value.toString(),
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: gradient,
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 3,
                    ),
                    overlayColor: labelColor.withValues(alpha: 0.12),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: value.toDouble().clamp(0.0, 255.0),
                    min: 0,
                    max: 255,
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Color currentColor = initialHex != null ? parseHexColor(initialHex!) : const Color(0xFF185B3A);
    int r = colorR(currentColor);
    int g = colorG(currentColor);
    int b = colorB(currentColor);
    final hexTextCtrl = TextEditingController(text: rgbToHex(r, g, b));

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 360,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.palette_rounded, size: 18, color: Color(0xFF185B3A)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'RGB Color Picker',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Swatch Box + RGB / HEX Inputs
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 74,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'rgb($r, $g, $b)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: 'rgb($r, $g, $b)'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied rgb($r, $g, $b) to clipboard!'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: hexTextCtrl,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    final parsed = parseHexColor(val);
                                    r = colorR(parsed);
                                    g = colorG(parsed);
                                    b = colorB(parsed);
                                    currentColor = parsed;
                                    hexTextCtrl.text = rgbToHex(r, g, b);
                                  },
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  final hexString = rgbToHex(r, g, b);
                                  Clipboard.setData(ClipboardData(text: hexString));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied $hexString to clipboard!'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // RGB Sliders Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRgbSlider(
                      label: 'R',
                      labelColor: const Color(0xFFEF4444),
                      value: r,
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(255, 0, g, b),
                          Color.fromARGB(255, 255, g, b),
                        ],
                      ),
                      onChanged: (val) {
                        r = val.clamp(0, 255);
                        currentColor = Color.fromARGB(255, r, g, b);
                        hexTextCtrl.text = rgbToHex(r, g, b);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildRgbSlider(
                      label: 'G',
                      labelColor: const Color(0xFF10B981),
                      value: g,
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(255, r, 0, b),
                          Color.fromARGB(255, r, 255, b),
                        ],
                      ),
                      onChanged: (val) {
                        g = val.clamp(0, 255);
                        currentColor = Color.fromARGB(255, r, g, b);
                        hexTextCtrl.text = rgbToHex(r, g, b);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildRgbSlider(
                      label: 'B',
                      labelColor: const Color(0xFF3B82F6),
                      value: b,
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(255, r, g, 0),
                          Color.fromARGB(255, r, g, 255),
                        ],
                      ),
                      onChanged: (val) {
                        b = val.clamp(0, 255);
                        currentColor = Color.fromARGB(255, r, g, b);
                        hexTextCtrl.text = rgbToHex(r, g, b);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2D Color Canvas - Hue spectrum (visual reference)
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFF00FF),
                      Color(0xFF0000FF),
                      Color(0xFF00FFFF),
                      Color(0xFF00FF00),
                      Color(0xFFFFFF00),
                      Color(0xFFFF0000),
                    ],
                    stops: [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
                  ),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick preset palette
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Presets',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      '#185B3A',
                      '#10B981',
                      '#3B82F6',
                      '#F59E0B',
                      '#EF4444',
                      '#8B5CF6',
                      '#06B6D4',
                      '#1E293B',
                    ].map((hex) {
                      final c = parseHexColor(hex);
                      final hexString = rgbToHex(r, g, b);
                      final isCur = hexString.toUpperCase() == hex.toUpperCase();
                      return GestureDetector(
                        onTap: () {
                          currentColor = c;
                          r = colorR(c);
                          g = colorG(c);
                          b = colorB(c);
                          hexTextCtrl.text = hex;
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCur ? Colors.black87 : Colors.white,
                              width: isCur ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () {
                      onSelected(null);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.block_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: Text(
                      'No Color',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 2,
                    ),
                    onPressed: () {
                      final hexString = rgbToHex(r, g, b);
                      onSelected(hexString);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Apply Color',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: currentColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
