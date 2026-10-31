import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  String _selectedMethod = 'Cash on Delivery';
  final List<Map<String, dynamic>> _methods = [
    {
      'id': '1',
      'name': 'Cash on Delivery',
      'subtitle': 'Pay with cash upon package delivery',
      'icon_name': 'payments',
      'is_active': true,
    },
    {
      'id': '2',
      'name': 'Debit / Credit Card',
      'subtitle': 'Visa, Mastercard & UnionPay accepted',
      'icon_name': 'credit_card',
      'is_active': true,
    },
    {
      'id': '3',
      'name': 'eSewa / Khalti / Mobile Wallet',
      'subtitle': 'Instant digital wallet payment',
      'icon_name': 'account_balance_wallet',
      'is_active': true,
    },
  ];

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'credit_card':
      case 'card':
        return Icons.credit_card_rounded;
      case 'account_balance_wallet':
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'payments':
      case 'cash':
      default:
        return Icons.payments_rounded;
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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Payment Methods',
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
                  Text(
                    'Available Payment Options',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select your default preferred payment method for faster checkout.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ...List.generate(_methods.length, (index) {
                    final item = _methods[index];
                    final name = item['name'] as String;
                    final subtitle = item['subtitle'] as String;
                    final isSelected = _selectedMethod == name;
                    final iconName = item['icon_name'] as String? ?? 'payments';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF185B3A).withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() => _selectedMethod = name);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Default payment set to $name', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xFF185B3A),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFE8F5EE) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _resolveIcon(iconName),
                                  color: isSelected ? const Color(0xFF185B3A) : const Color(0xFF64748B),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5EE),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Default',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF185B3A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF185B3A) : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFCBD5E1),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF185B3A), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All transactions and customer payment credentials are fully encrypted and verified directly at the door or via authorized gateway protocols.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
