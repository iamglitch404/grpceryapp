import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';

class DeliveryShiftsPage extends StatefulWidget {
  const DeliveryShiftsPage({super.key});

  @override
  State<DeliveryShiftsPage> createState() => _DeliveryShiftsPageState();
}

class _DeliveryShiftsPageState extends State<DeliveryShiftsPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _activeShift;
  List<dynamic> _shifts = [];
  String _totalHours = '0.0';
  Timer? _ticker;
  Duration _activeDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadShifts();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateActiveDuration());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateActiveDuration() {
    if (_activeShift != null && _activeShift!['clock_in_at'] != null) {
      final inTime = DateTime.tryParse(_activeShift!['clock_in_at']);
      if (inTime != null) {
        setState(() {
          _activeDuration = DateTime.now().difference(inTime);
        });
      }
    }
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    final data = await CubePod.get<DeliveryRepository>().fetchShifts();
    if (mounted) {
      setState(() {
        _activeShift = data?['active_shift'];
        _shifts = data?['shifts'] ?? [];
        _totalHours = data?['total_hours']?.toString() ?? '0.0';
        _isLoading = false;
      });
      _updateActiveDuration();
    }
  }

  Future<void> _toggleShift() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final isClockedIn = _activeShift != null;
    final repo = CubePod.get<DeliveryRepository>();

    if (isClockedIn) {
      final success = await repo.clockOut();
      if (mounted) {
        if (success) {
          AppToast.success(context, 'Shift ended. Great work today!');
          _loadShifts();
        } else {
          AppToast.error(context, 'Failed to clock out');
        }
      }
    } else {
      final success = await repo.clockIn();
      if (mounted) {
        if (success) {
          AppToast.success(context, 'Shift started! You are now online for orders.');
          _loadShifts();
        } else {
          AppToast.error(context, 'Failed to clock in');
        }
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isClockedIn = _activeShift != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Working Hours & Shifts',
          style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
          : RefreshIndicator(
              onRefresh: _loadShifts,
              color: const Color(0xFF185B3A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Clock In / Clock Out Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isClockedIn
                              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                              : [const Color(0xFF185B3A), const Color(0xFF064E3B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isClockedIn ? Colors.black : const Color(0xFF185B3A)).withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isClockedIn ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isClockedIn ? const Color(0xFF10B981) : Colors.white30,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isClockedIn ? const Color(0xFF10B981) : Colors.white60,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isClockedIn ? 'ON DUTY' : 'OFF DUTY',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Dovan Dispatcher',
                                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isClockedIn ? _formatDuration(_activeDuration) : '00:00:00',
                            style: GoogleFonts.outfit(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isClockedIn ? 'Current Shift Active Time' : 'Start your shift to accept orders',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClockedIn ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: _isProcessing ? null : _toggleShift,
                              icon: _isProcessing
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(isClockedIn ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded, color: Colors.white),
                              label: Text(
                                isClockedIn ? 'End Shift (Clock Out)' : 'Start Shift (Clock In)',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Hours Summary Stats Grid
                    Row(
                      children: [
                        Expanded(child: _buildSummaryCard('Total Hours', '$_totalHours hrs', Icons.access_time_rounded, const Color(0xFF3B82F6))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSummaryCard('Total Shifts', '${_shifts.length}', Icons.calendar_today_rounded, const Color(0xFF10B981))),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Shift History Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Shift History Logs',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          '${_shifts.length} Recorded',
                          style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Shift History List
                    if (_shifts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.history_rounded, size: 40, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 10),
                            Text('No shifts logged yet', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                            const SizedBox(height: 4),
                            Text('Clock in to start tracking your working hours', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _shifts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final s = _shifts[i];
                          final isActive = s['status'] == 'active';
                          final inTime = DateTime.tryParse(s['clock_in_at'] ?? '');
                          final outTime = s['clock_out_at'] != null ? DateTime.tryParse(s['clock_out_at']) : null;
                          final mins = s['total_minutes'] ?? 0;
                          final hoursStr = (mins / 60).toStringAsFixed(1);

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isActive ? Icons.timelapse_rounded : Icons.check_circle_outline_rounded,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            inTime != null ? '${inTime.day}/${inTime.month}/${inTime.year}' : 'Shift',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isActive ? 'IN PROGRESS' : '$hoursStr hrs',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isActive ? const Color(0xFF16A34A) : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        inTime != null
                                            ? '${inTime.hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')} - '
                                              '${outTime != null ? "${outTime.hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}" : "Now"}'
                                            : '',
                                        style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
