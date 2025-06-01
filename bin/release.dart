import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:path/path.dart" as path;
import "package:pubspec_parse/pubspec_parse.dart";
import "package:archive/archive.dart";

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print("PLATFORM must be specified: macos, windows, linux");
    exit(1);
  }

  final platform = args[0];

  if (!["macos", "windows", "linux"].contains(platform)) {
    print("PLATFORM must be specified: macos, windows, linux");
    exit(1);
  }

  final entryPoint = args.length > 1 ? args[1] : "lib/main.dart";

  final pubspec = File("pubspec.yaml").readAsStringSync();
  final parsed = Pubspec.parse(pubspec);

  final buildName =
      "${parsed.version?.major}.${parsed.version?.minor}.${parsed.version?.patch}";
  final buildNumber = parsed.version?.build.firstOrNull?.toString();

  final versionString = buildNumber != null && buildNumber.isNotEmpty
      ? "$buildName+$buildNumber"
      : buildName;

  final appNamePubspec = parsed.name;

  print(
    "Building version $versionString for $platform for app $appNamePubspec with entry point $entryPoint",
  );

  final flutterPath = Platform.environment["FLUTTER_ROOT"];
  if (flutterPath == null || flutterPath.isEmpty) {
    print("FLUTTER_ROOT environment variable is not set");
    exit(1);
  }

  print("Current working directory: ${Directory.current.path}");

  var flutterExecutable = "flutter";
  if (Platform.isWindows) {
    flutterExecutable += ".bat";
  }

  final flutterBinPath = path.join(flutterPath, "bin", flutterExecutable);
  if (!File(flutterBinPath).existsSync()) {
    print("Flutter executable not found at path: $flutterBinPath");
    exit(1);
  }

  final buildCommand = [
    flutterBinPath,
    "build",
    platform,
    "--target",
    entryPoint,
    "--dart-define",
    "FLUTTER_BUILD_NAME=$buildName",
    if (buildNumber != null && buildNumber.isNotEmpty)
      ...["--dart-define", "FLUTTER_BUILD_NUMBER=$buildNumber"],
  ];

  print("Executing build command: ${buildCommand.join(' ')}");

  final process =
  await Process.start(buildCommand.first, buildCommand.sublist(1));

  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln("Build failed with exit code $exitCode");
    exit(1);
  }

  print("Build completed successfully");

  late Directory buildDir;
  if (platform == "windows") {
    buildDir = Directory(
      path.join("build", "windows", "x64", "runner", "Release"),
    );
  } else if (platform == "macos") {
    buildDir = Directory(
      path.join(
        "build",
        "macos",
        "Build",
        "Products",
        "Release",
        "$appNamePubspec.app",
      ),
    );
  } else if (platform == "linux") {
    buildDir = Directory(
      path.join("build", "linux", "x64", "release", "bundle"),
    );
  }

  if (!buildDir.existsSync()) {
    print("Build directory not found: ${buildDir.path}");
    exit(1);
  }

  final distBase = path.join(
    "dist",
    "$appNamePubspec-$versionString-$platform",
  );
  final distPath = platform == "macos"
      ? path.join(distBase, "$appNamePubspec.app")
      : distBase;

  final distDir = Directory(distPath);
  if (distDir.existsSync()) {
    distDir.deleteSync(recursive: true);
  }

  await copyDirectory(buildDir, Directory(distPath));

  print("Copied to $distPath");

  // Zip the folder
  final zipFilePath = "$distBase.zip";
  await zipDirectory(Directory(distBase), zipFilePath);

  // Delete original unzipped directory
  Directory(distBase).deleteSync(recursive: true);

  print("Zipped archive created at $zipFilePath");
}

/// Copies directory contents recursively.
Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }

  await for (final entity in source.list(recursive: true)) {
    if (entity is File) {
      final relativePath = path.relative(entity.path, from: source.path);
      final newPath = path.join(destination.path, relativePath);
      await Directory(path.dirname(newPath)).create(recursive: true);
      await entity.copy(newPath);
    }
  }
}

/// Zips a directory using Dart's archive package.
Future<void> zipDirectory(Directory sourceDir, String outputZipPath) async {
  final archive = Archive();

  await for (final entity in sourceDir.list(recursive: true, followLinks: false)) {
    final relativePath = path.relative(entity.path, from: sourceDir.path);

    if (entity is File) {
      final data = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relativePath, data.length, data));
    } else if (entity is Directory) {
      archive.addFile(ArchiveFile('$relativePath/', 0, Uint8List(0)));
    }
  }

  final zipData = ZipEncoder().encode(archive);
  final zipFile = File(outputZipPath);
  await zipFile.create(recursive: true);
  await zipFile.writeAsBytes(zipData!);
}
