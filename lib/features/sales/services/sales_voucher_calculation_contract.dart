class SalesVoucherCalcLineInput {
  const SalesVoucherCalcLineInput({
    required this.itemCode,
    required this.itemName,
    required this.hsnSac,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.discount,
    required this.gstRate,
  });

  final String itemCode;
  final String itemName;
  final String hsnSac;
  final double quantity;
  final String unit;
  final double rate;
  final double discount;
  final double gstRate;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'itemCode': itemCode,
    'itemName': itemName,
    'hsnSac': hsnSac,
    'quantity': quantity,
    'unit': unit,
    'rate': rate,
    'discount': discount,
    'gstRate': gstRate,
  };
}

class SalesVoucherCalcChargeInput {
  const SalesVoucherCalcChargeInput({
    required this.name,
    required this.amount,
    required this.gstApplicable,
    required this.gstRate,
  });

  final String name;
  final double amount;
  final bool gstApplicable;
  final double gstRate;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'amount': amount,
    'gstApplicable': gstApplicable,
    'gstRate': gstRate,
  };
}

class SalesVoucherCalculationRequest {
  const SalesVoucherCalculationRequest({
    required this.sellerState,
    required this.placeOfSupply,
    required this.invoiceDiscount,
    required this.items,
    required this.charges,
  });

  final String sellerState;
  final String placeOfSupply;
  final double invoiceDiscount;
  final List<SalesVoucherCalcLineInput> items;
  final List<SalesVoucherCalcChargeInput> charges;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'sellerState': sellerState,
    'placeOfSupply': placeOfSupply,
    'invoiceDiscount': invoiceDiscount,
    'items': items.map((item) => item.toMap()).toList(growable: false),
    'charges': charges.map((charge) => charge.toMap()).toList(growable: false),
  };
}

class SalesVoucherCalculationResult {
  const SalesVoucherCalculationResult({
    this.subtotal = 0,
    this.itemDiscount = 0,
    this.invoiceDiscount = 0,
    this.taxableValue = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.cess = 0,
    this.otherCharges = 0,
    this.totalGst = 0,
    this.roundOff = 0,
    this.grandTotal = 0,
    this.amountInWords = '',
    this.taxTreatment = 'LOCAL',
  });

  final double subtotal;
  final double itemDiscount;
  final double invoiceDiscount;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double otherCharges;
  final double totalGst;
  final double roundOff;
  final double grandTotal;
  final String amountInWords;
  final String taxTreatment;

  factory SalesVoucherCalculationResult.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;

    return SalesVoucherCalculationResult(
      subtotal: asDouble(map['subtotal']),
      itemDiscount: asDouble(map['itemDiscount']),
      invoiceDiscount: asDouble(map['invoiceDiscount']),
      taxableValue: asDouble(map['taxableValue']),
      cgst: asDouble(map['cgst']),
      sgst: asDouble(map['sgst']),
      igst: asDouble(map['igst']),
      cess: asDouble(map['cess']),
      otherCharges: asDouble(map['otherCharges']),
      totalGst: asDouble(map['totalGst']),
      roundOff: asDouble(map['roundOff']),
      grandTotal: asDouble(map['grandTotal']),
      amountInWords: map['amountInWords']?.toString() ?? '',
      taxTreatment: map['taxTreatment']?.toString() ?? 'LOCAL',
    );
  }
}
