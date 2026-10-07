import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// ShimmerBox is a basic block used to build skeleton layouts.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white, // Color does not matter much here, it serves as mask
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// StudentListSkeleton represents a loading list of students.
class StudentListSkeleton extends StatelessWidget {
  final int count;
  const StudentListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              ShimmerBox(width: 48, height: 48, borderRadius: 24),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: double.infinity, height: 16),
                    SizedBox(height: 8),
                    ShimmerBox(width: 100, height: 14),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// SeatGridSkeleton represents a loading grid of seats.
class SeatGridSkeleton extends StatelessWidget {
  final int count;
  const SeatGridSkeleton({super.key, this.count = 12});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return const ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 8);
      },
    );
  }
}

/// DashboardSkeleton represents a loading dashboard structure.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 150, height: 24),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 100)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 100)),
            ],
          ),
          const SizedBox(height: 24),
          const ShimmerBox(width: 200, height: 24),
          const SizedBox(height: 16),
          const StudentListSkeleton(count: 3),
        ],
      ),
    );
  }
}
