import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../../controllers/app_provider.dart';

// Import all the screens
import 'account_screen.dart';
import 'shop_detail_screen.dart';
import 'shop_list_screen.dart';
import 'shop_map_screen.dart';
import 'ticket_screen.dart';

class CustomerFlow extends StatefulWidget {
  const CustomerFlow({super.key});

  @override
  State<CustomerFlow> createState() => _CustomerFlowState();
}

class _CustomerFlowState extends State<CustomerFlow> {
  int tab = 0; // 0 = home, 1 = ticket, 2 = account, 3 = map
  Shop? openedShop;

  @override
  Widget build(BuildContext context) {
    // This is the magic line that connects to the Provider!
    final provider = context.watch<AppProvider>();
    Widget body;

    if (openedShop != null) {
      body = ShopDetailScreen(
        shop: openedShop!,
        isSubscribed: provider.mySubShopIds.contains(openedShop!.id),
        subscribing: provider.subscribing,
        joiningQueue: provider.joiningQueue,
        cancelling: provider.cancellingShopId == openedShop!.id,
        queuedElsewhere: provider.myTicket != null && provider.myTicketShopId != openedShop!.id,
        onBack: () => setState(() => openedShop = null),
        onSubscribe: () => provider.subscribe(openedShop!.id),
        onWalkIn: () async {
          final shopId = openedShop!.id;
          await provider.walkIn(shopId);
          if (mounted) {
            setState(() {
              openedShop = null;
              tab = 1;
            });
          }
        },
        onCancel: () => provider.cancelSubscription(openedShop!.id),
      );
    } else if (tab == 1 && provider.myTicket != null) {
      final shop = provider.shops.firstWhere((s) => s.id == provider.myTicketShopId);
      body = TicketScreen(
        shop: shop,
        ticket: provider.myTicket!,
        position: provider.myTicketPosition ?? 1,
        leaving: provider.leavingQueue,
        refreshing: provider.refreshingTicket,
        onLeave: provider.leaveQueue,
        onRefresh: provider.refreshTicket,
      );
    } else if (tab == 2) {
      body = AccountScreen(
        shops: provider.shops.where((s) => provider.mySubShopIds.contains(s.id)).toList(),
        cancellingShopId: provider.cancellingShopId,
        onCancel: provider.cancelSubscription,
        notificationsEnabled: provider.notificationsEnabled,
        checkingNotificationPermission: provider.checkingNotificationPermission,
        onEnableNotifications: provider.requestNotificationPermission,
      );
    } else if (tab == 3) {
      body = ShopMapScreen(
        shops: provider.shops,
        onOpen: (s) => setState(() => openedShop = s),
        refreshingShops: provider.refreshingShops,
        onRefreshShops: provider.refreshShops,
      );
    } else {
      body = ShopListScreen(
        shops: provider.shops,
        onOpen: (s) => setState(() => openedShop = s),
        refreshingShops: provider.refreshingShops,
        onRefreshShops: provider.refreshShops,
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
                _navItem('Ticket', 1, disabled: provider.myTicket == null),
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