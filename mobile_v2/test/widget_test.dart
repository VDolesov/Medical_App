import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_app_v2/theme/app_theme.dart';

void main() {
  testWidgets('светлая и тёмная темы собираются и применяются', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: Text('ok'))),
      ),
    );
    expect(find.text('ok'), findsOneWidget);

    final BuildContext context = tester.element(find.text('ok'));
    expect(Theme.of(context).useMaterial3, isTrue);
  });

  test('подписи уровней серьёзности локализованы', () {
    expect(AppTheme.severityLabel('CRITICAL'), 'Высокий');
    expect(AppTheme.severityLabel('WARNING'), 'Средний');
    expect(AppTheme.severityLabel('INFO'), 'Низкий');
  });
}
