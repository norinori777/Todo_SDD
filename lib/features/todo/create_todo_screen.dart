import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../settings/folder_access.dart';
import 'todo_create_repository.dart';

class CreateTodoScreen extends StatefulWidget {
  const CreateTodoScreen({
    required this.repository,
    this.onReselectFolder,
    super.key,
  });

  final TodoCreateRepository repository;
  final Future<void> Function()? onReselectFolder;

  @override
  State<CreateTodoScreen> createState() => _CreateTodoScreenState();
}

class _CreateTodoScreenState extends State<CreateTodoScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _saving = false;
  bool _selectingFolder = false;
  bool _previewMode = false;
  String? _errorMessage;
  String? _folderActionLabel;
  List<RegisteredTagCandidate> _tagCandidates = const [];
  List<RegisteredTagCandidate> _matchingTags = const [];
  List<ExistingMarkdownCandidate> _noteCandidates = const [];
  List<ExistingMarkdownCandidate> _matchingNotes = const [];
  _TagToken? _activeTag;
  _WikiToken? _activeWiki;
  String? _candidateIssue;
  String _lastBodyText = '';
  bool _suppressSuggestions = false;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_refreshSuggestions);
    _loadCandidates();
  }

  @override
  void dispose() {
    _contentController.removeListener(_refreshSuggestions);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    try {
      final candidates = await widget.repository.loadCandidates();
      if (!mounted) return;
      setState(() {
        _tagCandidates = candidates.tags;
        _noteCandidates = candidates.notes;
        _candidateIssue = candidates.issues.isEmpty
            ? null
            : candidates.issues.join('\n');
      });
      _refreshSuggestions();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _candidateIssue = error.message ?? 'タグ・ノート候補を読み込めませんでした。';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _candidateIssue = 'タグ・ノート候補を読み込めませんでした。\n$error';
      });
    }
  }

  void _refreshSuggestions() {
    if (!mounted) return;
    final text = _contentController.text;
    if (text != _lastBodyText) {
      _lastBodyText = text;
      _suppressSuggestions = false;
    }
    final selection = _contentController.selection;
    final cursor = selection.isValid ? selection.extentOffset : text.length;
    final tagToken = _suppressSuggestions ? null : _findTagToken(text, cursor);
    final wikiToken = _suppressSuggestions
        ? null
        : _findWikiToken(text, cursor);
    setState(() {
      _activeTag = tagToken;
      _activeWiki = wikiToken;
      _matchingTags = tagToken == null
          ? const []
          : _tagCandidates
                .where((candidate) => candidate.tag.contains(tagToken.query))
                .toList(growable: false);
      _matchingNotes = wikiToken == null
          ? const []
          : _noteCandidates
                .where((candidate) => candidate.title.contains(wikiToken.query))
                .toList(growable: false);
    });
  }

  void _insertTag(RegisteredTagCandidate candidate) {
    final token = _activeTag;
    if (token == null) return;
    final replacement = '#${candidate.tag}';
    final text = _contentController.text.replaceRange(
      token.start,
      token.end,
      replacement,
    );
    final cursor = token.start + replacement.length;
    _lastBodyText = text;
    _suppressSuggestions = true;
    _contentController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  void _insertNote(ExistingMarkdownCandidate candidate) {
    final token = _activeWiki;
    if (token == null) return;
    final replacement = '[[${candidate.title}]]';
    final text = _contentController.text.replaceRange(
      token.start,
      token.end,
      replacement,
    );
    final cursor = token.start + replacement.length;
    _lastBodyText = text;
    _suppressSuggestions = true;
    _contentController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
      _folderActionLabel = null;
    });
    late final TodoCreateOutcome outcome;
    try {
      outcome = await widget.repository.create(
        TodoDraft(
          title: _titleController.text,
          content: _contentController.text,
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = '保存処理中に問題が発生しました。再度お試しください。\n$error';
      });
      return;
    }
    if (!mounted) return;
    if (outcome is TodoCreateSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _errorMessage = _failureMessage(outcome);
      _folderActionLabel = switch (outcome) {
        TodoPermissionDenied() => '保存先を再選択',
        TodoFolderUnavailable(reason: FolderUnavailableReason.notConfigured) =>
          '保存先を選択',
        TodoFolderUnavailable() => '保存先を再選択',
        _ => null,
      };
    });
  }

  KeyEventResult _handleBodyKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }

    if (_activeTag != null && _matchingTags.isEmpty) {
      setState(() {
        _activeTag = null;
        _matchingTags = const [];
        _suppressSuggestions = true;
      });
      return KeyEventResult.handled;
    }
    if (_activeWiki != null && _matchingNotes.isEmpty) {
      setState(() {
        _activeWiki = null;
        _matchingNotes = const [];
        _suppressSuggestions = true;
      });
    }
    return KeyEventResult.ignored;
  }

  Widget _tagSuggestionList() {
    if (_matchingTags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('一致するタグはありません。Enterで入力中のタグを確定できます。'),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 160),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final candidate in _matchingTags)
            ListTile(
              dense: true,
              title: Text('#${candidate.tag}'),
              onTap: () => _insertTag(candidate),
            ),
        ],
      ),
    );
  }

  Widget _noteSuggestionList() {
    if (_matchingNotes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('一致するノートはありません。'),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 160),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final candidate in _matchingNotes)
            ListTile(
              dense: true,
              title: Text(candidate.title),
              onTap: () => _insertNote(candidate),
            ),
        ],
      ),
    );
  }

  Future<void> _reselectFolder() async {
    final reselect = widget.onReselectFolder;
    if (reselect == null || _selectingFolder) return;

    setState(() => _selectingFolder = true);
    try {
      await reselect();
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
        _folderActionLabel = null;
        _tagCandidates = const [];
        _matchingTags = const [];
        _noteCandidates = const [];
        _matchingNotes = const [];
        _activeTag = null;
        _activeWiki = null;
        _candidateIssue = null;
      });
      await _loadCandidates();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.code == 'selection_cancelled'
            ? '${error.message ?? 'フォルダー選択がキャンセルされました'}。保存先と入力内容は変更されていません。'
            : error.message ?? '保存先フォルダーを選択できませんでした。';
      });
    } finally {
      if (mounted) setState(() => _selectingFolder = false);
    }
  }

  String _failureMessage(TodoCreateOutcome outcome) => switch (outcome) {
    TodoInvalidTitle(:final message) => message,
    TodoAlreadyExists(:final fileName) =>
      '「$fileName」はすでに存在します。別のタイトルを入力してください。',
    TodoFolderUnavailable(reason: FolderUnavailableReason.notConfigured) =>
      '保存先フォルダーが設定されていません。フォルダーを選択してください。',
    TodoFolderUnavailable(:final message) =>
      message ?? '保存先にアクセスできません。フォルダーの状態を確認してください。',
    TodoPermissionDenied(:final message) => message,
    TodoWriteFailure(:final message, residualPath: final residualPath?) =>
      '$message\n不完全なファイル「$residualPath」が残っています。保存先で確認し、手動で削除してください。',
    TodoWriteFailure(:final message) => message,
    TodoCreateSuccess() => '',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Todoを作成')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('todo-title'),
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'タイトル'),
          ),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('内容（任意）')),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('入力')),
              ButtonSegment(value: true, label: Text('プレビュー')),
            ],
            selected: {_previewMode},
            onSelectionChanged: (selection) {
              setState(() => _previewMode = selection.single);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _previewMode
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: MarkdownBody(data: _contentController.text),
                    )
                  : Focus(
                      onKeyEvent: _handleBodyKey,
                      child: TextField(
                        key: const ValueKey('todo-content'),
                        controller: _contentController,
                        minLines: null,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
            ),
          ),
          if (!_previewMode && _candidateIssue != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'タグ・ノート候補を読み込めませんでした。\n$_candidateIssue',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (!_previewMode && _activeTag != null) _tagSuggestionList(),
          if (!_previewMode && _activeWiki != null) _noteSuggestionList(),
          const SizedBox(height: 16),
          if (_errorMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (_folderActionLabel != null && widget.onReselectFolder != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: _selectingFolder ? null : _reselectFolder,
                child: Text(
                  _selectingFolder ? 'フォルダー選択中...' : _folderActionLabel!,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? '作成中...' : '作成する'),
            ),
          ),
        ],
      ),
    ),
  );
}

_TagToken? _findTagToken(String text, int cursor) {
  final offset = cursor.clamp(0, text.length);
  if (offset == 0) return null;
  final start = text.lastIndexOf('#', offset - 1);
  if (start < 0 ||
      (start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])) ||
      _isEscaped(text, start) ||
      _isInsideMarkdownCode(text, start)) {
    return null;
  }
  var end = start + 1;
  while (end < text.length && !RegExp(r'\s').hasMatch(text[end])) {
    end++;
  }
  if (offset < start + 1 || offset > end) return null;
  return _TagToken(
    start: start,
    end: end,
    query: text.substring(start + 1, end),
  );
}

_WikiToken? _findWikiToken(String text, int cursor) {
  final offset = cursor.clamp(0, text.length);
  if (offset == 0) return null;
  final start = text.lastIndexOf('[[', offset - 1);
  if (start < 0 ||
      offset < start + 2 ||
      _isEscaped(text, start) ||
      _isInsideMarkdownCode(text, start)) {
    return null;
  }
  final lineEnd = text.indexOf('\n', start);
  final closing = text.indexOf(']]', start + 2);
  final hasClosing = closing >= 0 && (lineEnd < 0 || closing < lineEnd);
  final queryEnd = hasClosing
      ? closing
      : lineEnd < 0
      ? text.length
      : lineEnd;
  final tokenEnd = hasClosing ? closing + 2 : queryEnd;
  if (offset > tokenEnd) return null;
  return _WikiToken(
    start: start,
    end: tokenEnd,
    query: text.substring(start + 2, queryEnd),
  );
}

bool _isEscaped(String text, int offset) {
  var slashes = 0;
  for (var index = offset - 1; index >= 0 && text[index] == '\\'; index--) {
    slashes++;
  }
  return slashes.isOdd;
}

bool _isInsideMarkdownCode(String text, int offset) {
  final fencePattern = RegExp(r'^\s{0,3}(`{3,}|~{3,})');
  var fenceCharacter = '';
  var fenceLength = 0;
  var scanStart = 0;
  var codeDelimiterLength = 0;

  while (scanStart <= offset) {
    final scanEnd = text.indexOf('\n', scanStart);
    final end = scanEnd < 0 ? text.length : scanEnd;
    final line = text.substring(scanStart, end);
    final fence = fencePattern.firstMatch(line)?.group(1);
    if (fenceCharacter.isNotEmpty) {
      if (scanStart <= offset && offset <= end) return true;
      if (fence != null &&
          fence[0] == fenceCharacter &&
          fence.length >= fenceLength) {
        fenceCharacter = '';
        fenceLength = 0;
      }
    } else if (fence != null) {
      if (offset <= end) return true;
      fenceCharacter = fence[0];
      fenceLength = fence.length;
    } else {
      final scanLimit = offset < end ? offset : end;
      for (var index = scanStart; index < scanLimit;) {
        if (text[index] != '`' || _isEscaped(text, index)) {
          index++;
          continue;
        }
        final runStart = index;
        while (index < end && text[index] == '`') {
          index++;
        }
        final runLength = index - runStart;
        if (codeDelimiterLength == 0) {
          codeDelimiterLength = runLength;
        } else if (runLength == codeDelimiterLength) {
          codeDelimiterLength = 0;
        }
      }
      if (offset <= end) return codeDelimiterLength != 0;
    }
    if (scanEnd < 0) break;
    scanStart = scanEnd + 1;
  }
  return false;
}

class _TagToken {
  const _TagToken({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

class _WikiToken {
  const _WikiToken({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}
