class ShopService {
  final String id;
  final String shopId;
  final String name;
  final int price;

  ShopService({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
  });

  factory ShopService.fromJson(Map<String, dynamic> json) {
    return ShopService(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
    );
  }
}