import 'package:flutter_test/flutter_test.dart';
import 'package:vidhub/models/launch_item.dart';

void main() {
  group('LaunchItem.guess', () {
    test('web addresses', () {
      final a = LaunchItem.guess('duolingo.com');
      expect(a.kind, equals(LaunchKind.url));
      expect(a.target, equals('https://duolingo.com'));

      final b = LaunchItem.guess('https://www.duolingo.com/learn');
      expect(b.kind, equals(LaunchKind.url));
      expect(b.target, equals('https://www.duolingo.com/learn'));

      expect(LaunchItem.guess('www.example.org/path?q=1').target, equals('https://www.example.org/path?q=1'));
    });

    test('custom URI schemes are links', () {
      final a = LaunchItem.guess('vscode://file/C:/code/my-project');
      expect(a.kind, equals(LaunchKind.url));
      expect(a.target, equals('vscode://file/C:/code/my-project'));
      expect(LaunchItem.guess('mailto:me@example.com').kind, equals(LaunchKind.url));
      expect(LaunchItem.guess('spotify:track:123').kind, equals(LaunchKind.url));
    });

    test('host and port is a local dev server', () {
      expect(LaunchItem.guess('localhost:3000').target, equals('http://localhost:3000'));
      expect(LaunchItem.guess('127.0.0.1:8080/app').target, equals('http://127.0.0.1:8080/app'));
    });

    test('Windows paths', () {
      expect(LaunchItem.guess(r'C:\Program Files\Notes\notes.exe').kind, equals(LaunchKind.app));
      expect(LaunchItem.guess(r'C:\Users\me\Desktop\Study.lnk').kind, equals(LaunchKind.app));
      expect(LaunchItem.guess(r'C:\Users\me\Documents\plan.docx').kind, equals(LaunchKind.file));
      expect(LaunchItem.guess(r'D:\Projects').kind, equals(LaunchKind.file));
      expect(LaunchItem.guess(r'\\server\share\a.pdf').kind, equals(LaunchKind.file));
    });

    test('quoted paths are unquoted', () {
      final a = LaunchItem.guess('"C:\\Program Files\\App\\app.exe"');
      expect(a.target, equals(r'C:\Program Files\App\app.exe'));
    });

    test('plain names are programs', () {
      expect(LaunchItem.guess('code').kind, equals(LaunchKind.app));
      expect(LaunchItem.guess('notepad').kind, equals(LaunchKind.app));
    });

    test('file names that look like domains are not links', () {
      expect(LaunchItem.guess('notes.txt').kind, equals(LaunchKind.file));
      expect(LaunchItem.guess('setup.exe').kind, equals(LaunchKind.app));
    });
  });

  group('displayName', () {
    test('uses a custom label first', () {
      expect(const LaunchItem(kind: LaunchKind.url, target: 'https://x.com', label: 'My X').displayName, equals('My X'));
    });

    test('hosts, schemes and file names', () {
      expect(LaunchItem.guess('https://www.duolingo.com/learn').displayName, equals('duolingo.com'));
      expect(LaunchItem.guess('vscode://file/C:/x').displayName, equals('vscode'));
      expect(LaunchItem.guess(r'C:\Program Files\Notes\notes.exe').displayName, equals('notes'));
      expect(LaunchItem.guess(r'C:\Users\me\plan.docx').displayName, equals('plan.docx'));
      expect(LaunchItem.guess('code').displayName, equals('code'));
    });
  });

  test('JSON round trip', () {
    const item = LaunchItem(kind: LaunchKind.app, target: 'code', label: 'VS Code');
    expect(LaunchItem.fromJson(item.toJson()), equals(item));
  });
}
