import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback onShowAddresses;
  final VoidCallback onSendNotification;
  final VoidCallback onShowRoleSheet;
  final VoidCallback onDelete;

  const AdminUserCard({
    super.key,
    required this.user,
    required this.onTap,
    required this.onShowAddresses,
    required this.onSendNotification,
    required this.onShowRoleSheet,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = u['name'] ?? u['full_name'] ?? 'User';
    final email = u['email'] ?? 'No email provided';
    final phone = u['phone'] ?? u['phone_number'] ?? '';
    final username = u['username'] ?? '';
    final role = (u['role'] ?? 'customer').toString().toLowerCase();
    final avatar = u['avatar_url'] ?? u['profile_image'];

    Color roleBg = const Color(0xFFEFF6FF);
    Color roleText = const Color(0xFF2563EB);
    String roleDisplay = 'CUSTOMER';

    if (role == 'admin') {
      roleBg = const Color(0xFFFAF5FF);
      roleText = const Color(0xFF9333EA);
      roleDisplay = 'ADMIN';
    } else if (role.contains('delivery')) {
      roleBg = const Color(0xFFFFFBEB);
      roleText = const Color(0xFFD97706);
      roleDisplay = 'DELIVERY';
    }

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipOval(
                        child: avatar != null && avatar.toString().isNotEmpty
                            ? Image.network(
                                avatar.toString(),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF185B3A)),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF185B3A)),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + Email + Role Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (u['status'] == 'suspended' || u['status'] == 'banned') ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  (u['status'] ?? 'ACTIVE').toString().toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: (u['status'] == 'suspended' || u['status'] == 'banned') ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: roleBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleDisplay,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: roleText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF059669), fontWeight: FontWeight.w600),
                                ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  (u['provider'] ?? 'EMAIL').toString().toUpperCase(),
                                  style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                                ),
                              ),
                              if (u['points_balance'] != null && (u['points_balance'] as num) > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded, size: 10, color: Color(0xFFD97706)),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${u['points_balance']} Pts',
                                        style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onShowAddresses,
                      icon: const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF059669)),
                      label: Text(
                        'Addresses',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onSendNotification,
                      icon: const Icon(Icons.notifications_active_outlined, size: 15, color: Color(0xFF2563EB)),
                      label: Text(
                        'Notify',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onShowRoleSheet,
                      icon: const Icon(Icons.manage_accounts_outlined, size: 15, color: Color(0xFF185B3A)),
                      label: Text(
                        'Role',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF185B3A)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFE11D48)),
                      label: Text(
                        'Delete',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

