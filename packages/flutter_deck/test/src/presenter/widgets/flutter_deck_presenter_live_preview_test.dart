import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:flutter_deck_client/flutter_deck_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Presenter view with live slide previews', () {
    testWidgets('builds the real slides and follows the steps of the current one', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        FlutterDeckApp(
          client: _NoopClient(),
          isPresenterView: true,
          configuration: const FlutterDeckConfiguration(
            presenter: FlutterDeckPresenterConfiguration(slidePreview: FlutterDeckSlidePreviewMode.live),
          ),
          slides: [
            _StepsSlide(route: '/a', name: 'A', steps: 2),
            _StepsSlide(route: '/b', name: 'B', steps: 2),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A step 1'), findsOneWidget);
      expect(find.text('B step 1'), findsOneWidget);

      final router = tester.element(find.text('A step 1')).flutterDeck.router..next();
      await tester.pumpAndSettle();

      expect(find.text('A step 2'), findsOneWidget);
      expect(find.text('B step 1'), findsOneWidget, reason: 'the next slide stays on its first step');

      router.next();
      await tester.pumpAndSettle();

      expect(find.text('B step 1'), findsOneWidget);
      expect(find.textContaining('A step'), findsNothing);
      expect(find.text('End of presentation'), findsOneWidget);
    });
  });
}

class _StepsSlide extends FlutterDeckSlideWidget {
  _StepsSlide({required String route, required this.name, required int steps})
    : super(
        configuration: FlutterDeckSlideConfiguration(route: route, steps: steps),
      );

  final String name;

  @override
  Widget build(BuildContext context) => FlutterDeckSlide.blank(
    builder: (context) => FlutterDeckSlideStepsBuilder(builder: (context, step) => Text('$name step $step')),
  );
}

class _NoopClient implements FlutterDeckClient {
  final _states = StreamController<FlutterDeckState>.broadcast();

  @override
  void init([FlutterDeckState? state]) {}

  @override
  void dispose() {}

  @override
  void openPresenterView() {}

  @override
  void updateState(FlutterDeckState state) {}

  @override
  Stream<FlutterDeckState> get flutterDeckStateStream => _states.stream;
}
