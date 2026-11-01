// Leaderboard calculations for admin dashboard.
// Extracted from dashboardPage.dart to reduce its size.

/// Computes customer leaderboard entries from users and orders.
List<Map<String, dynamic>> computeCustomerLeaderboard(
  List<dynamic> users,
  List<dynamic> orders,
) {
  String getUserRole(dynamic u) {
    final r = (u['role'] ?? 'customer').toString().toLowerCase();
    if (r == 'delivery_man' || r.contains('delivery')) return 'delivery_man';
    if (r == 'admin') return 'admin';
    return 'customer';
  }

  final customers = users.where((u) => getUserRole(u) == 'customer').toList();
  List<Map<String, dynamic>> list = [];

  for (final c in customers) {
    final uid = c['id'];
    final userOrders = orders.where((o) => (o['user_id'] ?? o['userId']) == uid).toList();
    final orderCount = userOrders.length;
    int totalSpent = 0;
    for (final o in userOrders) {
      final total = o['total_amount'] ?? (o['total_paise'] != null ? (o['total_paise'] as num) / 100 : 0);
      totalSpent += (num.tryParse(total.toString()) ?? 0).toInt();
    }
    final points = (c['points_balance'] as num?)?.toInt() ?? 0;

    list.add({
      'user': c,
      'name': (c['name'] ?? c['username'] ?? 'Customer').toString(),
      'email': (c['email'] ?? '').toString(),
      'avatar': c['avatar_url'] ?? c['profile_image'],
      'order_count': orderCount,
      'total_spent': totalSpent,
      'points': points,
    });
  }

  list.sort((a, b) {
    final ptsComp = (b['points'] as int).compareTo(a['points'] as int);
    if (ptsComp != 0) return ptsComp;
    return (b['order_count'] as int).compareTo(a['order_count'] as int);
  });

  return list.take(8).toList();
}

/// Computes delivery partner leaderboard entries from users and orders.
List<Map<String, dynamic>> computeDeliverymanLeaderboard(
  List<dynamic> users,
  List<dynamic> orders,
) {
  String getUserRole(dynamic u) {
    final r = (u['role'] ?? 'customer').toString().toLowerCase();
    if (r == 'delivery_man' || r.contains('delivery')) return 'delivery_man';
    if (r == 'admin') return 'admin';
    return 'customer';
  }

  final drivers = users.where((u) => getUserRole(u) == 'delivery_man').toList();
  List<Map<String, dynamic>> list = [];

  final deliveredOrders = orders.where((o) {
    final s = (o['status'] ?? '').toString().toLowerCase();
    return s == 'delivered';
  }).toList();

  final activeOrders = orders.where((o) {
    final s = (o['status'] ?? '').toString().toLowerCase();
    return s == 'on the way' || s == 'packed';
  }).toList();

  for (final d in drivers) {
    final uid = d['id'];
    final driverDelivered = deliveredOrders.where((o) => o['delivery_man_id'] == uid).length;
    final driverActive = activeOrders.where((o) => o['delivery_man_id'] == uid).length;

    final completedCount = driverDelivered > 0 ? driverDelivered : deliveredOrders.length;
    final activeCount = driverActive > 0 ? driverActive : activeOrders.length;
    final points = (d['points_balance'] as num?)?.toInt() ?? (completedCount * 10);

    list.add({
      'user': d,
      'name': (d['name'] ?? d['username'] ?? 'Delivery Partner').toString(),
      'email': (d['email'] ?? '').toString(),
      'phone': (d['phone'] ?? d['phone_number'] ?? '').toString(),
      'avatar': d['avatar_url'] ?? d['profile_image'],
      'completed_deliveries': completedCount,
      'active_deliveries': activeCount,
      'points': points,
      'status': (d['status'] ?? 'active').toString(),
    });
  }

  list.sort((a, b) => (b['completed_deliveries'] as int).compareTo(a['completed_deliveries'] as int));
  return list;
}
