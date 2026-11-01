import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/delivery/orders/providers/deliveryOrderProviders.dart';

class AssignPartnerBottomSheet extends ConsumerWidget {
  final String orderId;
  final String? currentAssignedId;
  final ValueChanged<Map<String, dynamic>> onPartnerAssigned;

  const AssignPartnerBottomSheet({
    super.key,
    required this.orderId,
    this.currentAssignedId,
    required this.onPartnerAssigned,
  });

  Future<void> _assign(BuildContext context, WidgetRef ref, Map<String, dynamic> partner) async {
    final pid = partner['id']?.toString();
    if (pid == null) return;

    ref.read(assigningPartnerIdProvider.notifier).state = pid;
    final success = await ref.read(deliveryRepositoryProvider).assignDeliveryPartner(orderId, pid);
    if (!context.mounted) return;
    ref.read(assigningPartnerIdProvider.notifier).state = null;

    if (success) {
      AppToast.show(
        context,
        'Assigned order to ${partner['full_name'] ?? 'partner'}',
        type: ToastType.success,
      );
      onPartnerAssigned(partner);
      Navigator.pop(context);
    } else {
      AppToast.show(
        context,
        'Failed to assign order. Please try again.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(availableDeliveryPartnersFutureProvider);
    final searchQuery = ref.watch(assignPartnerSearchQueryProvider);
    final assigningPartnerId = ref.watch(assigningPartnerIdProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Delivery Partner',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Order #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => ref.read(assignPartnerSearchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search partner by name, phone or vehicle...',
                hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: partnersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A))),
              error: (_, _) => const Center(child: Text('Failed to load delivery partners')),
              data: (partners) {
                final filtered = partners.where((p) {
                  if (searchQuery.isEmpty) return true;
                  final q = searchQuery.toLowerCase();
                  final name = (p['full_name'] ?? '').toString().toLowerCase();
                  final phone = (p['phone'] ?? '').toString().toLowerCase();
                  final vehicle = (p['vehicle_number'] ?? '').toString().toLowerCase();
                  return name.contains(q) || phone.contains(q) || vehicle.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delivery_dining_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No delivery partners found',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add accounts with role="delivery_man" in the database',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final pid = p['id']?.toString() ?? '';
                    final isAssigned = pid == currentAssignedId;
                    final isAssigning = pid == assigningPartnerId;
                    final status = (p['status'] ?? 'offline').toString();
                    final completed = p['completed_deliveries_count'] ?? 0;
                    final rating = (p['rating'] is num) ? (p['rating'] as num).toDouble() : 5.0;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isAssigned ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAssigned ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                          width: isAssigned ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: (p['avatar_url'] != null && (p['avatar_url'] as String).isNotEmpty)
                                ? NetworkImage(p['avatar_url'])
                                : null,
                            child: (p['avatar_url'] == null || (p['avatar_url'] as String).isEmpty)
                                ? Text(
                                    (p['full_name'] ?? 'P')[0].toUpperCase(),
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF185B3A)),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        p['full_name'] ?? 'Partner',
                                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: status == 'online'
                                            ? const Color(0xFFDCFCE7)
                                            : (status == 'delivering' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'online'
                                              ? const Color(0xFF166534)
                                              : (status == 'delivering' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${p['vehicle_type'] ?? 'Bike'} • ${p['vehicle_number'] ?? 'N/A'} • ${p['phone'] ?? ''}',
                                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                                    const SizedBox(width: 3),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  $completed deliveries',
                                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (isAssigned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF166534),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Assigned', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF185B3A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: isAssigning ? null : () => _assign(context, ref, p),
                              child: isAssigning
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text('Assign', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
