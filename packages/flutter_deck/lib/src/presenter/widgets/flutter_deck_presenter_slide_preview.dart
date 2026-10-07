import 'dart:typed_data';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_deck/src/configuration/configuration.dart';
import 'package:flutter_deck/src/flutter_deck.dart';
import 'package:flutter_deck/src/flutter_deck_router.dart';
import 'package:flutter_deck/src/renderers/renderers.dart';
import 'package:flutter_deck/src/theme/flutter_deck_theme.dart';

/// Renders the preview of the current and next slide.
///
/// This widget is used in the presenter view to display the current slide and
/// the next slide.
class FlutterDeckPresenterSlidePreview extends StatelessWidget {
  /// Creates a [FlutterDeckPresenterSlidePreview] widget.
  FlutterDeckPresenterSlidePreview({super.key}) : autoSizeGroup = AutoSizeGroup();

  /// The auto size group for the text widgets.
  final AutoSizeGroup autoSizeGroup;

  @override
  Widget build(BuildContext context) {
    final router = context.flutterDeck.router;

    return ListenableBuilder(
      listenable: router,
      builder: (context, child) {
        final FlutterDeckRouter(:currentSlideConfiguration, :currentSlideIndex, :currentStep) = router;
        final slideSteps = currentSlideConfiguration.steps;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _SlidePreview(
                  autoSizeGroup: autoSizeGroup,
                  index: currentSlideIndex,
                  step: currentStep,
                  steps: slideSteps,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: _SlidePreview(autoSizeGroup: autoSizeGroup, index: currentSlideIndex + 1, next: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlidePreview extends StatelessWidget {
  const _SlidePreview({required this.autoSizeGroup, required this.index, this.next = false, this.step, this.steps});

  final AutoSizeGroup autoSizeGroup;
  final int index;
  final bool next;
  final int? step;
  final int? steps;

  String _getHeader(int slideCount) {
    var slideInfo = 'Slide ${index + 1} of $slideCount';

    if (step != null && (steps ?? 1) > 1) {
      slideInfo += ' (step $step of $steps)';
    }

    return next ? 'Next: $slideInfo' : 'Current: $slideInfo';
  }

  @override
  Widget build(BuildContext context) {
    final flutterDeck = context.flutterDeck;
    final slideSize = flutterDeck.globalConfiguration.slideSize;
    final slides = flutterDeck.router.slides;
    final aspectRatio = slideSize.isResponsive ? 16 / 9 : slideSize.width! / slideSize.height!;
    final isLastSlide = index >= slides.length;

    return Column(
      children: [
        Text(isLastSlide ? '' : _getHeader(slides.length)),
        const SizedBox(height: 8),
        Expanded(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: isLastSlide
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _SlideTitle(
                        autoSizeGroup: autoSizeGroup,
                        color: Theme.of(context).colorScheme.onSurface,
                        title: 'End of presentation',
                      ),
                    ),
                  )
                : switch (flutterDeck.globalConfiguration.presenter.slidePreview) {
                    FlutterDeckSlidePreviewMode.image => _SlideContent(
                      flutterDeck: flutterDeck,
                      slide: slides[index],
                      step: step,
                      autoSizeGroup: autoSizeGroup,
                    ),
                    FlutterDeckSlidePreviewMode.live => _LiveSlideContent(
                      key: ValueKey(slides[index].route),
                      flutterDeck: flutterDeck,
                      slide: slides[index],
                      next: next,
                    ),
                  },
          ),
        ),
      ],
    );
  }
}

class _SlideContent extends StatefulWidget {
  const _SlideContent({
    required this.flutterDeck,
    required this.slide,
    required this.step,
    required this.autoSizeGroup,
  });

  final FlutterDeck flutterDeck;
  final FlutterDeckRouterSlide slide;
  final int? step;
  final AutoSizeGroup autoSizeGroup;

  @override
  State<_SlideContent> createState() => _SlideContentState();
}

class _SlideContentState extends State<_SlideContent> {
  late final FlutterDeckSlideImageRenderer _renderer;
  Future<Uint8List>? _imageFuture;

  @override
  void initState() {
    super.initState();

    _renderer = FlutterDeckSlideImageRenderer(flutterDeck: widget.flutterDeck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _renderSlide();
  }

  @override
  void didUpdateWidget(covariant _SlideContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.slide == oldWidget.slide && widget.step == oldWidget.step) return;

    _renderSlide();
  }

  void _renderSlide() => setState(() {
    _imageFuture = _renderer.render(
      context,
      widget.slide.widget,
      stepNumber: widget.step ?? 1,
      scale: 0.2,
      loadingDelay: const Duration(milliseconds: 300),
    );
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _SlidePreviewPlaceholder(slide: widget.slide, autoSizeGroup: widget.autoSizeGroup);
        }

        return Image.memory(snapshot.data!, fit: BoxFit.contain, gaplessPlayback: true);
      },
    );
  }
}

/// The slide itself, built live and scaled to fit the preview.
///
/// The current slide reads its step from the router, so it follows the
/// presentation step by step. The next slide stays on its first step.
class _LiveSlideContent extends StatelessWidget {
  const _LiveSlideContent({required this.flutterDeck, required this.slide, required this.next, super.key});

  final FlutterDeck flutterDeck;
  final FlutterDeckRouterSlide slide;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final slideSize = flutterDeck.globalConfiguration.slideSize;
    final width = MediaQuery.sizeOf(context).width;
    final logicalSize = slideSize.isResponsive
        ? Size(width, width * 9 / 16)
        : Size(slideSize.width!, slideSize.height!);
    final configuration = slide.configuration.copyWith(
      controls: const FlutterDeckControlsConfiguration.disabled(),
      showProgress: false,
    );

    return ExcludeFocus(
      child: IgnorePointer(
        child: ClipRect(
          child: FittedBox(
            child: SizedBox.fromSize(
              size: logicalSize,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: logicalSize),
                child: flutterDeck
                    .copyWith(configuration: configuration, stepNumber: next ? 1 : null)
                    .wrap(
                      context,
                      child: FlutterDeckTheme(data: FlutterDeckTheme.of(context), child: slide.widget),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidePreviewPlaceholder extends StatelessWidget {
  const _SlidePreviewPlaceholder({required this.slide, required this.autoSizeGroup});

  final FlutterDeckRouterSlide slide;
  final AutoSizeGroup autoSizeGroup;

  String _getSlideTitle(FlutterDeckRouterSlide slide) {
    final configuration = slide.configuration;
    final title = configuration.title;

    if (title != null) return title;

    final header = configuration.header;

    if (header.showHeader) return header.title;

    return configuration.route;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.secondary,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _SlideTitle(
          autoSizeGroup: autoSizeGroup,
          color: Theme.of(context).colorScheme.onSecondary,
          title: _getSlideTitle(slide),
        ),
      ),
    );
  }
}

class _SlideTitle extends StatelessWidget {
  const _SlideTitle({required this.autoSizeGroup, required this.color, required this.title});

  final AutoSizeGroup autoSizeGroup;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      title,
      group: autoSizeGroup,
      maxLines: 1,
      style: FlutterDeckTheme.of(context).textTheme.bodyLarge.copyWith(color: color, fontWeight: FontWeight.w500),
    );
  }
}
