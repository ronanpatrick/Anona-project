class MarketSnapshotItem {
  const MarketSnapshotItem({
    required this.symbol,
    required this.shortName,
    required this.currentPrice,
    required this.changePercent,
  });

  final String symbol;
  final String shortName;
  final double currentPrice;
  final double changePercent;

  factory MarketSnapshotItem.fromJson(Map<String, dynamic> json) {
    return MarketSnapshotItem(
      symbol: (json['symbol'] as String? ?? '').trim(),
      shortName: (json['short_name'] as String? ?? '').trim(),
      currentPrice: _toDouble(json['current_price']),
      changePercent: _toDouble(json['change_percent']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }
}
