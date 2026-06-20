import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingCard extends StatelessWidget {
  final double height;
  const LoadingCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Card(
      child: Container(height: height),
    ),
  );
}

class LoadingList extends StatelessWidget {
  final int count;
  const LoadingList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: count,
    padding: const EdgeInsets.all(16),
    itemBuilder: (_, __) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LoadingCard(height: 80 + (__ % 3) * 20),
    ),
  );
}
