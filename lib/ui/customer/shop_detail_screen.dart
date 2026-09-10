import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../../controllers/app_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/outline_button.dart';

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
    
    // 1. Grab the provider using the main screen's context BEFORE opening the dialog
    final provider = context.read<AppProvider>();

    showDialog(
      context: context,
      // 2. Rename this context to 'dialogContext'
      builder: (dialogContext) => StatefulBuilder(
        // 3. Rename this context to 'stateContext'
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
                // 4. Use the captured provider directly!
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

  @override
  Widget build(BuildContext context) {
    // Tells the UI to listen for real-time updates for this specific shop
    final currentShop = context.watch<AppProvider>().shops.firstWhere((s) => s.id == shop.id, orElse: () => shop);
    
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
                        // We added the review count in parentheses right here!
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
                          Text('You are a regular here', style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Walk in',
                        loading: joiningQueue,
                        onTap: queuedElsewhere ? () {} : onWalkIn,
                      ),
                      if (queuedElsewhere)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text("You're already in a queue somewhere else.", style: TextStyle(color: AppColors.red, fontSize: 12), textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 12),
                      CustomOutlineButton(
                        label: 'Cancel subscription',
                        loading: cancelling,
                        onTap: onCancel,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text('R${currentShop.price} / month', style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Unlimited walk-ins. No booking required.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Subscribe & Walk in',
                  loading: subscribing,
                  onTap: onSubscribe,
                ),
              ],
              
              const SizedBox(height: 32),
              
              if (currentShop.services.isNotEmpty) ...[
                const Text("SERVICES", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: currentShop.services.map((service) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(service, style: const TextStyle(color: AppColors.text, fontSize: 13)),
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