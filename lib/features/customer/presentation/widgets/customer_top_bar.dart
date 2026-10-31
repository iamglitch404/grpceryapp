import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:cubepod_flutter/cubepod_flutter.dart';
import 'package:app/core/widgets/top_bar.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/notifications/presentation/pages/notifications_page.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';
import 'package:app/features/customer/profile/presentation/pages/settings_page.dart';

/// Customer top navigation bar displaying the Dovan brand logo, live notification unread badge, and profile avatar.
class CustomerTopBar extends StatelessWidget implements PreferredSizeWidget {
  final double horizontalPadding;
  final Color? backgroundColor;

  const CustomerTopBar({
    super.key,
    this.horizontalPadding = 20.0,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(46.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: TopBar(
        backgroundColor: backgroundColor,
        horizontalPadding: horizontalPadding,
        verticalPadding: 0.0,
        customActions: _buildCustomerActions(context),
      ),
    );
  }

  List<Widget> _buildCustomerActions(BuildContext context) {
    return [
      CubeBuilder(
        builder: (context, watch) {
          final notifState = CubePod.get<NotificationState>();
          final unread = watch(notifState.unreadCount);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                splashRadius: 18,
                icon: SvgPicture.asset(
                  'assets/icons/ic_bell.svg',
                  width: 18.5,
                  height: 18.5,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF4A4A4A),
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              if (unread > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF44336),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(width: 5),
      ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: CubePod.get<AuthRepository>().authStateNotifier,
        builder: (context, user, _) {
          final avatar = user?['profile_image'] ?? user?['avatar_url'];
          final hasAvatar = avatar != null && avatar.toString().isNotEmpty;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: ClipOval(
                child: hasAvatar
                    ? Image.network(
                        avatar.toString(),
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF0F172A),
                            size: 17,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF0F172A),
                          size: 17,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    ];
  }
}

/// Standard Customer AppBar with identical height, alignment, and actions across all customer tabs.
class CustomerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double toolbarHeight;

  const CustomerAppBar({
    super.key,
    this.automaticallyImplyLeading = false,
    this.backgroundColor,
    this.toolbarHeight = 46.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight,
      backgroundColor: backgroundColor ?? const Color(0xFFF8F9FA),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      centerTitle: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleSpacing: 0,
      title: const CustomerTopBar(),
    );
  }
}

/// Standard Customer SliverAppBar with identical height, alignment, and actions for sliver scroll views.
class CustomerSliverAppBar extends StatelessWidget {
  final bool pinned;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double toolbarHeight;

  const CustomerSliverAppBar({
    super.key,
    this.pinned = true,
    this.automaticallyImplyLeading = false,
    this.backgroundColor,
    this.toolbarHeight = 46.0,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      pinned: pinned,
      toolbarHeight: toolbarHeight,
      backgroundColor: backgroundColor ?? const Color(0xFFF8F9FA),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      centerTitle: false,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleSpacing: 0,
      title: const CustomerTopBar(),
    );
  }
}
