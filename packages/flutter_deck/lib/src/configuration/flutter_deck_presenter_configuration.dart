/// How the presenter view previews the current and the next slide.
enum FlutterDeckSlidePreviewMode {
  /// Static images of the slides, rendered offscreen at a reduced scale.
  image,

  /// The slides themselves, built live and scaled to fit the preview.
  ///
  /// The current slide follows the presentation step by step, with its
  /// animations, videos and other live content. The next slide shows its
  /// first step.
  live,
}

/// The configuration for the presenter view.
class FlutterDeckPresenterConfiguration {
  /// Creates a configuration for the presenter view.
  ///
  /// By default, slides are previewed as images.
  const FlutterDeckPresenterConfiguration({this.slidePreview = FlutterDeckSlidePreviewMode.image});

  /// How the current and the next slide are previewed.
  final FlutterDeckSlidePreviewMode slidePreview;
}
