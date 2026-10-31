import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';

class DeliveryProfilePage extends StatefulWidget {
  const DeliveryProfilePage({super.key});

  @override
  State<DeliveryProfilePage> createState() => _DeliveryProfilePageState();
}

class _DeliveryProfilePageState extends State<DeliveryProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _partner;
  List<dynamic> _reviews = [];
  double _overallRating = 5.0;

  @override
  void initState() {
    super.initState();
    _loadProfileAndReviews();
  }

  Future<void> _loadProfileAndReviews() async {
    setState(() => _isLoading = true);
    final repo = CubePod.get<DeliveryRepository>();
    final results = await Future.wait([
      repo.fetchProfile(),
      repo.fetchReviews(),
    ]);

    if (mounted) {
      final profileData = results[0];
      final reviewsData = results[1];

      setState(() {
        _partner = profileData?['partner'];
        _reviews = reviewsData?['reviews'] ?? [];
        final rawRating = reviewsData?['overall_rating'] ?? _partner?['rating'];
        _overallRating = (rawRating is num) ? rawRating.toDouble() : 5.0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = CubePod.get<AuthRepository>().currentUser;
    final name = _partner?['full_name'] ?? user?['name'] ?? 'Delivery Partner';
    final email = _partner?['email'] ?? user?['email'] ?? '';
    final phone = _partner?['phone'] ?? user?['phone'] ?? '9800000000';
    final vehicle = (_partner?['vehicle_type'] ?? 'Bike').toString().toUpperCase();
    final completedCount = _partner?['completed_deliveries_count'] ?? 0;
    final earnedRs = ((_partner?['total_earned_paise'] ?? 0) / 100).toStringAsFixed(0);

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
          : RefreshIndicator(
              onRefresh: _loadProfileAndReviews,
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
                              _buildHeaderStat('Deliveries', '$completedCount'),
                              Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                              _buildHeaderStat('Earnings', 'Rs $earnedRs'),
                              Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                              _buildHeaderStat('Rating', '$_overallRating ★', highlight: true),
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
                                _overallRating.toStringAsFixed(1),
                                style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              Row(
                                children: List.generate(5, (index) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16)),
                              ),
                              const SizedBox(height: 4),
                              Text('${_reviews.length} reviews', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRatingBar('Delivery Speed', 4.9, const Color(0xFF10B981)),
                                const SizedBox(height: 6),
                                _buildRatingBar('Communication', 4.8, const Color(0xFF3B82F6)),
                                const SizedBox(height: 6),
                                _buildRatingBar('Careful Handling', 5.0, const Color(0xFF8B5CF6)),
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
                      itemCount: _reviews.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final rev = _reviews[i];
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
                          await CubePod.get<AuthRepository>().logout();
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
            ),
    );
  }

  Widget _buildHeaderStat(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFFD97706) : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRatingBar(String label, double rating, Color color) {
    final pct = (rating / 5.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
            Text(rating.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
