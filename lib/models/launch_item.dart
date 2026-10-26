/// Something VidHub opens when a task fires: a link, a program or a file/folder.
enum LaunchKind { url, app, file }

class LaunchItem {
  const LaunchItem({required this.kind, required this.target, this.label});

  final LaunchKind kind;
  final String target;
  final String? label;

  static final RegExp _hostPort = RegExp(r'^[A-Za-z0-9.\-]+:\d+(?:[/?#].*)?$');
  static final RegExp _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]+:');
  static final RegExp _winPath = RegExp(r'^(?:[A-Za-z]:[\\/]|\\\\)');
  static final RegExp _domain = RegExp(r'^[^\s/\\]+\.[A-Za-z]{2,}(?:[/?#]\S*)?$');
  static const Set<String> _programExts = {'exe', 'lnk', 'bat', 'cmd', 'msi'};
  static const Set<String> _documentExts = {
    'txt', 'md', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', //
    'csv', 'png', 'jpg', 'jpeg', 'gif', 'zip', 'json', 'py', 'dart',
  };

  /// Works out what kind of target a pasted string is.
  ///
  /// `duolingo.com` -> https link, `vscode://file/C:/x` -> link,
  /// `C:\Tools\app.exe` -> program, `C:\Docs\notes.txt` -> file, `code` -> program.
  factory LaunchItem.guess(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'^"+|"+$'), '').trim();

    if (_hostPort.hasMatch(t)) {
      return LaunchItem(kind: LaunchKind.url, target: 'http://$t');
    }
    if (_scheme.hasMatch(t)) {
      return LaunchItem(kind: LaunchKind.url, target: t);
    }
    if (_winPath.hasMatch(t) || t.startsWith('%')) {
      return LaunchItem(
        kind: _programExts.contains(_extension(t)) ? LaunchKind.app : LaunchKind.file,
        target: t,
      );
    }
    if (_domain.hasMatch(t)) {
      final ext = _extension(t);
      if (_programExts.contains(ext)) return LaunchItem(kind: LaunchKind.app, target: t);
      if (_documentExts.contains(ext)) return LaunchItem(kind: LaunchKind.file, target: t);
      return LaunchItem(kind: LaunchKind.url, target: 'https://$t');
    }
    return LaunchItem(kind: LaunchKind.app, target: t);
  }

  static String _extension(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Short name shown on chips.
  String get displayName {
    final custom = label?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    switch (kind) {
      case LaunchKind.url:
        final uri = Uri.tryParse(target);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
          return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
        }
        if (uri != null && uri.scheme.isNotEmpty) return uri.scheme;
        return target;
      case LaunchKind.app:
      case LaunchKind.file:
        final parts = target.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
        var name = parts.isEmpty ? target : parts.last;
        if (kind == LaunchKind.app) {
          name = name.replaceFirst(RegExp(r'\.(exe|lnk|bat|cmd)$', caseSensitive: false), '');
        }
        return name;
    }
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'target': target,
        if (label != null && label!.trim().isNotEmpty) 'label': label,
      };

  factory LaunchItem.fromJson(Map<String, dynamic> json) {
    return LaunchItem(
      kind: LaunchKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => LaunchKind.url,
      ),
      target: (json['target'] as String?) ?? '',
      label: json['label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LaunchItem && other.kind == kind && other.target == target && other.label == label;

  @override
  int get hashCode => Object.hash(kind, target, label);

  @override
  String toString() => 'LaunchItem(${kind.name}, $target)';
}
