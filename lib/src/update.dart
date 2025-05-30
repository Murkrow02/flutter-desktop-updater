import "dart:async";
import "dart:io";
import "package:archive/archive_io.dart";
import "package:desktop_updater/desktop_updater.dart";

Future<Stream<UpdateProgress>> updateAppFunction({
  required String remoteZipUrl,
}) async {
  final executablePath = Platform.resolvedExecutable;
  var appDirectory = Directory(
    executablePath.substring(0, executablePath.lastIndexOf(Platform.pathSeparator)),
  );

  final responseStream = StreamController<UpdateProgress>();

  if (Platform.isMacOS) {
    appDirectory = appDirectory.parent;
  }

  try {
    final tempDir = await Directory.systemTemp.createTemp("app_update_");
    final zipFile = File("${tempDir.path}/update.zip");

    // Download the zip
    final request = await HttpClient().getUrl(Uri.parse(remoteZipUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException("Failed to download update zip.");
    }

    final totalBytes = response.contentLength.toDouble();
    double receivedBytes = 0;

    final sink = zipFile.openWrite();

    await for (var chunk in response) {
      receivedBytes += chunk.length;
      sink.add(chunk);
      responseStream.add(
        UpdateProgress(
          totalBytes: totalBytes / 1024.0, // KB
          receivedBytes: receivedBytes / 1024.0,
          currentFile: "update.zip",
          totalFiles: 1,
          completedFiles: 0,
        ),
      );
    }

    await sink.close();

    responseStream.add(UpdateProgress(
      totalBytes: totalBytes / 1024.0,
      receivedBytes: receivedBytes / 1024.0,
      currentFile: "update.zip",
      totalFiles: 1,
      completedFiles: 1,
    ));

    // Extract and overwrite existing files
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final outPath = "${appDirectory.path}${Platform.pathSeparator}${file.name}";

      if (file.isFile) {
        final output = File(outPath)..createSync(recursive: true);
        output.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    print("Update files extracted to: ${appDirectory.path}");

    // FIX: Don't await close
    responseStream.close();

    print("Update files extracted successfully.");
  } catch (e) {
    responseStream.addError(e);
    print("Error during update: $e");
    responseStream.close();
  }

  print("Update completed successfully.");

  return responseStream.stream;
}
