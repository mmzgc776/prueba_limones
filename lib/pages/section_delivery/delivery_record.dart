class DeliveryRecord {
  final int deliveryNumber;
  final DateTime date;
  final Duration duration;
  final double avgPrice;
  final double kilograms;
  final int boxes;
  final double remaining;
  final String seller;
  final double total;

  DeliveryRecord({
    required this.deliveryNumber,
    required this.date,
    required this.duration,
    required this.avgPrice,
    required this.kilograms,
    required this.boxes,
    required this.remaining,
    required this.seller,
    required this.total,
  });
}
