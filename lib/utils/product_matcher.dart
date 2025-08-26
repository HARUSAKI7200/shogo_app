import 'package:flutter/foundation.dart';

class ProductMatcher {
  Map<String, dynamic> match(
    List<Map<String, String>> nifudaMapList,
    List<Map<String, String>> productMapList, {
    String pattern = 'T社（製番・項目番号）',
  }) {
    debugPrint('=== [ProductMatcher] 照合開始 (パターン: $pattern) ===');
    debugPrint('荷札: ${nifudaMapList.length}件, 製品リスト: ${productMapList.length}件');
    
    switch (pattern) {
      case 'T社（製番・項目番号）':
        return _matchForTCompany(nifudaMapList, productMapList);
      case '汎用（図書番号優先）':
        return _matchGeneralPurpose(nifudaMapList, productMapList);
      default:
        return _matchForTCompany(nifudaMapList, productMapList);
    }
  }

  Map<String, dynamic> _matchForTCompany(
    List<Map<String, String>> nifudaMapList,
    List<Map<String, String>> productMapList,
  ) {
    final matched = <Map<String, dynamic>>[];
    final unmatched = <Map<String, dynamic>>[];
    final Set<String> matchedProductKeys = {};

    for (final nifudaItem in nifudaMapList) {
      final nifudaSeiban = _normalize(nifudaItem['製番']);
      final nifudaItemNumber = _normalize(nifudaItem['項目番号']);

      final productGroup = productMapList
          .where((p) => _normalize(p['ORDER No.']) == nifudaSeiban)
          .toList();

      Map<String, String> potentialMatch = {};

      if (productGroup.isNotEmpty) {
        potentialMatch = productGroup.firstWhere(
          (p) => _normalize(p['ITEM OF SPARE']) == nifudaItemNumber,
          orElse: () => {},
        );
      }

      if (potentialMatch.isEmpty) {
        unmatched.add({
          ...nifudaItem,
          '照合ステータス': '製品未検出',
        });
        continue;
      }
      
      final String productKey = _normalize(potentialMatch['ORDER No.']) + '-' + _normalize(potentialMatch['ITEM OF SPARE']);
      matchedProductKeys.add(productKey);

      matched.add({
        ...nifudaItem,
        ...potentialMatch.map((k, v) => MapEntry('$k(製品)', v)),
        '照合ステータス': '一致',
      });
    }

    final missingProducts = productMapList.where((product) {
        final key = _normalize(product['ORDER No.']) + '-' + _normalize(product['ITEM OF SPARE']);
        return !matchedProductKeys.contains(key);
    }).map((p) => { ...p, '照合ステータス': '荷札未検出' }).toList();

    unmatched.addAll(missingProducts.cast<Map<String, dynamic>>());

    debugPrint('照合完了: 一致 ${matched.length}, 不一致/未検出 ${unmatched.length}');
    return {'matched': matched, 'unmatched': unmatched, 'missing': missingProducts};
  }

  Map<String, dynamic> _matchGeneralPurpose(
    List<Map<String, String>> nifudaMapList,
    List<Map<String, String>> productMapList,
  ) {
    final matched = <Map<String, dynamic>>[];
    final unmatched = <Map<String, dynamic>>[];
    final Set<String> matchedProductKeys = {};

    for (final nifudaItem in nifudaMapList) {
      final nifudaZusho = _normalize(nifudaItem['図書番号']);

      Map<String, String> potentialMatch = {};

      if (nifudaZusho.isNotEmpty) {
        potentialMatch = productMapList.firstWhere(
          (p) => _normalize(p['製品コード番号']) == nifudaZusho,
          orElse: () => {},
        );
      }

      if (potentialMatch.isEmpty) {
        unmatched.add({
          ...nifudaItem,
          '照合ステータス': '製品未検出',
        });
        continue;
      }

      final String productKey = _normalize(potentialMatch['ORDER No.']) + '-' + _normalize(potentialMatch['ITEM OF SPARE']);
      matchedProductKeys.add(productKey);
      
      matched.add({
        ...nifudaItem,
        ...potentialMatch.map((k, v) => MapEntry('$k(製品)', v)),
        '照合ステータス': '一致',
      });
    }

    final missingProducts = productMapList.where((product) {
        final key = _normalize(product['ORDER No.']) + '-' + _normalize(product['ITEM OF SPARE']);
        return !matchedProductKeys.contains(key);
    }).map((p) => { ...p, '照合ステータス': '荷札未検出' }).toList();

    unmatched.addAll(missingProducts.cast<Map<String, dynamic>>());
    return {'matched': matched, 'unmatched': unmatched, 'missing': missingProducts};
  }

  String _normalize(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[\s()]'), '').toUpperCase();
  }
}