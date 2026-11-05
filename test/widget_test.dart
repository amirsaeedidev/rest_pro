import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_project/shared/widgets/shimmer_skeleton.dart';

void main() {
  testWidgets('shimmer skeleton renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShimmerSkeleton(
            child: Center(child: Text('loading placeholder')),
          ),
        ),
      ),
    );

    expect(find.text('loading placeholder'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
