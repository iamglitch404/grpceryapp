import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/delivery/profile/providers/deliveryProfileProviders.dart';
import 'package:app/features/delivery/profile/widgets/deliveryProfileStats.dart';

class DeliveryProfilePage extends ConsumerWidget {
  const DeliveryProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final profileAsync = ref.watch(deliveryProfileFutureProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Rider Profile & Reviews',
          style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A))),
        error: (err, _) => Center(
          child: Text('Failed to load profile: $err', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
        ),
        data: (data) {
          final partner = data.partner;
          final reviews = data.reviews;
          final overallRating = data.overallRating;
          final name = partner?['full_name'] ?? user?['name'] ?? 'Delivery Partner';
          final email = partner?['email'] ?? user?['email'] ?? '';
          final phone = partner?['phone'] ?? user?['phone'] ?? '9800000000';
          final vehicle = (partner?['vehicle_type'] ?? 'Bike').toString().toUpperCase();
          final completedCount = partner?['completed_deliveries_count'] ?? 0;
          final earnedRs = ((partner?['total_earned_paise'] ?? 0) / 100).toStringAsFixed(0);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(deliveryProfileFutureProvider.future),
            color: const Color(0xFF185B3A),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: const Color(0xFF185B3A),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        if (email.isNotEmpty || phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone.isNotEmpty && email.isNotEmpty ? '$phone  •  $email' : (phone.isNotEmpty ? phone : email),
                            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                              child: Text('VERIFIED RIDER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A))),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.two_wheeler_rounded, size: 13, color: Color(0xFF475569)),
                                  const SizedBox(width: 4),
                                  Text(vehicle, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 8),
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            DeliveryHeaderStat(label: 'Deliveries', value: '$completedCount'),
                            Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                            DeliveryHeaderStat(label: 'Earnings', value: 'Rs $earnedRs'),
                            Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                            DeliveryHeaderStat(label: 'Rating', value: '$overallRating ★', highlight: true),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Customer Ratings Scorecard
                  Text('Ratings & Reviews', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(
                              overallRating.toStringAsFixed(1),
                              style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Row(
                              children: List.generate(5, (index) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16)),
                            ),
                            const SizedBox(height: 4),
                            Text('${reviews.length} reviews', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DeliveryRatingBar(label: 'Delivery Speed', rating: 4.9, color: Color(0xFF10B981)),
                              SizedBox(height: 6),
                              DeliveryRatingBar(label: 'Communication', rating: 4.8, color: Color(0xFF3B82F6)),
                              SizedBox(height: 6),
                              DeliveryRatingBar(label: 'Careful Handling', rating: 5.0, color: Color(0xFF8B5CF6)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Customer Reviews Feed
                  Text('Recent Customer Feedback', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final rev = reviews[i];
                      final customerName = rev['customer_name'] ?? 'Customer';
                      final rating = rev['rating'] ?? 5;
                      final text = rev['review_text'] ?? 'Great delivery!';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
                                Row(
                                  children: List.generate(
                                    rating,
                                    (idx) => const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              text,
                              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).logout();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text('Sign Out of Delivery Partner Account', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
