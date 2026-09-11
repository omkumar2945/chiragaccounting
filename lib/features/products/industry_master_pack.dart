class IndustryPackProduct {
  final String category;
  final String name;
  final String hsnCode;
  final double gstPercentage;
  final String unit;

  const IndustryPackProduct({
    required this.category,
    required this.name,
    required this.hsnCode,
    required this.gstPercentage,
    required this.unit,
  });
}

class IndustryMasterPack {
  final String key;
  final String label;
  final List<IndustryPackProduct> products;

  const IndustryMasterPack({
    required this.key,
    required this.label,
    required this.products,
  });
}

class IndustryMasterPacks {
  static const List<IndustryMasterPack> packs = [
    IndustryMasterPack(
      key: 'glass_aluminium',
      label: 'Glass & Aluminium',
      products: [
        IndustryPackProduct(category: 'Glass', name: '10mm Toughened Glass', hsnCode: '70071900', gstPercentage: 18, unit: 'Sq. Ft.'),
        IndustryPackProduct(category: 'Glass', name: '12mm Toughened Glass', hsnCode: '70071900', gstPercentage: 18, unit: 'Sq. Ft.'),
        IndustryPackProduct(category: 'Glass', name: '12.76 Laminated Glass', hsnCode: '70072190', gstPercentage: 18, unit: 'Sq. Ft.'),
        IndustryPackProduct(category: 'Glass', name: 'Float Glass', hsnCode: '70051010', gstPercentage: 18, unit: 'Sq. Ft.'),
        IndustryPackProduct(category: 'Aluminium Hardware', name: 'Patch Fitting', hsnCode: '83024110', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Aluminium Hardware', name: 'Floor Spring', hsnCode: '83024110', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Aluminium Hardware', name: 'Silicone Sealant', hsnCode: '35061000', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Aluminium Hardware', name: 'ACP Sheet', hsnCode: '39252000', gstPercentage: 18, unit: 'Sheet'),
      ],
    ),
    IndustryMasterPack(
      key: 'medical_pharmacy',
      label: 'Medical & Pharmacy',
      products: [
        IndustryPackProduct(category: 'Medicines', name: 'Tablet', hsnCode: '30049099', gstPercentage: 12, unit: 'Strip'),
        IndustryPackProduct(category: 'Medicines', name: 'Capsule', hsnCode: '30049099', gstPercentage: 12, unit: 'Strip'),
        IndustryPackProduct(category: 'Medicines', name: 'Syrup', hsnCode: '30049099', gstPercentage: 12, unit: 'Bottle'),
        IndustryPackProduct(category: 'Medicines', name: 'Injection', hsnCode: '30049099', gstPercentage: 12, unit: 'Nos'),
        IndustryPackProduct(category: 'Surgical', name: 'Surgical Gloves', hsnCode: '40151100', gstPercentage: 12, unit: 'Pair'),
        IndustryPackProduct(category: 'Consumables', name: 'Cotton Roll', hsnCode: '30059090', gstPercentage: 12, unit: 'Roll'),
      ],
    ),
    IndustryMasterPack(
      key: 'grocery_supermarket',
      label: 'Grocery & Supermarket',
      products: [
        IndustryPackProduct(category: 'Staples', name: 'Rice', hsnCode: '10063090', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Staples', name: 'Dal', hsnCode: '07139090', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Staples', name: 'Atta', hsnCode: '11010000', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Essentials', name: 'Sugar', hsnCode: '17019990', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Essentials', name: 'Refined Oil', hsnCode: '15121990', gstPercentage: 5, unit: 'Ltr'),
        IndustryPackProduct(category: 'Snacks', name: 'Biscuits', hsnCode: '19053100', gstPercentage: 18, unit: 'Pack'),
        IndustryPackProduct(category: 'Beverages', name: 'Soft Drink', hsnCode: '22021090', gstPercentage: 28, unit: 'Bottle'),
      ],
    ),
    IndustryMasterPack(
      key: 'restaurant_hotel',
      label: 'Restaurant & Hotel',
      products: [
        IndustryPackProduct(category: 'Food Items', name: 'Meal Combo', hsnCode: '996331', gstPercentage: 5, unit: 'Nos'),
        IndustryPackProduct(category: 'Beverages', name: 'Fresh Juice', hsnCode: '22029990', gstPercentage: 12, unit: 'Glass'),
        IndustryPackProduct(category: 'Kitchen Raw Material', name: 'Cooking Oil', hsnCode: '15121990', gstPercentage: 5, unit: 'Ltr'),
        IndustryPackProduct(category: 'Packaging', name: 'Food Container', hsnCode: '39241090', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'hardware_electrical',
      label: 'Hardware & Electrical',
      products: [
        IndustryPackProduct(category: 'Hardware', name: 'Door Hinge', hsnCode: '83021010', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Hardware', name: 'Lock Set', hsnCode: '83014090', gstPercentage: 18, unit: 'Set'),
        IndustryPackProduct(category: 'Hardware', name: 'Screw Box', hsnCode: '73181500', gstPercentage: 18, unit: 'Box'),
        IndustryPackProduct(category: 'Electrical', name: 'LED Bulb', hsnCode: '85395000', gstPercentage: 12, unit: 'Nos'),
        IndustryPackProduct(category: 'Electrical', name: 'Switch Board', hsnCode: '85365090', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Electrical', name: 'Wire Roll', hsnCode: '85444999', gstPercentage: 18, unit: 'Roll'),
      ],
    ),
    IndustryMasterPack(
      key: 'textile_garments',
      label: 'Textile & Garments',
      products: [
        IndustryPackProduct(category: 'Fabric', name: 'Cotton Fabric', hsnCode: '52085290', gstPercentage: 5, unit: 'Mtr'),
        IndustryPackProduct(category: 'Fabric', name: 'Polyester Fabric', hsnCode: '54075290', gstPercentage: 12, unit: 'Mtr'),
        IndustryPackProduct(category: 'Garments', name: 'Shirt', hsnCode: '62052000', gstPercentage: 5, unit: 'Nos'),
        IndustryPackProduct(category: 'Garments', name: 'T-Shirt', hsnCode: '61091000', gstPercentage: 5, unit: 'Nos'),
        IndustryPackProduct(category: 'Accessories', name: 'Zip', hsnCode: '96071900', gstPercentage: 12, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'bakery',
      label: 'Bakery',
      products: [
        IndustryPackProduct(category: 'Bakery Items', name: 'Bread', hsnCode: '19059090', gstPercentage: 5, unit: 'Nos'),
        IndustryPackProduct(category: 'Bakery Items', name: 'Cake', hsnCode: '19059040', gstPercentage: 18, unit: 'Kg'),
        IndustryPackProduct(category: 'Bakery Items', name: 'Pastry', hsnCode: '19059040', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'sweet_shop',
      label: 'Sweet Shop',
      products: [
        IndustryPackProduct(category: 'Sweets', name: 'Kaju Katli', hsnCode: '21069099', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Sweets', name: 'Ladoo', hsnCode: '21069099', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Snacks', name: 'Namkeen', hsnCode: '21069099', gstPercentage: 12, unit: 'Kg'),
      ],
    ),
    IndustryMasterPack(
      key: 'hardware',
      label: 'Hardware',
      products: [
        IndustryPackProduct(category: 'Hardware', name: 'Nuts and Bolts', hsnCode: '73181500', gstPercentage: 18, unit: 'Box'),
        IndustryPackProduct(category: 'Hardware', name: 'Door Handle', hsnCode: '83024110', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Hardware', name: 'Pad Lock', hsnCode: '83014090', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'electrical',
      label: 'Electrical',
      products: [
        IndustryPackProduct(category: 'Electrical', name: 'MCB', hsnCode: '85362000', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Electrical', name: 'Copper Wire', hsnCode: '85444999', gstPercentage: 18, unit: 'Roll'),
        IndustryPackProduct(category: 'Electrical', name: 'LED Tube Light', hsnCode: '94054090', gstPercentage: 12, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'paint',
      label: 'Paint',
      products: [
        IndustryPackProduct(category: 'Paint', name: 'Wall Putty', hsnCode: '32149090', gstPercentage: 18, unit: 'Bag'),
        IndustryPackProduct(category: 'Paint', name: 'Interior Emulsion', hsnCode: '32091090', gstPercentage: 18, unit: 'Ltr'),
        IndustryPackProduct(category: 'Paint', name: 'Primer', hsnCode: '32081090', gstPercentage: 18, unit: 'Ltr'),
      ],
    ),
    IndustryMasterPack(
      key: 'automobile',
      label: 'Automobile',
      products: [
        IndustryPackProduct(category: 'Spare Parts', name: 'Engine Oil', hsnCode: '27101980', gstPercentage: 18, unit: 'Ltr'),
        IndustryPackProduct(category: 'Spare Parts', name: 'Brake Pad', hsnCode: '87083000', gstPercentage: 28, unit: 'Set'),
        IndustryPackProduct(category: 'Accessories', name: 'Car Battery', hsnCode: '85071000', gstPercentage: 28, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'mobile_shop',
      label: 'Mobile Shop',
      products: [
        IndustryPackProduct(category: 'Mobiles', name: 'Android Smartphone', hsnCode: '85171300', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Accessories', name: 'Mobile Charger', hsnCode: '85044089', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Accessories', name: 'Tempered Glass', hsnCode: '70071900', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'electronics',
      label: 'Electronics',
      products: [
        IndustryPackProduct(category: 'Electronics', name: 'LED TV', hsnCode: '85287217', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Electronics', name: 'Mixer Grinder', hsnCode: '85094010', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Accessories', name: 'Remote Control', hsnCode: '85299090', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'textile',
      label: 'Textile',
      products: [
        IndustryPackProduct(category: 'Fabric', name: 'Denim Fabric', hsnCode: '52094200', gstPercentage: 5, unit: 'Mtr'),
        IndustryPackProduct(category: 'Fabric', name: 'Linen Fabric', hsnCode: '53092990', gstPercentage: 5, unit: 'Mtr'),
        IndustryPackProduct(category: 'Yarn', name: 'Cotton Yarn', hsnCode: '52051200', gstPercentage: 5, unit: 'Kg'),
      ],
    ),
    IndustryMasterPack(
      key: 'garments',
      label: 'Garments',
      products: [
        IndustryPackProduct(category: 'Garments', name: 'Jeans', hsnCode: '62034200', gstPercentage: 12, unit: 'Nos'),
        IndustryPackProduct(category: 'Garments', name: 'Kurti', hsnCode: '62064000', gstPercentage: 5, unit: 'Nos'),
        IndustryPackProduct(category: 'Garments', name: 'School Uniform', hsnCode: '62032200', gstPercentage: 5, unit: 'Set'),
      ],
    ),
    IndustryMasterPack(
      key: 'jewellery',
      label: 'Jewellery',
      products: [
        IndustryPackProduct(category: 'Gold', name: 'Gold Ring', hsnCode: '71131910', gstPercentage: 3, unit: 'Nos'),
        IndustryPackProduct(category: 'Silver', name: 'Silver Chain', hsnCode: '71131120', gstPercentage: 3, unit: 'Nos'),
        IndustryPackProduct(category: 'Diamond', name: 'Diamond Pendant', hsnCode: '71131930', gstPercentage: 3, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'furniture',
      label: 'Furniture',
      products: [
        IndustryPackProduct(category: 'Furniture', name: 'Office Chair', hsnCode: '94013000', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Furniture', name: 'Wooden Table', hsnCode: '94036000', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Furniture', name: 'Steel Rack', hsnCode: '94032090', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'construction',
      label: 'Construction',
      products: [
        IndustryPackProduct(category: 'Material', name: 'Cement Bag', hsnCode: '25232930', gstPercentage: 28, unit: 'Bag'),
        IndustryPackProduct(category: 'Material', name: 'TMT Steel', hsnCode: '72142090', gstPercentage: 18, unit: 'Ton'),
        IndustryPackProduct(category: 'Material', name: 'Sand', hsnCode: '25059000', gstPercentage: 5, unit: 'Ton'),
      ],
    ),
    IndustryMasterPack(
      key: 'manufacturing',
      label: 'Manufacturing',
      products: [
        IndustryPackProduct(category: 'Raw Material', name: 'Industrial Chemical', hsnCode: '38249900', gstPercentage: 18, unit: 'Kg'),
        IndustryPackProduct(category: 'Raw Material', name: 'Packing Box', hsnCode: '48191010', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Finished Goods', name: 'Finished Product SKU-A', hsnCode: '84798999', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'agriculture',
      label: 'Agriculture',
      products: [
        IndustryPackProduct(category: 'Seeds', name: 'Wheat Seeds', hsnCode: '10011100', gstPercentage: 5, unit: 'Kg'),
        IndustryPackProduct(category: 'Fertilizers', name: 'Urea', hsnCode: '31021000', gstPercentage: 5, unit: 'Bag'),
        IndustryPackProduct(category: 'Tools', name: 'Sprayer Pump', hsnCode: '84244100', gstPercentage: 12, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'printing',
      label: 'Printing',
      products: [
        IndustryPackProduct(category: 'Paper', name: 'A4 Paper Ream', hsnCode: '48025690', gstPercentage: 12, unit: 'Pack'),
        IndustryPackProduct(category: 'Ink', name: 'Cyan Ink', hsnCode: '32159090', gstPercentage: 18, unit: 'Bottle'),
        IndustryPackProduct(category: 'Services', name: 'Offset Printing', hsnCode: '998912', gstPercentage: 18, unit: 'Job'),
      ],
    ),
    IndustryMasterPack(
      key: 'transport',
      label: 'Transport',
      products: [
        IndustryPackProduct(category: 'Transport Service', name: 'Local Goods Trip', hsnCode: '996511', gstPercentage: 5, unit: 'Trip'),
        IndustryPackProduct(category: 'Transport Service', name: 'Interstate Goods Trip', hsnCode: '996511', gstPercentage: 12, unit: 'Trip'),
        IndustryPackProduct(category: 'Fuel', name: 'Diesel Expense Allocation', hsnCode: '27101930', gstPercentage: 18, unit: 'Ltr'),
      ],
    ),
    IndustryMasterPack(
      key: 'logistics',
      label: 'Logistics',
      products: [
        IndustryPackProduct(category: 'Logistics Service', name: 'Warehousing', hsnCode: '996721', gstPercentage: 18, unit: 'Month'),
        IndustryPackProduct(category: 'Logistics Service', name: 'Last Mile Delivery', hsnCode: '996812', gstPercentage: 18, unit: 'Shipment'),
        IndustryPackProduct(category: 'Packaging', name: 'Corrugated Box', hsnCode: '48191010', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'chartered_accountant',
      label: 'Chartered Accountant',
      products: [
        IndustryPackProduct(category: 'Professional Service', name: 'Audit Fees', hsnCode: '998221', gstPercentage: 18, unit: 'Job'),
        IndustryPackProduct(category: 'Professional Service', name: 'GST Return Filing', hsnCode: '998213', gstPercentage: 18, unit: 'Month'),
        IndustryPackProduct(category: 'Professional Service', name: 'Income Tax Filing', hsnCode: '998212', gstPercentage: 18, unit: 'Job'),
      ],
    ),
    IndustryMasterPack(
      key: 'tax_consultant',
      label: 'Tax Consultant',
      products: [
        IndustryPackProduct(category: 'Tax Service', name: 'GST Advisory', hsnCode: '998213', gstPercentage: 18, unit: 'Job'),
        IndustryPackProduct(category: 'Tax Service', name: 'Tax Planning', hsnCode: '998212', gstPercentage: 18, unit: 'Job'),
        IndustryPackProduct(category: 'Tax Service', name: 'Compliance Review', hsnCode: '998213', gstPercentage: 18, unit: 'Job'),
      ],
    ),
    IndustryMasterPack(
      key: 'advocate',
      label: 'Advocate',
      products: [
        IndustryPackProduct(category: 'Legal Service', name: 'Consultation Fees', hsnCode: '998214', gstPercentage: 18, unit: 'Hour'),
        IndustryPackProduct(category: 'Legal Service', name: 'Case Drafting', hsnCode: '998214', gstPercentage: 18, unit: 'Job'),
        IndustryPackProduct(category: 'Legal Service', name: 'Court Appearance', hsnCode: '998214', gstPercentage: 18, unit: 'Visit'),
      ],
    ),
    IndustryMasterPack(
      key: 'service_business',
      label: 'Service Business',
      products: [
        IndustryPackProduct(category: 'Service', name: 'Installation Service', hsnCode: '998739', gstPercentage: 18, unit: 'Job'),
        IndustryPackProduct(category: 'Service', name: 'Repair Service', hsnCode: '998719', gstPercentage: 18, unit: 'Job'),
        IndustryPackProduct(category: 'Service', name: 'AMC Contract', hsnCode: '998599', gstPercentage: 18, unit: 'Year'),
      ],
    ),
    IndustryMasterPack(
      key: 'retail',
      label: 'Retail',
      products: [
        IndustryPackProduct(category: 'Retail Goods', name: 'Fast Moving Item A', hsnCode: '39249090', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Retail Goods', name: 'Fast Moving Item B', hsnCode: '96039000', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Retail Goods', name: 'Fast Moving Item C', hsnCode: '34011190', gstPercentage: 18, unit: 'Nos'),
      ],
    ),
    IndustryMasterPack(
      key: 'wholesale',
      label: 'Wholesale',
      products: [
        IndustryPackProduct(category: 'Wholesale Goods', name: 'Bulk Item A', hsnCode: '84798999', gstPercentage: 18, unit: 'Box'),
        IndustryPackProduct(category: 'Wholesale Goods', name: 'Bulk Item B', hsnCode: '39269099', gstPercentage: 18, unit: 'Carton'),
        IndustryPackProduct(category: 'Wholesale Goods', name: 'Bulk Item C', hsnCode: '85044090', gstPercentage: 18, unit: 'Carton'),
      ],
    ),
    IndustryMasterPack(
      key: 'distributor',
      label: 'Distributor',
      products: [
        IndustryPackProduct(category: 'Distribution', name: 'Primary SKU A', hsnCode: '21069099', gstPercentage: 12, unit: 'Box'),
        IndustryPackProduct(category: 'Distribution', name: 'Primary SKU B', hsnCode: '19053100', gstPercentage: 18, unit: 'Box'),
        IndustryPackProduct(category: 'Distribution', name: 'Primary SKU C', hsnCode: '33049990', gstPercentage: 18, unit: 'Carton'),
      ],
    ),
    IndustryMasterPack(
      key: 'ecommerce',
      label: 'E-commerce',
      products: [
        IndustryPackProduct(category: 'Online Goods', name: 'Marketplace SKU A', hsnCode: '61091000', gstPercentage: 5, unit: 'Nos'),
        IndustryPackProduct(category: 'Online Goods', name: 'Marketplace SKU B', hsnCode: '42021250', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'Packaging', name: 'Courier Polybag', hsnCode: '39232100', gstPercentage: 18, unit: 'Pack'),
      ],
    ),
    IndustryMasterPack(
      key: 'other',
      label: 'Other',
      products: [
        IndustryPackProduct(category: 'General', name: 'General Product 1', hsnCode: '84798999', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'General', name: 'General Product 2', hsnCode: '39269099', gstPercentage: 18, unit: 'Nos'),
        IndustryPackProduct(category: 'General Service', name: 'General Service 1', hsnCode: '998599', gstPercentage: 18, unit: 'Job'),
      ],
    ),
  ];

  static IndustryMasterPack? byKey(String key) {
    for (final pack in packs) {
      if (pack.key == key) {
        return pack;
      }
    }
    return null;
  }
}
