import 'dart:io';
import 'dart:async';

void main() async {
  final scriptPath = Platform.script.toFilePath();
  final projectPath = findProjectRoot(scriptPath);

  if (projectPath == null) {
    print(
        'Unable to determine project root. Make sure to run the script from within the Flutter project.');
    exit(1);
  }

  await removePrints(projectPath);
}

String? findProjectRoot(String scriptPath) {
  final scriptFile = File(scriptPath);
  final scriptDirectory = scriptFile.parent;

  // Navigate up the directory structure until finding the pubspec.yaml file
  Directory currentDirectory = scriptDirectory;
  while (!File('${currentDirectory.path}/pubspec.yaml').existsSync()) {
    final parent = currentDirectory.parent;
    if (parent.path == currentDirectory.path) {
      // Reached the root directory without finding pubspec.yaml
      return null;
    }
    currentDirectory = parent;
  }

  return currentDirectory.path;
}

Future<void> removePrints(String directory) async {
  final directoryHandle = Directory(directory);
  await for (var entity in directoryHandle.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      await processFile(entity.path);
    }
  }
}

Future<void> processFile(String filePath) async {
  final file = File(filePath);
  final content = await file.readAsString();
  final newContent = content.replaceAll(RegExp(r'print\(.+?\);'), '');

  if (content != newContent) {
    await file.writeAsString(newContent);
  }
}