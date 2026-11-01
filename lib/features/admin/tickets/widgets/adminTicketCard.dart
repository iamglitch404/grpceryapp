import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final void Function(String id, String newStatus) onUpdateStatus;

  const AdminTicketCard({
    super.key,
    required this.ticket,
    required this.onUpdateStatus,
  });

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFFFEF3C7);
      case 'in progress':
        return const Color(0xFFDBEAFE);
      case 'resolved':
      case 'closed':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFFB45309);
      case 'in progress':
        return const Color(0xFF1D4ED8);
      case 'resolved':
      case 'closed':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm';
    } catch (_) {
      return dateStr.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = (ticket['id'] ?? '').toString();
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final name = (ticket['customer_name'] ?? 'Customer').toString();
    final email = (ticket['customer_email'] ?? '').toString();
    final phone = (ticket['customer_phone'] ?? '').toString();
    final message = (ticket['message'] ?? '').toString();
    final subject = (ticket['subject'] ?? 'Support Request').toString();
    final status = (ticket['status'] ?? 'Open').toString();
    final dateStr = (ticket['created_at'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: id));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied ticket ID #$shortId'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 15,
                        color: Color(0xFF185B3A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#$shortId',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, size: 12, color: Color(0xFF185B3A)),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              _capitalize(name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (newStatus) => onUpdateStatus(id, newStatus),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Open', child: Text('Mark Open')),
                  const PopupMenuItem(value: 'In Progress', child: Text('Mark In Progress')),
                  const PopupMenuItem(value: 'Resolved', child: Text('Mark Resolved')),
                  const PopupMenuItem(value: 'Closed', child: Text('Mark Closed')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBg(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _getStatusText(status),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: _getStatusText(status),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
          if (ticket['attachments'] is List && (ticket['attachments'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (ticket['attachments'] as List).map<Widget>((att) {
                final isMap = att is Map;
                final url = isMap ? (att['url'] ?? '') : att.toString();
                final attName = isMap ? (att['file_name'] ?? 'File') : 'File';
                final isImg = isMap
                    ? (att['file_type'] == 'image' || url.toLowerCase().contains('.webp') || url.toLowerCase().contains('.png') || url.toLowerCase().contains('.jpg'))
                    : (url.toLowerCase().contains('.webp') || url.toLowerCase().contains('.png') || url.toLowerCase().contains('.jpg'));

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isImg ? Icons.image_outlined : Icons.attach_file_rounded,
                        size: 13,
                        color: const Color(0xFF185B3A),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          attName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF185B3A)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: InkWell(
                        onTap: phone.isNotEmpty
                            ? () {
                                Clipboard.setData(ClipboardData(text: phone));
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied phone: $phone'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : null,
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _capitalize(name),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (phone.isNotEmpty || email.isNotEmpty)
                                TextSpan(
                                  text: ' • ${phone.isNotEmpty ? phone : email}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (dateStr.isNotEmpty)
                Text(
                  _formatDate(dateStr),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

