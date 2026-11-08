# 調査結果: Todo作成画面

## Markdownプレビュー

**Decision**: `flutter_markdown_plus`をMarkdownプレビュー用レンダラーとして採用する。

**Rationale**: 既存の`pubspec.yaml`にはMarkdownレンダラーがなく、仕様はMarkdown形式のプレビューを求める。標準Markdownを独自実装すると、コードブロック、リスト、リンク、エスケープなどの解釈と保守をアプリ側で担うことになる。`flutter_markdown_plus`はFlutter向けの継続メンテナンス版で、`MarkdownBody`や拡張用ビルダーを提供し、Androidで利用できる。実装時にFlutter 3.41.7 / Dart 3.11.5で`flutter pub get`と`flutter analyze`を行う。

**Alternatives considered**:

- `flutter_markdown`: pub.devでメンテナンス終了が告知されているため、新規依存には選ばない。
- `markdown_widget`: 機能は豊富だが、本機能に必要な範囲より依存が多い。目次や高度なコード強調が要件化された場合に再検討する。
- 自作の簡易レンダラー: 依存追加は避けられるが、標準Markdownの構文処理を独自に維持する必要があるため選ばない。

`[[タイトル]]`は標準Markdown構文ではない。作成画面の入力補完・保存ではWikiリンク文字列を保持し、プレビューではMarkdownレンダラーの標準表示を基本とする。リンクの解決・タップ動作は別機能の範囲である。

Sources:

- [flutter_markdown_plus on pub.dev](https://pub.dev/packages/flutter_markdown_plus)
- [flutter_markdown on pub.dev](https://pub.dev/packages/flutter_markdown)
- [markdown_widget on pub.dev](https://pub.dev/packages/markdown_widget)

## Android SAFによる新規Markdown作成

**Decision**: AndroidネイティブMethodChannelに、保存済みツリーフォルダー直下で新規Documentを作成して書き込む操作を追加する。保存URIに永続的な読取・書込権限があること、ルートが作成をサポートすることを確認し、直下の同名`.md`を事前に拒否してから新規作成する。SAF提供元が衝突時に別名を返す場合があるため、作成Documentの表示名を要求名と照合し、一致しない場合は今回作成したDocumentだけを削除して競合を返す。書込失敗や不一致Documentの後始末に失敗した場合も成功扱いせず、残存状態を明示する。

**Rationale**: 現行の`MainActivity`は保存URIの読取権限確認と`readFolder`のみを実装し、作成画面から直接`File`に書き込む境界がない。SAFのDocument URIに対する作成・書込をAndroid層に集約することで、選択されたツリー範囲を維持し、既存Markdownへ書き込まない方針を一箇所で検証できる。`FLAG_DIR_SUPPORTS_CREATE`と新規Documentの`FLAG_SUPPORTS_WRITE`を確認し、`DocumentsContract.createDocument`の戻り値を検証する。提供元による衝突回避の改名や後始末失敗を成功として隠さない。

**Alternatives considered**:

- Dart側でURIをパスへ変換して直接書く: SAF URIを通常ファイルパスとみなせず、アクセス境界も迂回するため採用しない。
- 既存ファイルを開いて上書き: 仕様とユーザーデータ保護原則に反するため採用しない。
- 新しいサーバーやDBを導入する: Markdownファイルを正本とする既存構成に不要なため採用しない。

**Integration constraint**: 現在の保存済みURIは読取権限のみを前提とする実装である。既存の保存先選択／設定境界は書込権限も永続化しなければならない。読取専用で保存されたURIから作成しようとした場合は、作成画面から既存のフォルダー選択フローを開いて再選択を案内する。新しい読取・書込権限の取得と永続化が成功した場合にのみ保存先URIを更新し、選択をキャンセルした場合は旧設定と作成画面の入力を保持する。作成機能は`com.android.externalstorage.documents`以外の提供元を新たに許可しない。

SAFの新規作成APIは、名前衝突時に既存ファイルを上書きせず、新しい名前を返す提供元がある。アプリ側の事前確認だけに依存せず、返却されたDocumentの名前と相対パスも検証する。要求名と異なるDocumentが作成されたときはその新規Documentのみを削除し、削除に失敗した場合は残存ファイルの相対パスを画面に示し、利用者に確認・手動削除を案内する。ストリームのopen/write/closeエラーでも同様に今回作成したファイルだけを後始末する。後始末にも失敗した場合は入力を保持し、作成成功として扱わない。

Sources:

- [Access documents and other files from shared storage](https://developer.android.com/training/data-storage/shared/documents-files)
- [DocumentsContract.createDocument](https://developer.android.com/reference/android/provider/DocumentsContract#createDocument(android.content.ContentResolver,android.net.Uri,java.lang.String,java.lang.String))
- [ContentResolver.openOutputStream](https://developer.android.com/reference/android/content/ContentResolver#openOutputStream(android.net.Uri,java.lang.String))
- [ContentResolver.takePersistableUriPermission](https://developer.android.com/reference/android/content/ContentResolver#takePersistableUriPermission(android.net.Uri,int))
- [Document provider capabilities](https://developer.android.com/guide/topics/providers/document-provider)

## 既存コードとの統合

**Decision**: Todo固有の画面・作成結果・候補データを`lib/features/todo/`に置き、既存の`TodoRepository`、`NoteId`、Markdownタグ解析、`AndroidFolderReader`を再利用する。UIから`File`やAndroid URIを直接扱わない。

**Rationale**: 憲法の機能単位構成・データアクセス境界と一致し、既存一覧画面の`onCreate`コールバックと一覧再読込を利用できる。候補用のタグは既存ノートの解析結果から構成し、ノート候補はMarkdownファイル名（拡張子除外）を表示する。

**Alternatives considered**:

- `main.dart`やWidgetに探索・保存ロジックを実装: 画面とSAF/Markdown詳細が結合するため採用しない。
- Todo作成専用の新しいストレージ方式を追加: 既存のSAF・Markdown境界と重複するため採用しない。
