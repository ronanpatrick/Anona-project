import 'package:flutter/material.dart';

import '../models/market_snapshot_item.dart';
import '../screens/profile_screen.dart';

class StockWatchlistCard extends StatelessWidget {
  const StockWatchlistCard({
    required this.items,
    super.key,
  });

  final List<MarketSnapshotItem> items;

  String _formatPrice(double value) => '\$${value.toStringAsFixed(2)}';

  String _formatChangePercent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF136844),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Your Watchlist',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} stocks tracked',
                            style: TextStyle(
                              color: Colors.green.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final item = items[index];
              final isPositive = item.changePercent >= 0;
              final pillColor = isPositive ? const Color(0xFF23A563) : const Color(0xFFC44343);
              final arrowIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
              final rowTitle = item.shortName.isEmpty ? item.symbol : item.shortName;

              return Column(
                children: <Widget>[
                  if (index > 0)
                    Divider(
                      height: 14,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              rowTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.green.shade100,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: <Widget>[
                          Text(
                            _formatPrice(item.currentPrice),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pillColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(arrowIcon, color: Colors.white, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  _formatChangePercent(item.changePercent),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '*Stock data as of market close',
              style: TextStyle(
                color: Colors.green.shade100,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
