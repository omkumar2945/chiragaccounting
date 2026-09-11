enum BusinessNature {
  retail,
  wholesale,
  manufacturing,
  service,
  trading,
  distributor,
  dealer,
  agent,
  commission,
  carryingAndForwarding,
  import,
  export,
  jobWork,
  contractor,
  ecommerce,
}

extension BusinessNatureLabel on BusinessNature {
  String get label => switch (this) {
    BusinessNature.retail => 'Retail',
    BusinessNature.wholesale => 'Wholesale',
    BusinessNature.manufacturing => 'Manufacturing',
    BusinessNature.service => 'Service',
    BusinessNature.trading => 'Trading',
    BusinessNature.distributor => 'Distributor',
    BusinessNature.dealer => 'Dealer',
    BusinessNature.agent => 'Agent',
    BusinessNature.commission => 'Commission',
    BusinessNature.carryingAndForwarding => 'C&F',
    BusinessNature.import => 'Import',
    BusinessNature.export => 'Export',
    BusinessNature.jobWork => 'Job Work',
    BusinessNature.contractor => 'Contractor',
    BusinessNature.ecommerce => 'E-commerce',
  };
}

class BusinessFieldDefinition {
  const BusinessFieldDefinition({
    required this.key,
    required this.label,
    this.required = false,
  });

  final String key;
  final String label;
  final bool required;
}

class TaxCodeSuggestion {
  const TaxCodeSuggestion({
    required this.category,
    required this.code,
    required this.gstRate,
    required this.description,
  });

  final String category;
  final String code;
  final double gstRate;
  final String description;
}

class BusinessTemplateDefinition {
  const BusinessTemplateDefinition({
    required this.key,
    required this.name,
    required this.category,
    required this.defaultNatures,
    required this.invoiceFields,
    required this.optionalDocuments,
    required this.taxSuggestions,
    this.stockTracking = true,
    this.defaultPrintFormat = 'A4 Tax Invoice',
  });

  final String key;
  final String name;
  final String category;
  final List<BusinessNature> defaultNatures;
  final List<String> invoiceFields;
  final List<String> optionalDocuments;
  final List<TaxCodeSuggestion> taxSuggestions;
  final bool stockTracking;
  final String defaultPrintFormat;
}

class BusinessTypeOption {
  const BusinessTypeOption({
    required this.name,
    required this.category,
    required this.templateKey,
  });

  final String name;
  final String category;
  final String templateKey;
}

class BusinessTemplateProfile {
  const BusinessTemplateProfile({
    required this.templateKeys,
    required this.businessTypes,
    required this.businessNatures,
    required this.enabledDocuments,
    required this.enabledFields,
    required this.updatedAt,
    this.customBusinessName = '',
    this.version = 1,
  });

  final List<String> templateKeys;
  final List<String> businessTypes;
  final List<BusinessNature> businessNatures;
  final List<String> enabledDocuments;
  final List<String> enabledFields;
  final String customBusinessName;
  final int version;
  final DateTime updatedAt;

  Map<String, Object> toJson() => <String, Object>{
    'templateKeys': templateKeys,
    'businessTypes': businessTypes,
    'businessNatures': businessNatures.map((value) => value.name).toList(),
    'enabledDocuments': enabledDocuments,
    'enabledFields': enabledFields,
    'customBusinessName': customBusinessName,
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BusinessTemplateProfile.fromJson(Map<String, dynamic> json) {
    final natureNames = (json['businessNatures'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    return BusinessTemplateProfile(
      templateKeys: (json['templateKeys'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      businessTypes: (json['businessTypes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      businessNatures: BusinessNature.values
          .where((value) => natureNames.contains(value.name))
          .toList(growable: false),
      enabledDocuments: (json['enabledDocuments'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      enabledFields: (json['enabledFields'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      customBusinessName: json['customBusinessName'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class BusinessTemplateCatalog {
  static const Map<String, List<String>> businessTypesByCategory =
      <String, List<String>>{
        'Retail': <String>[
          'General Store',
          'Supermarket',
          'Grocery',
          'Fancy Store',
          'Cosmetics',
          'Medical/Pharmacy',
          'Garments',
          'Footwear',
          'Textile',
          'Electronics',
          'Mobile',
          'Computer',
          'Furniture',
          'Home Appliances',
          'Stationery',
          'Books',
          'Toys',
          'Sports',
          'Gift',
          'Bakery',
          'Sweet Shop',
          'Restaurant',
          'Cafe',
          'Hotel',
          'Food/Catering',
        ],
        'Trading/Wholesale': <String>[
          'Hardware',
          'Electrical',
          'Plumbing',
          'Sanitary',
          'Paint',
          'Plywood',
          'Timber',
          'Glass',
          'Aluminium',
          'Steel',
          'Iron',
          'Pipes',
          'Plastic',
          'PVC',
          'CPVC',
          'UPVC',
          'SS',
          'Railing',
          'Industrial Supply',
          'Tools',
          'Machinery',
          'Bearings',
          'Fasteners',
          'Welding',
          'Safety Equipment',
          'Packaging',
          'Chemicals',
          'Raw Materials',
        ],
        'Automobile': <String>[
          'Cars',
          'Bikes',
          'Commercial Vehicles',
          'Auto Parts',
          'Spare Parts',
          'Tyres',
          'Batteries',
          'Lubricants',
          'Accessories',
          'Garage/Workshop',
          'Automobile Dealer',
        ],
        'Specialized': <String>[
          'Jewellery',
          'Gold/Silver',
          'Optical',
          'Watches',
          'Leather',
          'Chemical',
          'Agricultural Products',
          'Seeds',
          'Fertilizers',
          'Construction Materials',
          'Tiles',
          'Marble',
          'Granite',
          'Sanitaryware',
          'Mattress/Foam',
          'Paper',
          'Printing',
          'Scrap',
          'Fuel/Petroleum',
        ],
        'Manufacturing': <String>[
          'General Manufacturing',
          'Engineering',
          'Fabrication',
          'Metal',
          'Plastic',
          'Chemical',
          'Textile',
          'Food',
          'Furniture',
          'Packaging',
          'Machinery',
          'Component Manufacturing',
          'Job Work',
        ],
        'Construction': <String>[
          'Contractor',
          'Civil Contractor',
          'Electrical Contractor',
          'Plumbing Contractor',
          'Interior Contractor',
          'Fabricator',
          'Builder',
          'Developer',
          'Project Contractor',
          'Material Supplier',
        ],
        'Services': <String>[
          'Consultancy',
          'CA/Accounting',
          'Legal',
          'IT',
          'Software',
          'Digital Marketing',
          'Advertising',
          'Repair & Maintenance',
          'Transport',
          'Logistics',
          'Courier',
          'Rental',
          'Education',
          'Training',
          'Travel',
          'Event Management',
          'Salon',
          'Beauty',
          'Cleaning',
          'Security',
          'Healthcare',
          'Professional Services',
          'Other Service Business',
        ],
        'Distribution': <String>[
          'Distributor',
          'Dealer',
          'Stockist',
          'Super Stockist',
          'Agent',
          'Commission Agent',
          'C&F',
          'Franchise',
          'Importer',
          'Exporter',
          'E-commerce',
          'Marketplace Seller',
        ],
        'Custom': <String>['Other / Custom Business'],
      };

  static List<BusinessTypeOption> get businessTypes {
    return <BusinessTypeOption>[
      for (final category in businessTypesByCategory.entries)
        for (final name in category.value)
          BusinessTypeOption(
            name: name,
            category: category.key,
            templateKey: _templateKeyFor(name, category.key),
          ),
    ];
  }

  static String _templateKeyFor(String name, String category) {
    final normalized = name.toLowerCase();
    if (normalized.contains('jewell') || normalized.contains('gold')) {
      return 'jewellery';
    }
    if (category == 'Automobile') {
      return 'automobile';
    }
    if (normalized.contains('textile') || normalized.contains('garment')) {
      return 'textile';
    }
    if (normalized.contains('restaurant') ||
        normalized.contains('cafe') ||
        normalized.contains('hotel') ||
        normalized.contains('food') ||
        normalized.contains('bakery') ||
        normalized.contains('sweet')) {
      return 'restaurant_food';
    }
    if (category == 'Manufacturing' || normalized == 'job work') {
      return 'manufacturing';
    }
    if (category == 'Construction' ||
        normalized.contains('contractor') ||
        normalized == 'builder' ||
        normalized == 'developer') {
      return 'contractor';
    }
    if (category == 'Services') {
      return 'professional_service';
    }
    if (category == 'Distribution') {
      if (normalized.contains('e-commerce') ||
          normalized.contains('marketplace')) {
        return 'ecommerce';
      }
      if (normalized.contains('agent') ||
          normalized.contains('commission') ||
          normalized == 'c&f') {
        return 'agency_commission';
      }
      return 'distribution';
    }
    if (category == 'Trading/Wholesale') {
      return 'hardware_industrial';
    }
    if (category == 'Custom') {
      return 'custom';
    }
    return 'general_retail';
  }

  static const List<String> standardVouchers = <String>[
    'F4 Contra',
    'F5 Payment',
    'F6 Receipt',
    'F7 Journal',
    'F8 Sales',
    'F9 Purchase',
    'Ctrl+F8 Credit Note',
    'Ctrl+F9 Debit Note',
    'Alt+F7 Stock Journal',
    'Alt+F8 Stock/Material Transfer',
  ];

  static const List<String> allDocuments = <String>[
    'Quotation',
    'Estimate',
    'Proforma Invoice',
    'Sales Order',
    'Purchase Order',
    'Delivery Challan',
    'Material Inward',
    'Material Outward',
    'Job Work Inward',
    'Job Work Outward',
    'Goods Receipt',
    'Goods Return',
    'Purchase Return',
    'Sales Return',
    'Production',
    'Consumption',
    'Service Order',
    'Work Order',
  ];

  static const List<BusinessFieldDefinition> itemMasterFields =
      <BusinessFieldDefinition>[
        BusinessFieldDefinition(
          key: 'name',
          label: 'Item / Service Name',
          required: true,
        ),
        BusinessFieldDefinition(
          key: 'hsnSac',
          label: 'HSN / SAC Code',
          required: true,
        ),
        BusinessFieldDefinition(
          key: 'gstRate',
          label: 'GST Rate',
          required: true,
        ),
        BusinessFieldDefinition(key: 'uom', label: 'UOM', required: true),
        BusinessFieldDefinition(key: 'purchaseRate', label: 'Purchase Rate'),
        BusinessFieldDefinition(key: 'salesRate', label: 'Sales Rate'),
        BusinessFieldDefinition(key: 'mrp', label: 'MRP'),
        BusinessFieldDefinition(key: 'discount', label: 'Discount'),
        BusinessFieldDefinition(
          key: 'taxTreatment',
          label: 'Tax Inclusive / Exclusive',
        ),
        BusinessFieldDefinition(key: 'batch', label: 'Batch / Lot'),
        BusinessFieldDefinition(key: 'serialNumber', label: 'Serial Number'),
        BusinessFieldDefinition(key: 'barcode', label: 'Barcode'),
        BusinessFieldDefinition(key: 'brand', label: 'Brand'),
        BusinessFieldDefinition(key: 'model', label: 'Model'),
        BusinessFieldDefinition(key: 'size', label: 'Size'),
        BusinessFieldDefinition(key: 'colour', label: 'Colour'),
        BusinessFieldDefinition(key: 'grade', label: 'Grade'),
        BusinessFieldDefinition(key: 'specification', label: 'Specification'),
        BusinessFieldDefinition(key: 'warranty', label: 'Warranty'),
        BusinessFieldDefinition(key: 'expiry', label: 'Expiry'),
        BusinessFieldDefinition(key: 'openingStock', label: 'Opening Stock'),
        BusinessFieldDefinition(key: 'warehouse', label: 'Warehouse / Godown'),
        BusinessFieldDefinition(
          key: 'alternativeUnits',
          label: 'Alternative Units',
        ),
        BusinessFieldDefinition(
          key: 'customAttributes',
          label: 'Custom Attributes',
        ),
      ];

  static const List<BusinessTemplateDefinition> templates =
      <BusinessTemplateDefinition>[
        BusinessTemplateDefinition(
          key: 'general_retail',
          name: 'General Retail & POS',
          category: 'Retail',
          defaultNatures: <BusinessNature>[BusinessNature.retail],
          invoiceFields: <String>[
            'Item',
            'Barcode',
            'Quantity',
            'MRP',
            'Discount',
            'Rate',
            'HSN',
            'GST',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Estimate',
            'Sales Order',
            'Delivery Challan',
            'Sales Return',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'General goods',
              code: '39269099',
              gstRate: 18,
              description: 'Other articles of plastics',
            ),
          ],
          defaultPrintFormat: 'Thermal / A4 Tax Invoice',
        ),
        BusinessTemplateDefinition(
          key: 'jewellery',
          name: 'Jewellery & Precious Metals',
          category: 'Specialized',
          defaultNatures: <BusinessNature>[
            BusinessNature.retail,
            BusinessNature.trading,
          ],
          invoiceFields: <String>[
            'Item',
            'Purity',
            'Gross Weight',
            'Stone Weight',
            'Net Weight',
            'Rate',
            'Making Charges',
            'Wastage',
            'HSN',
            'GST',
          ],
          optionalDocuments: <String>[
            'Estimate',
            'Sales Order',
            'Delivery Challan',
            'Purchase Return',
            'Sales Return',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Gold jewellery',
              code: '71131910',
              gstRate: 3,
              description: 'Articles of gold jewellery',
            ),
            TaxCodeSuggestion(
              category: 'Silver jewellery',
              code: '71131120',
              gstRate: 3,
              description: 'Articles of silver jewellery',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'automobile',
          name: 'Automobile & Spare Parts',
          category: 'Automobile',
          defaultNatures: <BusinessNature>[
            BusinessNature.retail,
            BusinessNature.dealer,
          ],
          invoiceFields: <String>[
            'Part No.',
            'Brand',
            'Model',
            'Vehicle Compatibility',
            'Serial Number',
            'Quantity',
            'Rate',
            'Warranty',
            'HSN',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Estimate',
            'Sales Order',
            'Purchase Order',
            'Delivery Challan',
            'Goods Return',
            'Service Order',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Vehicle parts',
              code: '87089900',
              gstRate: 28,
              description: 'Motor vehicle parts and accessories',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'textile',
          name: 'Textile & Garments',
          category: 'Retail',
          defaultNatures: <BusinessNature>[
            BusinessNature.retail,
            BusinessNature.wholesale,
          ],
          invoiceFields: <String>[
            'Item',
            'Design',
            'Colour',
            'Size',
            'Fabric',
            'Meter/Piece',
            'Quantity',
            'Rate',
            'HSN',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Sales Order',
            'Purchase Order',
            'Delivery Challan',
            'Job Work Inward',
            'Job Work Outward',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Cotton fabric',
              code: '52085290',
              gstRate: 5,
              description: 'Printed cotton woven fabric',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'hardware_industrial',
          name: 'Hardware & Industrial Supply',
          category: 'Trading/Wholesale',
          defaultNatures: <BusinessNature>[
            BusinessNature.trading,
            BusinessNature.wholesale,
          ],
          invoiceFields: <String>[
            'Item',
            'Brand',
            'Size',
            'Specification',
            'Unit',
            'Quantity',
            'Rate',
            'Discount',
            'HSN',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Sales Order',
            'Purchase Order',
            'Delivery Challan',
            'Material Inward',
            'Material Outward',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Fasteners',
              code: '73181500',
              gstRate: 18,
              description: 'Threaded screws and bolts',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'restaurant_food',
          name: 'Restaurant, Hotel & Food',
          category: 'Retail',
          defaultNatures: <BusinessNature>[
            BusinessNature.service,
            BusinessNature.retail,
          ],
          invoiceFields: <String>[
            'Menu Item',
            'Quantity',
            'Rate',
            'GST',
            'Table/Order No.',
            'Service Charge',
            'KOT Reference',
          ],
          optionalDocuments: <String>[
            'Estimate',
            'Purchase Order',
            'Goods Receipt',
            'Consumption',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Restaurant service',
              code: '996331',
              gstRate: 5,
              description: 'Restaurant and food serving services',
            ),
          ],
          defaultPrintFormat: 'Thermal KOT / Tax Invoice',
        ),
        BusinessTemplateDefinition(
          key: 'manufacturing',
          name: 'Manufacturing & Job Work',
          category: 'Manufacturing',
          defaultNatures: <BusinessNature>[
            BusinessNature.manufacturing,
            BusinessNature.jobWork,
          ],
          invoiceFields: <String>[
            'Raw Material',
            'Finished Goods',
            'BOM/Job',
            'Production Qty',
            'Wastage',
            'Batch',
            'Stock Movement',
            'HSN',
          ],
          optionalDocuments: <String>[
            'Purchase Order',
            'Material Inward',
            'Material Outward',
            'Job Work Inward',
            'Job Work Outward',
            'Production',
            'Consumption',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Job work service',
              code: '998873',
              gstRate: 18,
              description: 'Manufacturing services on physical inputs',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'professional_service',
          name: 'Professional & General Services',
          category: 'Services',
          defaultNatures: <BusinessNature>[BusinessNature.service],
          invoiceFields: <String>[
            'Service Description',
            'SAC',
            'Quantity/Hours',
            'Rate',
            'Professional Charges',
            'GST',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Estimate',
            'Proforma Invoice',
            'Service Order',
            'Work Order',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Professional service',
              code: '998399',
              gstRate: 18,
              description: 'Other professional and technical services',
            ),
            TaxCodeSuggestion(
              category: 'Accounting service',
              code: '998221',
              gstRate: 18,
              description: 'Financial auditing services',
            ),
          ],
          stockTracking: false,
        ),
        BusinessTemplateDefinition(
          key: 'contractor',
          name: 'Construction & Contractor',
          category: 'Construction',
          defaultNatures: <BusinessNature>[
            BusinessNature.contractor,
            BusinessNature.service,
          ],
          invoiceFields: <String>[
            'Work Description',
            'Measurement',
            'Quantity',
            'Rate',
            'Site/Project',
            'Retention',
            'Advance',
            'Deductions',
            'GST',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Estimate',
            'Purchase Order',
            'Delivery Challan',
            'Material Inward',
            'Material Outward',
            'Work Order',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Works contract',
              code: '9954',
              gstRate: 18,
              description: 'Construction and works contract services',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'distribution',
          name: 'Distribution & Channel Sales',
          category: 'Distribution',
          defaultNatures: <BusinessNature>[
            BusinessNature.distributor,
            BusinessNature.dealer,
          ],
          invoiceFields: <String>[
            'Item',
            'SKU',
            'Batch',
            'Expiry',
            'Scheme',
            'Quantity',
            'Free Qty',
            'Rate',
            'Discount',
            'HSN',
            'GST',
          ],
          optionalDocuments: <String>[
            'Sales Order',
            'Purchase Order',
            'Delivery Challan',
            'Goods Receipt',
            'Goods Return',
            'Purchase Return',
            'Sales Return',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'General distribution goods',
              code: '21069099',
              gstRate: 18,
              description: 'Other food preparations',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'ecommerce',
          name: 'E-commerce & Marketplace',
          category: 'Distribution',
          defaultNatures: <BusinessNature>[
            BusinessNature.ecommerce,
            BusinessNature.trading,
          ],
          invoiceFields: <String>[
            'Product',
            'SKU',
            'Barcode',
            'Quantity',
            'Rate',
            'Discount',
            'Shipping Charge',
            'Marketplace Order No.',
            'HSN',
            'GST',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Proforma Invoice',
            'Sales Order',
            'Purchase Order',
            'Delivery Challan',
            'Goods Return',
            'Sales Return',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Marketplace facilitation service',
              code: '998599',
              gstRate: 18,
              description: 'Other support services',
            ),
          ],
        ),
        BusinessTemplateDefinition(
          key: 'agency_commission',
          name: 'Agent, Commission & C&F',
          category: 'Distribution',
          defaultNatures: <BusinessNature>[
            BusinessNature.agent,
            BusinessNature.commission,
            BusinessNature.carryingAndForwarding,
          ],
          invoiceFields: <String>[
            'Party',
            'Item / Service',
            'Commission',
            'Commission Rate',
            'Quantity',
            'Rate',
            'SAC',
            'GST',
          ],
          optionalDocuments: <String>[
            'Quotation',
            'Proforma Invoice',
            'Sales Order',
            'Purchase Order',
            'Delivery Challan',
            'Service Order',
          ],
          taxSuggestions: <TaxCodeSuggestion>[
            TaxCodeSuggestion(
              category: 'Commission agent service',
              code: '996111',
              gstRate: 18,
              description: 'Services of commission agents',
            ),
          ],
          stockTracking: false,
        ),
        BusinessTemplateDefinition(
          key: 'custom',
          name: 'Other / Custom Business',
          category: 'Custom',
          defaultNatures: <BusinessNature>[BusinessNature.trading],
          invoiceFields: <String>[
            'Item / Service',
            'Description',
            'Quantity',
            'Unit',
            'Rate',
            'Discount',
            'HSN/SAC',
            'GST',
          ],
          optionalDocuments: allDocuments,
          taxSuggestions: <TaxCodeSuggestion>[],
        ),
      ];

  static BusinessTemplateDefinition? byKey(String key) {
    for (final template in templates) {
      if (template.key == key) return template;
    }
    return null;
  }

  static List<BusinessTemplateDefinition> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return templates;
    return templates
        .where((template) {
          return template.name.toLowerCase().contains(normalized) ||
              template.category.toLowerCase().contains(normalized) ||
              template.invoiceFields.any(
                (field) => field.toLowerCase().contains(normalized),
              );
        })
        .toList(growable: false);
  }
}
