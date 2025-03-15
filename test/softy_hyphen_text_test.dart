import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_hyphen_text/soft_hyphen_text.dart';

void main() {
  testWidgets('SoftHyphenText handles small containers correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              width: 40, // Very small width to force wrapping
              child: SoftHyphenText(
                text: 'Divided­ByHyphen', // Text with soft hyphen
              ),
            ),
          ),
        ),
      ),
    );

    // Verify that the text is rendered without a hyphen at the beginning
    final textFinder = find.byType(Text);
    expect(textFinder, findsOneWidget);

    final Text textWidget = tester.widget(textFinder);
    expect(textWidget.data, isNot(startsWith('-')));
  });

  testWidgets('SoftHyphenText only adds hyphens at soft hyphen positions', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              width: 100, // Width that will cause wrapping
              child: SoftHyphenText(
                text: 'This­is­a­test­with­soft­hyphens',
              ),
            ),
          ),
        ),
      ),
    );

    // Get the rendered text
    final textFinder = find.byType(Text);
    expect(textFinder, findsOneWidget);

    final Text textWidget = tester.widget(textFinder);
    final String renderedText = textWidget.data!;

    // Verify that hyphens only appear where soft hyphens were placed
    // 1. The text doesn't start with a hyphen
    expect(renderedText, isNot(startsWith('-')));

    // 2. If there are hyphens, they should be at the end of lines
    if (renderedText.contains('-')) {
      final lines = renderedText.split('\n');
      for (final line in lines) {
        if (line.contains('-')) {
          expect(line.endsWith('-'), isTrue, reason: 'Hyphen should only appear at the end of a line');
        }
      }
    }
  });

  testWidgets('SoftHyphenText properly handles controlled hyphenation', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              width: 80, // Width that will cause wrapping
              child: SoftHyphenText(
                text: 'Hyper­text­markup­language',
              ),
            ),
          ),
        ),
      ),
    );

    // Get the rendered text
    final textFinder = find.byType(Text);
    expect(textFinder, findsOneWidget);

    final Text textWidget = tester.widget(textFinder);
    final String renderedText = textWidget.data!;

    // The text should contain at least one hyphen
    expect(renderedText.contains('-'), isTrue);

    // Each line that ends with a hyphen should be followed by text on the next line
    final lines = renderedText.split('\n');
    for (int i = 0; i < lines.length - 1; i++) {
      if (lines[i].endsWith('-')) {
        expect(lines[i + 1].isNotEmpty, isTrue);
      }
    }
  });

  testWidgets('SoftHyphenText removes soft hyphens when no wrapping is needed', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              width: 300, // Wide enough to not need wrapping
              child: SoftHyphenText(
                text: 'Word­With­Hyphens',
              ),
            ),
          ),
        ),
      ),
    );

    // Verify that the text is rendered without any hyphens
    final textFinder = find.byType(Text);
    expect(textFinder, findsOneWidget);

    final Text textWidget = tester.widget(textFinder);
    expect(textWidget.data, equals('WordWithHyphens'));
  });
}
