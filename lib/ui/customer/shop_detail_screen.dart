import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../../controllers/app_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/outline_button.dart';
import '../../models/shopService.dart';

class ShopDetailScreen extends StatelessWidget {
  final Shop shop;
  final bool isSubscribed;
  final bool subscribing;
  final bool joiningQueue;
  final bool cancelling;
  final bool queuedElsewhere;
  final VoidCallback onBack;
  final VoidCallback onSubscribe;
  final VoidCallback onWalkIn; 
  final VoidCallback onCancel;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    required this.isSubscribed,
    required this.subscribing,
    required this.joiningQueue,
    required this.cancelling,
    required this.queuedElsewhere,
    required this.onBack,
    required this.onSubscribe,
    required this.onWalkIn,
    required this.onCancel,
  });

  void _showReviewDialog(BuildContext context, String shopId) {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    
    final provider = context.read<AppProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('How was your cut?', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(
                    index < selectedRating ? Icons.star : Icons.star_border, 
                    color: AppColors.brass, 
                    size: 32
                  ),
                  onPressed: () => setState(() => selectedRating = index + 1),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                style: const TextStyle(color: AppColors.text),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brass, foregroundColor: AppColors.bg),
              onPressed: () {
                provider.submitReview(shopId, selectedRating, commentCtrl.text);
                Navigator.pop(dialogContext);
              },
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalkInModal(BuildContext context, Shop currentShop, bool isSubscribed, AppProvider provider) {
    ShopService? selectedService;
    String payMethod = isSubscribed ? 'subscription' : 'cash';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 20, right: 20, top: 24
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Join the Queue', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                const Text('1. WHAT ARE YOU GETTING?', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                if (currentShop.menu.isEmpty)
                  const Text('This shop needs to add services before you can walk in.', style: TextStyle(color: AppColors.red, fontSize: 13))
                else
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: currentShop.menu.map((s) {
                      final isSelected = selectedService?.id == s.id;
                      return GestureDetector(
                        onTap: () => setState(() => selectedService = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.brass.withOpacity(0.15) : AppColors.surface2,
                            border: Border.all(color: isSelected ? AppColors.brass : AppColors.line),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${s.name} - R${s.price}', 
                            style: TextStyle(
                              color: isSelected ? AppColors.brass : AppColors.text, 
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 32),
                
                const Text('2. HOW ARE YOU PAYING?', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                
                if (isSubscribed)
                  RadioListTile<String>(
                    title: const Text('VIP Pass', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Covered by your 30-Day Pass', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                    activeColor: AppColors.brass,
                    contentPadding: EdgeInsets.zero,
                    value: 'subscription',
                    groupValue: payMethod,
                    onChanged: (v) => setState(() => payMethod = v!),
                  ),
                RadioListTile<String>(
                  title: const Text('Cash In-Store', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Pay the barber directly', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  activeColor: AppColors.brass,
                  contentPadding: EdgeInsets.zero,
                  value: 'cash',
                  groupValue: payMethod,
                  onChanged: (v) => setState(() => payMethod = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Once-off via App', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  subtitle: Text(selectedService != null ? 'Pay R${selectedService!.price} now' : 'Select a service to see price', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  activeColor: AppColors.brass,
                  contentPadding: EdgeInsets.zero,
                  value: 'once_off',
                  groupValue: payMethod,
                  onChanged: (v) => setState(() => payMethod = v!),
                ),
                
                const SizedBox(height: 24),
                PrimaryButton(
  label: 'Confirm & Join Queue',
  loading: joiningQueue,
  onTap: () async {
    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service first')),
      );
      return;
    }

    Navigator.pop(sheetContext);

    if (payMethod == 'once_off') {
      // IMPORTANT: do NOT call provider.walkIn() here. The queue entry for
      // a once-off payment is created SERVER-SIDE, inside the Yoco webhook,
      // only once payment.succeeded genuinely fires. Calling walkIn() here
      // would join the queue the instant the checkout tab opens, regardless
      // of whether the customer ever actually pays — which was the bug.
      await provider.processYocoPayment(
        amount: selectedService!.price,
        shopId: currentShop.id,
        paymentType: 'once_off',
        serviceName: selectedService!.name,
      );
      // The checkout tab is now open. There is a real gap — seconds, maybe
      // longer — between now and the webhook actually creating the ticket.
      // Tell the customer plainly rather than pretending it's instant.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Complete payment in the tab that just opened — "
                "your ticket will appear here once it's confirmed."),
            duration: Duration(seconds: 5),
          ),
        );
      }
      // Best-effort auto-refresh while they're likely still completing
      // checkout, so the ticket shows up without them needing to think
      // about pulling to refresh themselves.
      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 3));
        await provider.refreshTicket();
        if (provider.myTicket != null) break;
      }
    } else {
      // Cash and subscription-covered walk-ins have nothing to wait on —
      // there's no payment gate for either, so joining immediately is correct.
      await provider.walkIn(currentShop.id, payMethod, selectedService!);
      onWalkIn();
    }
  },
),
              ],
            ),
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currentShop = provider.shops.firstWhere((s) => s.id == shop.id, orElse: () => shop);
    
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.text),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Text(
                    currentShop.name,
                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  image: currentShop.photoUrl != null
                      ? DecorationImage(image: NetworkImage(currentShop.photoUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: currentShop.photoUrl == null
                    ? const Center(child: Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 48))
                    : null,
              ),
              
              if (currentShop.portfolioUrls.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text("PORTFOLIO", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: currentShop.portfolioUrls.length,
                    itemBuilder: (context, i) {
                      return Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 8),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          image: DecorationImage(image: NetworkImage(currentShop.portfolioUrls[i]), fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentShop.name, style: const TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${currentShop.area} · ${currentShop.chairs} chairs', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        if (currentShop.phone != null && currentShop.phone!.isNotEmpty) ...[
                           const SizedBox(height: 4),
                           Row(
                             children: [
                               const Icon(Icons.phone, color: AppColors.brass, size: 14),
                               const SizedBox(width: 4),
                               Text(currentShop.phone!, style: const TextStyle(color: AppColors.brass, fontSize: 13, fontWeight: FontWeight.w600)),
                             ],
                           )
                        ]
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brass.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: AppColors.brass, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${currentShop.rating.toStringAsFixed(1)} (${currentShop.reviews.length})', 
                          style: const TextStyle(color: AppColors.brass, fontWeight: FontWeight.bold, fontSize: 13)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (isSubscribed) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brass.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.brass.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.brass, size: 20),
                          SizedBox(width: 10),
                          Text('You have a 30-Day VIP Pass', style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Walk in',
                        loading: joiningQueue,
                        onTap: queuedElsewhere ? () {} : () => _showWalkInModal(context, currentShop, true, provider),
                      ),
                      if (queuedElsewhere)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text("You're already in a queue somewhere else.", style: TextStyle(color: AppColors.red, fontSize: 12), textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 12),
                      CustomOutlineButton(
                        label: 'Pass Info', // Updated from Cancel Subscription
                        loading: cancelling,
                        onTap: onCancel,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // UPDATED UI: 30-Day pass phrasing instead of monthly auto-renew
                Text('R${currentShop.price} / 30 Days', style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Unlimited walk-ins. Valid for 30 days.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Buy VIP Pass',
                  loading: subscribing,
                  onTap: () async {
                    // NEW LOGIC: Trigger Yoco directly for the subscription
                    final paymentStarted = await provider.processYocoPayment(
                      amount: currentShop.price,
                      shopId: currentShop.id,
                      paymentType: 'subscription',
                      serviceName: '30-Day VIP Pass',
                    );
                    
                    if (paymentStarted) {
                      // Trigger the callback to tell the parent UI to refresh data
                      onSubscribe(); 
                    }
                  },
                ),
                const SizedBox(height: 12),
                CustomOutlineButton(
                  label: 'Just Walk In (Once-off / Cash)',
                  loading: joiningQueue,
                  onTap: queuedElsewhere ? () {} : () => _showWalkInModal(context, currentShop, false, provider),
                ),
                if (queuedElsewhere)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text("You're already in a queue somewhere else.", style: TextStyle(color: AppColors.red, fontSize: 12), textAlign: TextAlign.center),
                  ),
              ],
              
              const SizedBox(height: 32),
              
              if (currentShop.menu.isNotEmpty) ...[
                const Text("MENU", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: currentShop.menu.map((service) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text('${service.name} - R${service.price}', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  )).toList(),
                ),
                const SizedBox(height: 24),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("REVIEWS", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                  GestureDetector(
                    onTap: () => _showReviewDialog(context, currentShop.id),
                    child: const Text('Write a review', style: TextStyle(color: AppColors.brass, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (currentShop.reviews.isEmpty)
                const Text("No reviews yet. Be the first to leave one!", style: TextStyle(color: AppColors.textFaint, fontSize: 12))
              else
                ...currentShop.reviews.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (index) => Icon(
                                index < r.rating ? Icons.star : Icons.star_border,
                                color: AppColors.brass,
                                size: 14,
                              )),
                            ],
                          ),
                          Text(
                            '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}', 
                            style: const TextStyle(color: AppColors.textFaint, fontSize: 10)
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.customerName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 12)),
                      if (r.comment != null && r.comment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.comment!, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                      ]
                    ],
                  ),
                )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}