import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/features/customer/orders/presentation/pages/order_detail_page.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Canceled':
      case 'Cancelled': return Colors.red;
      case 'Pending': return Colors.orange;
      case 'Packed': return Colors.brown;
      case 'On the way': return Colors.blue;
      case 'Delivered': default: return const Color(0xFF42A769);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Canceled':
      case 'Cancelled': return const Color(0xFFFFEBEE);
      case 'Pending': return Colors.orange.shade50;
      case 'Packed': return Colors.brown.shade50;
      case 'On the way': return Colors.blue.shade50;
      case 'Delivered': default: return const Color(0xFFE8F5E9);
    }
  }

  int _selectedTab = 0; // 0: Current Order, 1: Previous Order

  List<Map<String, dynamic>> _currentOrders = [];
  bool _isLoadingCurrent = false;

  List<Map<String, dynamic>> _previousOrders = [];
  bool _isLoadingPrevious = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentOrders();
    _fetchPreviousOrders();
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/orders/$orderId'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      
      if (response.statusCode != 200) {
         throw Exception('Failed to cancel order: ${response.body}');
      }
      
      _fetchCurrentOrders();
      _fetchPreviousOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel order'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchCurrentOrders() async {
    if (!CubePod.get<AuthRepository>().isLoggedIn) return;
    setState(() => _isLoadingCurrent = true);
    
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders?status=Pending'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
          
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _currentOrders = List<Map<String, dynamic>>.from(data['data']['orders']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching current orders: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCurrent = false);
      }
    }
  }

  Future<void> _fetchPreviousOrders() async {
    if (!CubePod.get<AuthRepository>().isLoggedIn) return;
    setState(() => _isLoadingPrevious = true);
    
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders?status=!Pending'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
          
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _previousOrders = List<Map<String, dynamic>>.from(data['data']['orders']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching previous orders: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrevious = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D2D2D), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Order History',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Tab header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  _buildTabItem(0, 'Current Order'),
                  const SizedBox(width: 24),
                  _buildTabItem(1, 'Previous Order'),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F2F5)),
            Expanded(
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              color: isSelected ? const Color(0xFF1E2022) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? 48 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2022),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 0) {
      return _buildCurrentOrderView();
    } else {
      return _buildPreviousOrderView();
    }
  }

  Widget _buildCurrentOrderView() {
    final isLoggedIn = CubePod.get<AuthRepository>().isLoggedIn;
    if (!isLoggedIn) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
          },
          child: const Text('Log In to view orders'),
        ),
      );
    }

    if (_isLoadingCurrent) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)));
    }

    if (_currentOrders.isEmpty) {
      return const Center(
        child: Text(
          'No active orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      itemCount: _currentOrders.length,
      itemBuilder: (context, index) {
        final order = _currentOrders[index];
        final store = order['store'] ?? 'Nippon Mart';
        final status = order['status'] ?? 'Pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF42A769).withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Status: ${order['status'] ?? 'Pending'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                store,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF42A769), size: 20),
                  Expanded(child: Container(height: 2, color: const Color(0xFF42A769))),
                  const Icon(Icons.local_shipping, color: Color(0xFF42A769), size: 24),
                  Expanded(child: Container(height: 2, color: Colors.grey.shade300)),
                  Icon(Icons.home, color: Colors.grey.shade300, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Packed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Delivering', style: TextStyle(fontSize: 12, color: Color(0xFF42A769), fontWeight: FontWeight.bold)),
                  Text('Arrived', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF0F2F5)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ' •  Items',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E2022)),
                  ),
                  Row(
                    children: [
                      if (order['status'] == 'Pending') ...[
                        GestureDetector(
                          onTap: () => _cancelOrder(order['id']),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailPage(order: order),
                            ),
                          );
                        },
                        child: const Text(
                          'View Detail',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF42A769)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviousOrderView() {
    final isLoggedIn = CubePod.get<AuthRepository>().isLoggedIn;
    if (!isLoggedIn) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
          },
          child: const Text('Log In to view orders'),
        ),
      );
    }

    if (_isLoadingPrevious) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)));
    }

    if (_previousOrders.isEmpty) {
      return const Center(
        child: Text(
          'No previous orders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _previousOrders.length,
      itemBuilder: (context, index) {
        final order = _previousOrders[index];
        final orderItems = order['order_items'] as List? ?? [];
        final store = order['store'] ?? 'Nippon Mart';
        final status = order['status'] ?? 'Delivered';
        final createdAt = order['created_at'] != null ? order['created_at'].toString().substring(0, 10) : '';

        // Safely extract product image if available
        String? imageUrl;
        if (orderItems.isNotEmpty && orderItems[0]['products'] != null) {
           imageUrl = orderItems[0]['products']['image'];
        }
        final displayImage = imageUrl ?? 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=150&q=80';

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          displayImage,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 58,
                                height: 58,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2022),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order - ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              createdAt,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(status),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(status).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getStatusColor(status),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ' •  Items',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2022),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailPage(order: order),
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Text(
                              'View Detail',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 24, color: Color(0xFFF0F2F5)),
          ],
        );
      },
    );
  }
}
