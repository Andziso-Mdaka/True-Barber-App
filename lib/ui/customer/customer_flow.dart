import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../../models/queue_entry.dart';

// Import all the screens we just created
import 'account_screen.dart';
import 'shop_detail_screen.dart';
import 'shop_list_screen.dart';
import 'shop_map_screen.dart';
import 'ticket_screen.dart';


class CustomerFlow extends StatefulWidget {
  final List<Shop> shops;
  final Set<String> mySubShopIds;
  final QueueEntry? myTicket;
  final int? myTicketPosition;
  final String? myTicketShopId;
  final bool subscribing;
  final String? cancellingShopId;
  final bool joiningQueue;
  final bool leavingQueue;
  final bool refreshingShops;
  final Future<void> Function() onRefreshShops;
  final bool notificationsEnabled;
  final bool checkingNotificationPermission;
  final Future<void> Function() onEnableNotifications;
  final bool refreshingTicket;
  final Future<void> Function() onRefreshTicket;
  final void Function(String shopId) onSubscribe;
  final void Function(String shopId) onCancelSubscription;
  final Future<void> Function(String shopId) onWalkIn;
  final VoidCallback onLeaveQueue;

  const CustomerFlow({
    super.key,
    required this.shops,
    required this.mySubShopIds,
    required this.myTicket,
    required this.myTicketPosition,
    required this.myTicketShopId,
    required this.subscribing,
    required this.cancellingShopId,
    required this.joiningQueue,
    required this.leavingQueue,
    required this.refreshingShops,
    required this.onRefreshShops,
    required this.notificationsEnabled,
    required this.checkingNotificationPermission,
    required this.onEnableNotifications,
    required this.refreshingTicket,
    required this.onRefreshTicket,
    required this.onSubscribe,
    required this.onCancelSubscription,
    required this.onWalkIn,
    required this.onLeaveQueue,
  });

  @override
  State<CustomerFlow> createState() => _CustomerFlowState();
}

class _CustomerFlowState extends State<CustomerFlow> {
  int tab = 0; // 0 = home, 1 = ticket, 2 = account, 3 = map
  Shop? openedShop;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (openedShop != null) {
      body = ShopDetailScreen(
        shop: openedShop!,
        isSubscribed: widget.mySubShopIds.contains(openedShop!.id),
        subscribing: widget.subscribing,
        joiningQueue: widget.joiningQueue,
        cancelling: widget.cancellingShopId == openedShop!.id,
        queuedElsewhere: widget.myTicket != null && widget.myTicketShopId != openedShop!.id,
        onBack: () => setState(() => openedShop = null),
        onSubscribe: () => widget.onSubscribe(openedShop!.id),
        onWalkIn: () async {
          final shopId = openedShop!.id;
          await widget.onWalkIn(shopId);
          if (mounted) {
            setState(() {
              openedShop = null;
              tab = 1;
            });
          }
        },
        onCancel: () => widget.onCancelSubscription(openedShop!.id),
      );
    } else if (tab == 1 && widget.myTicket != null) {
      final shop = widget.shops.firstWhere((s) => s.id == widget.myTicketShopId);
      body = TicketScreen(
        shop: shop,
        ticket: widget.myTicket!,
        position: widget.myTicketPosition ?? 1,
        leaving: widget.leavingQueue,
        refreshing: widget.refreshingTicket,
        onLeave: widget.onLeaveQueue,
        onRefresh: widget.onRefreshTicket,
      );
    } else if (tab == 2) {
      body = AccountScreen(
        shops: widget.shops.where((s) => widget.mySubShopIds.contains(s.id)).toList(),
        cancellingShopId: widget.cancellingShopId,
        onCancel: widget.onCancelSubscription,
        notificationsEnabled: widget.notificationsEnabled,
        checkingNotificationPermission: widget.checkingNotificationPermission,
        onEnableNotifications: widget.onEnableNotifications,
      );
    } else if (tab == 3) {
      body = ShopMapScreen(
        shops: widget.shops,
        onOpen: (s) => setState(() => openedShop = s),
        refreshingShops: widget.refreshingShops,
        onRefreshShops: widget.onRefreshShops,
      );
    } else {
      body = ShopListScreen(
        shops: widget.shops,
        onOpen: (s) => setState(() => openedShop = s),
        refreshingShops: widget.refreshingShops,
        onRefreshShops: widget.onRefreshShops,
      );
    }

    return Column(
      children: [
        Expanded(child: body),
        if (openedShop == null)
          BottomAppBar(
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem('Home', 0),
                _navItem('Map', 3),
                _navItem('Ticket', 1, disabled: widget.myTicket == null),
                _navItem('Account', 2),
              ],
            ),
          ),
      ],
    );
  }

  Widget _navItem(String label, int index, {bool disabled = false}) {
    final active = tab == index;
    return TextButton(
      onPressed: disabled ? null : () => setState(() => tab = index),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: active ? AppColors.brass : (disabled ? AppColors.textFaint : AppColors.textMuted),
        ),
      ),
    );
  }
}
