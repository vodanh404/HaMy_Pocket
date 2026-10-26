class SherpaChineseVoiceService {
  SherpaChineseVoiceService._();

  static final instance = SherpaChineseVoiceService._();

  Future<bool> get isInstalled async => false;

  Future<void> downloadVoicePack() async {
    throw UnsupportedError('Sherpa ONNX voices are not supported on web.');
  }

  Future<void> speak(String text, {required int speaker}) async {
    throw UnsupportedError('Sherpa ONNX voices are not supported on web.');
  }
}
