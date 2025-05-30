import 'package:desktop_updater/desktop_updater.dart';
import "package:desktop_updater/updater_controller.dart";
import 'package:flutter/material.dart';
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = DesktopUpdaterInheritedNotifier.of(context)?.notifier;
    if (notifier == null) return const SizedBox();

    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // _Header(),
            // const SizedBox(height: 24),
            _UpdateTexts(notifier: notifier),
            const SizedBox(height: 24),
            _UpdateActions(notifier: notifier),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.update,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _UpdateTexts extends StatelessWidget {
  const _UpdateTexts({required this.notifier});
  final DesktopUpdaterController notifier;

  @override
  Widget build(BuildContext context) {
    final appName = notifier.appName;
    final appVersion = notifier.appVersion;
    final downloadSize = (notifier.downloadSize ?? 0) / 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notifier.getLocalization?.updateAvailableText ?? "Update Available",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 30
          ),
        ),
        Text(
          getLocalizedString(
            notifier.getLocalization?.newVersionAvailableText,
            [appName, appVersion],
          ) ??
              "$appName $appVersion is available",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          getLocalizedString(
            notifier.getLocalization?.newVersionLongText,
            [downloadSize.toStringAsFixed(2)],
          ) ??
              "New version is ready to download. This will download ${downloadSize.toStringAsFixed(2)} MB of data.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UpdateActions extends StatelessWidget {
  const _UpdateActions({required this.notifier});
  final DesktopUpdaterController notifier;

  @override
  Widget build(BuildContext context) {
    final isDownloading = notifier.isDownloading ?? false;
    final isDownloaded = notifier.isDownloaded ?? false;
    final isMandatory = notifier.isMandatory ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isDownloading && !isDownloaded)
          _DownloadingProgress(notifier: notifier)
        else if (!isDownloading && isDownloaded)
          _RestartButton(notifier: notifier)
        else
          Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: Text(notifier.getLocalization?.downloadText ?? "Download"),
                onPressed: notifier.downloadUpdate,
              ),
              const SizedBox(width: 8),
              if (!isMandatory)
                OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: Text(notifier.getLocalization?.skipThisVersionText ?? "Skip this version"),
                  onPressed: notifier.makeSkipUpdate,
                ),
            ],
          ),
        _ReleaseNotesButton(notifier: notifier),
      ],
    );
  }
}

class _DownloadingProgress extends StatelessWidget {
  const _DownloadingProgress({required this.notifier});
  final DesktopUpdaterController notifier;

  @override
  Widget build(BuildContext context) {
    final progress = notifier.downloadProgress ?? 0;
    final downloaded = (notifier.downloadedSize ?? 0) / 1024;
    final total = (notifier.downloadSize ?? 0) / 1024;

    return FilledButton.icon(
      icon: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(value: progress),
      ),
      label: Text("${(progress * 100).toInt()}% (${downloaded.toStringAsFixed(2)} MB / ${total.toStringAsFixed(2)} MB)"),
      onPressed: null,
    );
  }
}

class _RestartButton extends StatelessWidget {
  const _RestartButton({required this.notifier});
  final DesktopUpdaterController notifier;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: const Icon(Icons.restart_alt),
      label: Text(notifier.getLocalization?.restartText ?? "Restart to update"),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notifier.getLocalization?.warningTitleText ?? "Are you sure?"),
            content: Text(
              notifier.getLocalization?.restartWarningText ??
                  "Restart is required to complete the update. Unsaved changes may be lost. Restart now?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(notifier.getLocalization?.warningCancelText ?? "Not now"),
              ),
              TextButton(
                onPressed: notifier.restartApp,
                child: Text(notifier.getLocalization?.warningConfirmText ?? "Restart"),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReleaseNotesButton extends StatelessWidget {
  const _ReleaseNotesButton({required this.notifier});
  final DesktopUpdaterController notifier;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Release notes",
      icon: const Icon(Icons.description_outlined),
      onPressed: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => _ReleaseNotesBottomSheet(notifier: notifier),
      ),
    );
  }
}

class _ReleaseNotesBottomSheet extends StatelessWidget {
  const _ReleaseNotesBottomSheet({required this.notifier});
  final DesktopUpdaterController notifier;

  @override
  Widget build(BuildContext context) {
    final notes = notifier.releaseNotes
        ?.map((e) => "• ${e?.message}")
        .join("\n") ??
        "";

    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      snapSizes: const [0.6, 1.0],
      minChildSize: 0.6,
      initialChildSize: 0.6,
      builder: (_, controller) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            controller: controller,
            children: [
              Text(
                "Release notes",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                notes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
