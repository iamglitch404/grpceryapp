import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

class ShareProductBottomSheet extends StatefulWidget {
  final String title;
  final String image;
  final String price;

  const ShareProductBottomSheet({
    super.key,
    required this.title,
    required this.image,
    required this.price,
  });

  static void show(BuildContext context, {
    required String title,
    required String image,
    required String price,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (BuildContext context) => ShareProductBottomSheet(
        title: title,
        image: image,
        price: price,
      ),
    );
  }

  @override
  State<ShareProductBottomSheet> createState() => _ShareProductBottomSheetState();
}

class _ShareProductBottomSheetState extends State<ShareProductBottomSheet> {
  final ScrollController _scrollController = ScrollController();

  void _slideToQr() {
    _scrollController.animateTo(
      MediaQuery.of(context).size.width,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutQuart,
    );
  }

  void _slideToShare() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutQuart,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildQrView(String shareUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: _slideToShare,
              ),
              const Text(
                'Product QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 48), // balance the back button
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(shareUrl)}&ecc=H',
                  width: 200,
                  height: 200,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      widget.image,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF185B3A)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('QR Code saved to gallery!')),
                    );
                  },
                  icon: const Icon(Icons.download, color: Color(0xFF185B3A), size: 18),
                  label: const Text('Download', style: TextStyle(color: Color(0xFF185B3A))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: const Color(0xFF185B3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Share.share('Scan this QR code to check out ${widget.title} on Dovan!');
                  },
                  icon: const Icon(Icons.share, color: Colors.white, size: 18),
                  label: const Text('Share', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareView(String shareUrl) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Share Product',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        
        // URL & Actions Box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Product Image thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // URL and Buttons Container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shareUrl,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied to clipboard')),
                          );
                        },
                        child: const Icon(Icons.copy, color: Color(0xFF39A968), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 20, color: Colors.grey.shade300),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _slideToQr,
                        child: const Icon(Icons.qr_code_scanner, color: Color(0xFF39A968), size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 24),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 24,
            children: [
              _buildShareOption(
                svgUrl: 'https://cdn.simpleicons.org/whatsapp/25D366',
                label: 'WhatsApp',
                bgColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this amazing product: ${widget.title} for only ${widget.price} on our Grocery App!');
                },
              ),
              _buildShareOption(
                svgUrl: 'https://cdn.simpleicons.org/facebook/1877F2',
                label: 'Facebook',
                bgColor: const Color(0xFF1877F2).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this amazing product: ${widget.title} for only ${widget.price} on our Grocery App!');
                },
              ),
              _buildShareOption(
                svgUrl: 'https://cdn.simpleicons.org/telegram/26A5E4',
                label: 'Telegram',
                bgColor: const Color(0xFF0088CC).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this amazing product: ${widget.title} for only ${widget.price} on our Grocery App!');
                },
              ),
              _buildShareOption(
                svgUrl: 'https://cdn.simpleicons.org/instagram/E4405F',
                label: 'Instagram',
                bgColor: const Color(0xFFE1306C).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this amazing product: ${widget.title} for only ${widget.price} on our Grocery App!');
                },
              ),
              _buildShareOption(
                svgUrl: 'https://cdn.simpleicons.org/x/000000',
                label: 'X',
                bgColor: Colors.black.withValues(alpha: 0.05),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this amazing product: ${widget.title} for only ${widget.price} on our Grocery App!');
                },
              ),
              _buildShareOption(
                svgUrl: 'https://cdn.simpleicons.org/reddit/FF4500',
                label: 'Reddit',
                bgColor: const Color(0xFFFF4500).withValues(alpha: 0.1),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this amazing product: ${widget.title} for only ${widget.price} on our Grocery App!');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShareOption({
    required String svgUrl,
    required String label,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 3.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.network(
                  svgUrl,
                  width: 28,
                  height: 28,
                  placeholderBuilder: (BuildContext context) => const SizedBox(
                    width: 28,
                    height: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shareUrl = 'https://dovan.app/product/${widget.title.replaceAll(' ', '-').toLowerCase()}';
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: screenWidth,
                  child: _buildShareView(shareUrl),
                ),
                SizedBox(
                  width: screenWidth,
                  child: _buildQrView(shareUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
