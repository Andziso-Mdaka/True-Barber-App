import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../../models/queue_entry.dart';
import '../widgets/outline_button.dart';

class TicketScreen extends StatelessWidget {
  final Shop shop;
  final QueueEntry ticket;
  final int position;
  final bool leaving;
  final bool refreshing;
  final VoidCallback onLeave;
  final VoidCallback onRefresh;
  const TicketScreen({
    super.key,
    required this.shop,
    required this.ticket,
    required this.position,
    required this.leaving,
    required this.refreshing,
    required this.onLeave,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final called = ticket.status == 'called';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: refreshing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass),
                    )
                  : const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
              onPressed: refreshing ? null : onRefresh,
              tooltip: 'Check for updates',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: called ? AppColors.brass.withOpacity(0.12) : AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brass.withOpacity(called ? 0.9 : 0.5), width: called ? 2 : 1),
            ),
            child: Column(
              children: [
                Text(shop.name,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text('${ticket.ticketNo}',
                    style: const TextStyle(color: AppColors.brass, fontSize: 56, fontWeight: FontWeight.bold)),
                if (called) ...[
                  const Icon(Icons.content_cut, color: AppColors.brass, size: 22),
                  const SizedBox(height: 6),
                  const Text("YOU'RE UP!",
                      style: TextStyle(color: AppColors.brass, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('Head to the shop now · barber ${ticket.barber}',
                      style: const TextStyle(color: AppColors.text, fontSize: 13)),
                ] else ...[
                  Text('Position $position in line · barber ${ticket.barber}',
                      style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Est. wait ~${position * 8} min',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          CustomOutlineButton(label: 'Leave queue', color: AppColors.red, onTap: onLeave, loading: leaving),
        ],
      ),
    );
  }
}