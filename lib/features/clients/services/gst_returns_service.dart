import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class GstModuleKpi {
  final String label;
  final String value;

  const GstModuleKpi({
    required this.label,
    required this.value,
  });
}

class GstModuleRecord {
  final String title;
  final String subtitle;
  final String? status;
  final String? amount;
  final String? dueDate;

  const GstModuleRecord({
    required this.title,
    required this.subtitle,
    this.status,
    this.amount,
    this.dueDate,
  });
}

class GstModuleApiResult {
  final String module;
  final String message;
  final List<GstModuleKpi> kpis;
  final List<GstModuleRecord> records;
  final DateTime fetchedAt;
  final String? errorMessage;

  const GstModuleApiResult({
    required this.module,
    required this.message,
    required this.kpis,
    required this.records,
    required this.fetchedAt,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}

class GstReturnsService {
  GstReturnsService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<GstModuleApiResult> fetchGstr1({
    required String gstin,
    required String clientId,
  }) {
    return _fetchModuleData(
      module: 'GSTR-1',
      endpoint: ApiConstants.gstGstr1,
      gstin: gstin,
      clientId: clientId,
    );
  }

  Future<GstModuleApiResult> fetchGstr3b({
    required String gstin,
    required String clientId,
  }) {
    return _fetchModuleData(
      module: 'GSTR-3B',
      endpoint: ApiConstants.gstGstr3b,
      gstin: gstin,
      clientId: clientId,
    );
  }

  Future<GstModuleApiResult> fetchGstr2bMatching({
    required String gstin,
    required String clientId,
  }) {
    return _fetchModuleData(
      module: 'GSTR-2B Matching',
      endpoint: ApiConstants.gstGstr2bMatching,
      gstin: gstin,
      clientId: clientId,
    );
  }

  Future<GstModuleApiResult> fetchReturnStatus({
    required String gstin,
    required String clientId,
  }) {
    return _fetchModuleData(
      module: 'Return Status',
      endpoint: ApiConstants.gstReturnStatus,
      gstin: gstin,
      clientId: clientId,
    );
  }

  Future<GstModuleApiResult> fetchAnalytics({
    required String gstin,
    required String clientId,
  }) {
    return _fetchModuleData(
      module: 'GST Analytics',
      endpoint: ApiConstants.gstAnalytics,
      gstin: gstin,
      clientId: clientId,
    );
  }

  Future<GstModuleApiResult> _fetchModuleData({
    required String module,
    required String endpoint,
    required String gstin,
    required String clientId,
  }) async {
    final normalizedGstin = gstin.trim().toUpperCase();

    if (normalizedGstin.isEmpty) {
      return GstModuleApiResult(
        module: module,
        message: 'Select GSTIN to load $module data.',
        kpis: const <GstModuleKpi>[],
        records: const <GstModuleRecord>[],
        fetchedAt: DateTime.now(),
        errorMessage: 'GSTIN is required.',
      );
    }

    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: {
          'gstin': normalizedGstin,
          'clientId': clientId,
        },
      );

      final body = response.data;
      final root = _normalizeRoot(body);
      final payload = _extractPayload(root);
      final kpis = _extractKpis(payload);
      final records = _extractRecords(payload);

      final message = _readString(root, const <String>[
            'message',
            'statusMessage',
            'detail',
          ]) ??
          _readString(payload, const <String>[
            'message',
            'statusMessage',
            'detail',
          ]) ??
          '$module data fetched successfully.';

      return GstModuleApiResult(
        module: module,
        message: message,
        kpis: kpis,
        records: records,
        fetchedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      final statusCode = e.response?.statusCode;

      final endpointHint = statusCode == 404
          ? ' Endpoint $endpoint was not found. Update endpoint path in ApiConstants.'
          : '';

      return GstModuleApiResult(
        module: module,
        message: 'Failed to fetch $module data.',
        kpis: const <GstModuleKpi>[],
        records: const <GstModuleRecord>[],
        fetchedAt: DateTime.now(),
        errorMessage: '${apiError.message}$endpointHint',
      );
    } catch (_) {
      return GstModuleApiResult(
        module: module,
        message: 'Failed to fetch $module data.',
        kpis: const <GstModuleKpi>[],
        records: const <GstModuleRecord>[],
        fetchedAt: DateTime.now(),
        errorMessage: 'Unexpected response for $module API.',
      );
    }
  }

  Map<String, dynamic> _normalizeRoot(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is List) {
      return <String, dynamic>{'data': body};
    }
    return <String, dynamic>{'value': body};
  }

  dynamic _extractPayload(Map<String, dynamic> body) {
    final candidates = <String>[
      'data',
      'result',
      'payload',
      'response',
      'items',
      'records',
      'returns',
      'analytics',
      'summary',
    ];

    for (final key in candidates) {
      if (body.containsKey(key)) {
        return body[key];
      }
    }

    return body;
  }

  List<GstModuleKpi> _extractKpis(dynamic payload) {
    final kpis = <GstModuleKpi>[];

    if (payload is Map<String, dynamic>) {
      final nestedKpis = payload['kpis'] ??
          payload['metrics'] ??
          payload['summary'] ??
          payload['totals'];

      if (nestedKpis is Map<String, dynamic>) {
        for (final entry in nestedKpis.entries) {
          final value = _formatValue(entry.value);
          if (value.isEmpty) continue;
          kpis.add(GstModuleKpi(label: _toTitle(entry.key), value: value));
        }
      }

      if (kpis.isEmpty) {
        for (final entry in payload.entries) {
          if (entry.value is Map || entry.value is List) continue;
          final value = _formatValue(entry.value);
          if (value.isEmpty) continue;
          kpis.add(GstModuleKpi(label: _toTitle(entry.key), value: value));
          if (kpis.length >= 8) break;
        }
      }
    }

    return kpis;
  }

  List<GstModuleRecord> _extractRecords(dynamic payload) {
    final records = <GstModuleRecord>[];

    List<dynamic> rows = const <dynamic>[];

    if (payload is List) {
      rows = payload;
    }

    if (payload is Map<String, dynamic>) {
      final listCandidate = payload['items'] ??
          payload['rows'] ??
          payload['records'] ??
          payload['returns'] ??
          payload['invoices'] ??
          payload['mismatches'] ??
          payload['list'];
      if (listCandidate is List) {
        rows = listCandidate;
      }
    }

    for (final raw in rows) {
      if (raw is! Map<String, dynamic>) continue;

      final title = _readString(raw, const <String>[
            'title',
            'name',
            'returnType',
            'invoiceNo',
            'period',
            'month',
          ]) ??
          'Record';

      final subtitle = _readString(raw, const <String>[
            'subtitle',
            'description',
            'partyName',
            'vendorName',
            'remarks',
          ]) ??
          '-';

      final status = _readString(raw, const <String>[
        'status',
        'filingStatus',
        'state',
      ]);

      final amountValue = raw['amount'] ??
          raw['taxAmount'] ??
          raw['total'] ??
          raw['taxLiability'] ??
          raw['itc'];

      final dueDate = _readString(raw, const <String>[
        'dueDate',
        'filingDueDate',
        'date',
      ]);

      final amount = _formatValue(amountValue);

      records.add(
        GstModuleRecord(
          title: title,
          subtitle: subtitle,
          status: status,
          amount: amount.isEmpty ? null : amount,
          dueDate: dueDate,
        ),
      );
    }

    return records;
  }

  String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        return value.toString();
      }
    }
    return null;
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2);
    }
    final text = value.toString().trim();
    return text;
  }

  String _toTitle(String key) {
    final normalized = key
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
        .trim();
    if (normalized.isEmpty) return key;

    final words = normalized.split(RegExp(r'\s+'));
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}
