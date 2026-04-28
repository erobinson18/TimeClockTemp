class ValidateCodeResponse {
  final bool ok;
  final String rawMessage;

  const ValidateCodeResponse({
    required this.ok,
    required this.rawMessage,
});

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'rawMessage' : rawMessage,
  };

  factory ValidateCodeResponse.fromJson(Map<String, dynamic> json) {
    return ValidateCodeResponse(
      ok: (json['ok'] as bool?) ?? false,
      rawMessage: (json['rawMessage'] as String?) ?? '',
    );
  }
}