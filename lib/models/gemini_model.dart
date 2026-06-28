/// Enum representing the available Gemini API models.
///
/// Each variant maps to a human-readable display name and the
/// corresponding REST API model identifier string.
enum GeminiModelId {
  gemini35Flash(
    displayName: 'Gemini 3.5 Flash',
    apiId: 'gemini-3.5-flash',
  ),
  gemini31FlashLite(
    displayName: 'Gemini 3.1 Flash Lite',
    apiId: 'gemini-3.1-flash-lite',
  ),
  gemini3Flash(
    displayName: 'Gemini 3 Flash',
    apiId: 'gemini-3.0-flash',
  ),
  gemini25Flash(
    displayName: 'Gemini 2.5 Flash',
    apiId: 'gemini-2.5-flash',
  ),
  gemini25FlashLite(
    displayName: 'Gemini 2.5 Flash Lite',
    apiId: 'gemini-2.5-flash-lite',
  ),
  gemini2Flash(
    displayName: 'Gemini 2 Flash',
    apiId: 'gemini-2.0-flash',
  ),
  gemini2FlashLite(
    displayName: 'Gemini 2 Flash Lite',
    apiId: 'gemini-2.0-flash-lite',
  );

  const GeminiModelId({
    required this.displayName,
    required this.apiId,
  });

  /// Human-readable label shown in the UI dropdown.
  final String displayName;

  /// The model identifier used in the Gemini REST API URL.
  final String apiId;

  /// Resolves a [GeminiModelId] from its [apiId] string.
  /// Returns [GeminiModelId.gemini25Flash] if no match is found.
  static GeminiModelId fromApiId(String id) {
    return GeminiModelId.values.firstWhere(
      (model) => model.apiId == id,
      orElse: () => GeminiModelId.gemini25Flash,
    );
  }
}
