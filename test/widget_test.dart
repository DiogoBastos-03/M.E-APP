import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:me_app/core/widgets/me_logo.dart';

void main() {
  testWidgets('MeLogo renderiza a imagem do logo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MeLogo(height: 32))),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
