class HsnCatalogEntry {
  final String hsnCode;
  final String description;
  final double gstPercentage;

  const HsnCatalogEntry({
    required this.hsnCode,
    required this.description,
    required this.gstPercentage,
  });
}

class ProductCatalog {
  static const String governmentLookupEndpoint = String.fromEnvironment(
    'GST_HSN_LOOKUP_URL',
    defaultValue: 'https://api.taxlookup.fastgst.in/search/hsn',
  );

  static const String hsnLookupApiKey = String.fromEnvironment(
    'GST_HSN_LOOKUP_API_KEY',
    defaultValue: '',
  );

  static const List<String> units = [
    'Nos',
    'Pc',
    'Pcs',
    'Piece',
    'Unit',
    'Box',
    'Pack',
    'Set',
    'Pair',
    'Dozen',
    'Lot',
    'Job',
    'Kg',
    'Gram',
    'Ton',
    'Ltr',
    'Ml',
    'Mtr',
    'Meter Run',
    'Cm',
    'Mm',
    'Ft',
    'Feet Run',
    'Sq. Ft.',
    'Sq. Mtr.',
    'Cu. Ft.',
    'Cu. Mtr.',
    'Roll',
    'Sheet',
    'Panel',
    'Door',
    'Window',
    'Bag',
    'Bottle',
    'Jar',
    'Carton',
    'Bundle',
    'Tray',
    'Can',
  ];

  static const List<HsnCatalogEntry> hsnEntries = [
    HsnCatalogEntry(
      hsnCode: '70031210',
      description: 'Wired sheet glass',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70042011',
      description: 'Drawn or blown coloured glass sheet',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70071900',
      description: 'Toughened safety glass',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70072190',
      description: 'Laminated safety glass',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70080000',
      description: 'Multiple-walled insulating glass units',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70051010',
      description: 'Float glass sheet',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70052990',
      description: 'Other float glass',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '70169000',
      description: 'Glass paving blocks and slabs',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '76101000',
      description: 'Aluminium doors, windows and frames',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '76042100',
      description: 'Aluminium alloy bars, rods and profiles',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '76042990',
      description: 'Other aluminium profiles',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '83024110',
      description: 'Builders hardware fittings',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '83021010',
      description: 'Door and window hinges',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '83014090',
      description: 'Locks and locking hardware',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '39252000',
      description: 'Plastic builders ware',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '35061000',
      description: 'Prepared glues and adhesives',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '32081090',
      description: 'Paints and varnishes',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '39162090',
      description: 'Plastic strips and profiles',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '84713090',
      description: 'Portable computers',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '84716040',
      description: 'Computer input/output units',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '85044089',
      description: 'Chargers and power supplies',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '85444290',
      description: 'Insulated electric conductors',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '94038900',
      description: 'Other furniture and fixtures',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '73083000',
      description: 'Iron and steel doors, windows and frames',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '73181500',
      description: 'Screws and bolts of iron or steel',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '83025000',
      description: 'Hat-racks, brackets and similar fixtures',
      gstPercentage: 18,
    ),
    HsnCatalogEntry(
      hsnCode: '94054090',
      description: 'LED lights and electrical fittings',
      gstPercentage: 12,
    ),
  ];

  static HsnCatalogEntry? lookupByHsn(String hsnCode) {
    final normalized = hsnCode.trim();
    if (normalized.isEmpty) {
      return null;
    }

    for (final entry in hsnEntries) {
      if (entry.hsnCode == normalized) {
        return entry;
      }
    }

    // Allow chapter/partial search (for example, 7007).
    for (final entry in hsnEntries) {
      if (entry.hsnCode.startsWith(normalized)) {
        return entry;
      }
    }

    return null;
  }

  /// Search local catalog entries whose description contains [keyword].
  static List<HsnCatalogEntry> searchByName(String keyword) {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return [];
    final queryTokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(growable: false);

    int score(HsnCatalogEntry entry) {
      final description = entry.description.toLowerCase();
      if (description == q) return 0;
      if (description.startsWith(q)) return 1;

      var matchedTokens = 0;
      for (final token in queryTokens) {
        if (description.contains(token)) {
          matchedTokens++;
        }
      }

      final tokenScore = queryTokens.isEmpty
          ? 1000
          : (queryTokens.length - matchedTokens) * 100;
      final lengthPenalty = (description.length - q.length).abs();
      return 10 + tokenScore + lengthPenalty;
    }

    final results = hsnEntries
        .where((e) => e.description.toLowerCase().contains(q))
        .toList(growable: false);
    results.sort((a, b) => score(a).compareTo(score(b)));
    return results;
  }

  /// Search local catalog entries by HSN/SAC code prefix or exact code.
  static List<HsnCatalogEntry> searchByHsn(String hsnQuery) {
    final q = hsnQuery.trim();
    if (q.isEmpty) return [];
    return hsnEntries.where((e) => e.hsnCode.startsWith(q)).toList();
  }

  static double? gstForHsn(String hsnCode) {
    return lookupByHsn(hsnCode)?.gstPercentage;
  }
}
