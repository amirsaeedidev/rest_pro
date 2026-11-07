import 'package:flutter/material.dart';

import 'shimmer_skeleton.dart';

/// Reusable content placeholder for screens that load their first Supabase snapshot.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({
    super.key,
    this.cardCount = 4,
    this.headerHeight = 132,
    this.showHeader = true,
  });

  final int cardCount;
  final double headerHeight;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: ShimmerSkeleton(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              _placeholder(height: headerHeight, radius: 22),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(child: _placeholder(height: 74, radius: 16)),
                const SizedBox(width: 12),
                Expanded(child: _placeholder(height: 74, radius: 16)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(
              cardCount,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _placeholder(
                  height: index == 0 ? 112 : 84,
                  radius: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({required double height, required double radius}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
