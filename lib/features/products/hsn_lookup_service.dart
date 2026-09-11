import 'package:dio/dio.dart';

import 'package:chirag_accounting/features/products/product_catalog.dart';

class HsnLookupResult {
  final String hsnCode;
  final String description;
  final double gstPercentage;
  final String source;

  const HsnLookupResult({
    required this.hsnCode,
    required this.description,
    required this.gstPercentage,
    required this.source,
  });
}

class HsnLookupService {
  HsnLookupService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<HsnLookupResult?> lookup(String hsnCode) async {
    final normalized = hsnCode.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final liveResult = await _lookupGovernmentEndpoint(normalized);
    if (liveResult != null) {
      return liveResult;
    }

    final local = ProductCatalog.lookupByHsn(normalized);
    if (local == null) {
      return null;
    }

    return HsnLookupResult(
      hsnCode: local.hsnCode,
      description: local.description,
      gstPercentage: local.gstPercentage,
      source: 'local-catalog',
    );
  }

  Future<HsnLookupResult?> _lookupGovernmentEndpoint(String hsnCode) async {
    final endpoint = ProductCatalog.governmentLookupEndpoint;
    if (endpoint.isEmpty) {
      return null;
    }

    final apiKey = ProductCatalog.hsnLookupApiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    try {
      final normalizedEndpoint = endpoint.endsWith('/')
          ? endpoint.substring(0, endpoint.length - 1)
          : endpoint;

      final response = await _dio.get<dynamic>(
        '$normalizedEndpoint/$hsnCode',
        options: Options(
          headers: {
            'X-API-Key': apiKey,
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return null;
      }

      final data = _extractPayload(body);
      if (data == null) {
        return null;
      }

      final normalizedHsn =
          (data['hsnCode'] ?? data['hsn_code'] ?? data['hsn'] ?? hsnCode)
              .toString()
              .trim();
      final description =
          (data['description'] ??
                  data['itemDescription'] ??
                  data['item_description'] ??
                  data['name'] ??
                  '')
              .toString()
              .trim();
      final rawGst = data['gstPercentage'] ??
          data['gst_rate'] ??
          data['gstRate'] ??
          data['tax_rate'] ??
          data['taxRate'] ??
          data['rate'] ??
          data['igst'];
      final gst = rawGst is num
          ? rawGst.toDouble()
          : double.tryParse(rawGst?.toString() ?? '');
      final fallbackGst = ProductCatalog.gstForHsn(normalizedHsn) ??
          ProductCatalog.gstForHsn(hsnCode);
      final effectiveGst = gst ?? fallbackGst;

      if (description.isEmpty || effectiveGst == null) {
        return null;
      }

      return HsnLookupResult(
        hsnCode: normalizedHsn,
        description: description,
        gstPercentage: effectiveGst,
        source: 'government-endpoint',
      );
    } catch (_) {
      return null;
    }
  }

  /// Search by product name keyword. Tries the live API first, falls back to
  /// local catalog description matching.
  Future<List<HsnLookupResult>> searchByProductName(String keyword) async {
    final liveResults = await _searchByKeyword(keyword);
    if (liveResults.isNotEmpty) {
      return _rankByKeyword(keyword, liveResults);
    }
    return _rankByKeyword(
      keyword,
      ProductCatalog.searchByName(keyword)
        .map(
          (e) => HsnLookupResult(
            hsnCode: e.hsnCode,
            description: e.description,
            gstPercentage: e.gstPercentage,
            source: 'local-catalog',
          ),
        )
        .toList(),
    );
  }

  List<HsnLookupResult> _rankByKeyword(
    String keyword,
    List<HsnLookupResult> results,
  ) {
    final q = keyword.trim().toLowerCase();
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(growable: false);

    int score(HsnLookupResult result) {
      final description = result.description.toLowerCase();
      if (description == q) return 0;
      if (description.startsWith(q)) return 1;

      var matches = 0;
      for (final token in tokens) {
        if (description.contains(token)) {
          matches++;
        }
      }

      final tokenPenalty = tokens.isEmpty ? 1000 : (tokens.length - matches) * 100;
      final lengthPenalty = (description.length - q.length).abs();
      return 10 + tokenPenalty + lengthPenalty;
    }

    final ranked = [...results];
    ranked.sort((a, b) => score(a).compareTo(score(b)));
    return ranked;
  }

  Future<List<HsnLookupResult>> _searchByKeyword(String keyword) async {
    final endpoint = ProductCatalog.governmentLookupEndpoint;
    if (endpoint.isEmpty) return [];
    final apiKey = ProductCatalog.hsnLookupApiKey;
    if (apiKey.isEmpty) return [];

    try {
      final response = await _dio.get<dynamic>(
        endpoint,
        queryParameters: {'query': keyword},
        options: Options(
          headers: {
            'X-API-Key': apiKey,
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) return [];

      final raw = body['data'] ??
          body['result'] ??
          body['items'] ??
          body['results'] ??
          body['list'];
      if (raw is! List) return [];

      final results = <HsnLookupResult>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final hsnCode =
            (item['hsnCode'] ?? item['hsn_code'] ?? item['hsn'] ?? '')
                .toString()
                .trim();
        final description = (item['description'] ??
                item['itemDescription'] ??
                item['item_description'] ??
                item['name'] ??
                '')
            .toString()
            .trim();
        final rawGst = item['gstPercentage'] ??
            item['gst_rate'] ??
            item['gstRate'] ??
            item['igst'];
        final gst = rawGst is num
            ? rawGst.toDouble()
            : double.tryParse(rawGst?.toString() ?? '');
        final effectiveGst =
            gst ?? ProductCatalog.gstForHsn(hsnCode) ?? 18.0;
        if (hsnCode.isEmpty || description.isEmpty) continue;
        results.add(HsnLookupResult(
          hsnCode: hsnCode,
          description: description,
          gstPercentage: effectiveGst,
          source: 'government-endpoint',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _extractPayload(Map<String, dynamic> body) {
    final candidate = body['data'] ?? body['result'] ?? body['item'] ?? body;
    if (candidate is Map<String, dynamic>) {
      return candidate;
    }

    if (candidate is List && candidate.isNotEmpty) {
      final first = candidate.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }

    return null;
  }
}
