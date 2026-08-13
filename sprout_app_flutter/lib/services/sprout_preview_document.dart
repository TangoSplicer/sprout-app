/// A small, safe view model for rendering supported SproutScript UI in preview.
///
/// The Rust compiler remains the source of truth for validation and compilation.
/// This parser mirrors its currently supported static UI surface so a preview
/// always reflects the document the user has authored or accepted from AI.
class SproutPreviewDocument {
  final String appName;
  final String screenName;
  final List<String> labels;
  final List<String> buttons;

  const SproutPreviewDocument({
    required this.appName,
    required this.screenName,
    required this.labels,
    required this.buttons,
  });

  factory SproutPreviewDocument.parse(String source) {
    final appMatch = RegExp(r'app\s+"([^"]+)"').firstMatch(source);
    final screenMatch = RegExp(r'screen\s+(\w+)').firstMatch(source);
    final labels = RegExp(r'label\s+"([^"]*)"')
        .allMatches(source)
        .map((match) => match.group(1)!.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    final buttons = RegExp(r'button\s+"([^"]+)"')
        .allMatches(source)
        .map((match) => match.group(1)!.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    return SproutPreviewDocument(
      appName: appMatch?.group(1) ?? 'Untitled Sprout App',
      screenName: screenMatch?.group(1) ?? 'Home',
      labels: labels,
      buttons: buttons,
    );
  }

  bool get hasVisibleContent => labels.isNotEmpty || buttons.isNotEmpty;
}
