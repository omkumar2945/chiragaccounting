class PurchaseItem {
  final String id;
  final String productName;
  final String hsnCode;
  final String unit;
  final double quantity;
  final double rate;
  final double gstPercentage;
  final Map<String, String> attributes;

  const PurchaseItem({
    required this.id,
    required this.productName,
    this.hsnCode = '',
    this.unit = 'Nos',
    required this.quantity,
    required this.rate,
    this.gstPercentage = 18,
    this.attributes = const <String, String>{},
  });

  double get taxableAmount => quantity * rate;
  double get gstAmount => taxableAmount * (gstPercentage / 100);
  double get lineTotal => taxableAmount + gstAmount;
}
