import "package:desktop_updater/desktop_updater.dart";
import "package:flutter/material.dart";

class DesktopUpdaterController extends ChangeNotifier {
  DesktopUpdaterController({
    required Uri? appArchiveUrl,
    this.localization,
  }) {
    if (appArchiveUrl != null) {
      init(appArchiveUrl);
    }
  }

  DesktopUpdateLocalization? localization;
  DesktopUpdateLocalization? get getLocalization => localization;

  String? _appName;
  String? get appName => _appName;

  String? _appVersion;
  String? get appVersion => _appVersion;

  Uri? _appArchiveUrl;
  Uri? get appArchiveUrl => _appArchiveUrl;

  bool _needUpdate = false;
  bool get needUpdate => _needUpdate;

  bool _isMandatory = false;
  bool get isMandatory => _isMandatory;

  String? _zipUrl;

  UpdateProgress? _updateProgress;
  UpdateProgress? get updateProgress => _updateProgress;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  bool _isDownloaded = false;
  bool get isDownloaded => _isDownloaded;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  double _downloadSize = 0;
  double? get downloadSize => _downloadSize;

  double _downloadedSize = 0;
  double get downloadedSize => _downloadedSize;

  List<FileHashModel?>? _changedFiles;

  List<ChangeModel?>? _releaseNotes;
  List<ChangeModel?>? get releaseNotes => _releaseNotes;

  bool _skipUpdate = false;
  bool get skipUpdate => _skipUpdate;

  final _plugin = DesktopUpdater();

  void init(Uri url) {
    _appArchiveUrl = url;
    checkVersion();
    notifyListeners();
  }

  void makeSkipUpdate() {
    _skipUpdate = true;
    print("Skip update: $_skipUpdate");
    notifyListeners();
  }

  Future<void> checkVersion() async {
    if (_appArchiveUrl == null) {
      throw Exception("App archive URL is not set");
    }

    final versionResponse = await _plugin.versionCheck(
      appArchiveUrl: appArchiveUrl.toString(),
    );

    if (versionResponse?.url != null) {
      print("Found folder url: ${versionResponse?.url}");

      _needUpdate = true;
      _zipUrl = versionResponse?.url;
      _isMandatory = versionResponse?.mandatory ?? false;

      // Calculate total length in KB
      _downloadSize = (versionResponse?.changedFiles?.fold<double>(
            0,
            (previousValue, element) =>
                previousValue + ((element?.length ?? 0) / 1024.0),
          )) ??
          0.0;

      // Get changed files liste
      _changedFiles = versionResponse?.changedFiles;
      _releaseNotes = versionResponse?.changes;
      _appName = versionResponse?.appName;
      _appVersion = versionResponse?.version;

      print("Need update: $_needUpdate");

      notifyListeners();
    }
  }

  Future<void> downloadUpdate() async {
    if (_zipUrl == null) {
      throw Exception("ZIP URL is not set");
    }

    final stream = await _plugin.updateApp(
      remoteZipUrl: _zipUrl!,
    );

    stream.listen(
          (event) {
        _updateProgress = event;

        _isDownloading = true;
        _isDownloaded = false;
        _downloadSize = event.totalBytes;
        _downloadProgress = event.receivedBytes / event.totalBytes;
        _downloadedSize = event.receivedBytes;

        notifyListeners();
      },
      onDone: () {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _downloadedSize = _downloadSize;
        _isDownloaded = true;

        notifyListeners();
      },
      onError: (error) {
        _isDownloading = false;
        _isDownloaded = false;
        print("Download error: $error");

        notifyListeners();
      },
      cancelOnError: true,
    );
  }


  void restartApp() {
    _plugin.restartApp();
  }
}
