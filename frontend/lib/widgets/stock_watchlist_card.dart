import 'package:flutter/material.dart';

import '../models/market_snapshot_item.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class StockWatchlistCard extends StatelessWidget {
  const StockWatchlistCard({
    required this.items,
    this.onTap,
    this.isExpanded = false,
    super.key,
  });

  final List<MarketSnapshotItem> items;
  final VoidCallback? onTap;
  final bool isExpanded;

  String _formatPrice(double value) => '\$${value.toStringAsFixed(2)}';

  String _formatChangePercent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final int totalItems = items.length;
    final int displayCount = isExpanded ? totalItems : (totalItems > 3 ? 3 : totalItems);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header row
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.show_chart_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Your Watchlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '$totalItems stocks tracked',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Divider(color: Colors.white.withOpacity(0.12), height: 1),
        const SizedBox(height: 8),

        // Stock rows
        if (isExpanded)
          Expanded(
            child: ListView.separated(
              shrinkWrap: false,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: displayCount,
              separatorBuilder: (_, __) => Divider(
                height: 12,
                color: Colors.white.withOpacity(0.1),
              ),
              itemBuilder: _buildItem,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayCount,
            separatorBuilder: (_, __) => Divider(
              height: 12,
              color: Colors.white.withOpacity(0.1),
            ),
            itemBuilder: _buildItem,
          ),

        if (!isExpanded && totalItems > 3) ...[
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tap to view all',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        Center(
          child: Text(
            '* Market data as of last close',
            style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 10),
          ),
        ),
      ],
    );

    Widget card = Container(
      decoration: BoxDecoration(
        // Deep money-green gradient
        gradient: const LinearGradient(
          colors: [Color(0xFF004D2E), AnonaColors.moneyGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: isExpanded
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AnonaColors.moneyGreenGlow,
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: content,
    );

    if (onTap != null && !isExpanded) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }

  Widget _buildItem(BuildContext context, int index) {
    final item       = items[index];
    final isPositive = item.changePercent >= 0;
    final rowTitle   = item.shortName.isEmpty
        ? item.symbol
        : item.shortName;

    return Row(
      children: <Widget>[
        // Ticker chip
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.symbol,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rowTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
            ),
          ),
        ),
        // Price
        Text(
          _formatPrice(item.currentPrice),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        // Change pill
        _ChangePill(
          label: _formatChangePercent(item.changePercent),
          isPositive: isPositive,
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.label, required this.isPositive});
  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AnonaColors.gainGreen : AnonaColors.lossRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
