import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/market_snapshot_item.dart';
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

  // Compute overall market sentiment
  int get _gainers => items.where((i) => i.changePercent >= 0).length;
  int get _losers  => items.where((i) => i.changePercent < 0).length;

  @override
  Widget build(BuildContext context) {
    final int totalItems   = items.length;
    final int displayCount = isExpanded ? totalItems : (totalItems > 3 ? 3 : totalItems);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Header ──────────────────────────────────────────────────────────
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
                  Text(
                    'Your Watchlist',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '$totalItems stocks tracked',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Market pulse badge
            if (items.isNotEmpty) _MarketPulseBadge(gainers: _gainers, losers: _losers),
          ],
        ),

        const SizedBox(height: 14),
        Divider(color: Colors.white.withOpacity(0.12), height: 1),
        const SizedBox(height: 10),

        // ── Stock rows ───────────────────────────────────────────────────────
        if (isExpanded)
          Expanded(
            child: ListView.separated(
              shrinkWrap: false,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: displayCount,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.white.withOpacity(0.08),
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
              height: 1,
              color: Colors.white.withOpacity(0.08),
            ),
            itemBuilder: _buildItem,
          ),

        const SizedBox(height: 14),

        // ── Market overview strip (only in preview mode) ─────────────────────
        if (!isExpanded && items.length > 1) ...[
          _MarketOverviewStrip(items: items),
          const SizedBox(height: 14),
        ],

        // ── Footer ────────────────────────────────────────────────────────────
        if (!isExpanded && totalItems > 3) ...[
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View all $totalItems stocks',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.7),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        Center(
          child: Text(
            '* Market data as of last close',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );

    Widget card = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003D24), Color(0xFF005C37), AnonaColors.moneyGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: isExpanded
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AnonaColors.moneyGreenGlow,
            blurRadius: 32,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
    final rowTitle   = item.shortName.isEmpty ? item.symbol : item.shortName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          // Ticker chip
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Text(
              item.symbol,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              rowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Price
          Text(
            _formatPrice(item.currentPrice),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          // Change pill
          _ChangePill(
            label: _formatChangePercent(item.changePercent),
            isPositive: isPositive,
          ),
        ],
      ),
    );
  }
}

// ── Market Overview Strip ──────────────────────────────────────────────────────

class _MarketOverviewStrip extends StatelessWidget {
  const _MarketOverviewStrip({required this.items});
  final List<MarketSnapshotItem> items;

  @override
  Widget build(BuildContext context) {
    // Compute summary stats
    final gainers = items.where((i) => i.changePercent >= 0).length;
    final losers  = items.where((i) => i.changePercent < 0).length;
    final total   = items.length;
    final gainerFraction = total > 0 ? gainers / total : 0.0;

    final avgChange = total > 0
        ? items.map((i) => i.changePercent).reduce((a, b) => a + b) / total
        : 0.0;
    final avgPositive = avgChange >= 0;
    final avgSign = avgPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MARKET PULSE',
                style: GoogleFonts.inter(
                  color: AnonaColors.moneyGreenLight.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '$avgSign${avgChange.toStringAsFixed(2)}% avg',
                style: GoogleFonts.inter(
                  color: avgPositive
                      ? AnonaColors.gainGreen
                      : AnonaColors.lossRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Gainer/loser bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(
                    flex: (gainerFraction * 100).round(),
                    child: Container(color: AnonaColors.gainGreen),
                  ),
                  Expanded(
                    flex: ((1 - gainerFraction) * 100).round().clamp(1, 100),
                    child: Container(color: AnonaColors.lossRed.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _DotLabel(color: AnonaColors.gainGreen, label: '$gainers up'),
              const SizedBox(width: 12),
              _DotLabel(color: AnonaColors.lossRed, label: '$losers down'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotLabel extends StatelessWidget {
  const _DotLabel({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Market Pulse Badge ─────────────────────────────────────────────────────────

class _MarketPulseBadge extends StatelessWidget {
  const _MarketPulseBadge({required this.gainers, required this.losers});
  final int gainers;
  final int losers;

  @override
  Widget build(BuildContext context) {
    final majority = gainers >= losers;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (majority ? AnonaColors.gainGreen : AnonaColors.lossRed)
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: (majority ? AnonaColors.gainGreen : AnonaColors.lossRed)
              .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            majority ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: majority ? AnonaColors.gainGreen : AnonaColors.lossRed,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            majority ? '$gainers / ${gainers + losers}' : '$losers / ${gainers + losers}',
            style: GoogleFonts.inter(
              color: majority ? AnonaColors.gainGreen : AnonaColors.lossRed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change Pill ────────────────────────────────────────────────────────────────

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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 9,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
