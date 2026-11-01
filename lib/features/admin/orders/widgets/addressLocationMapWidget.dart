// Mini address map preview widget for saved delivery addresses.
// Extracted from orderMapWidget.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/admin/orders/widgets/orderMapHelpers.dart';

/// Mini Address Map Preview for Saved Delivery Addresses
class AddressLocationMapWidget extends StatelessWidget {
  final Map<String, dynamic> address;

  const AddressLocationMapWidget({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    final lat = toDouble(address['latitude']);
    final lng = toDouble(address['longitude']);
    if (lat == null || lng == null) return const SizedBox.shrink();

    final point = LatLng(lat, lng);
    final street = address['street'] ?? 'Saved Address';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE11D48)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GPS Pin: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  Text(street, style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              launchGoogleMapsNavigation(
                origin: kDovanAdminHub,
                destination: point,
              );
            },
            icon: const Icon(Icons.navigation_rounded, size: 12),
            label: Text('Navigate', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
