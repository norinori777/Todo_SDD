# データモデル: Todo作成画面

## TodoDraft

作成画面で編集中の未保存Todo。

| Field | Type | Rule |
|---|---|---|
| `title` | String | 必須。空または空白のみ、`.`、`..`、`/`、`\`、U+0000〜U+001F、U+007Fは拒否する。Windows固有の禁止文字・予約名は一律拒否せず、提供元に委ねる。入力値を自動変更しない |
| `content` | String | 任意。Markdown本文を入力どおり保持する |

保存先は設定済みのSAFツリーフォルダー直下、保存名は`<title>.md`。タイトルは拡張子を除くファイル名およびTodo一覧の表示名となる。

## Todo (既存エンティティ)

既存の`Todo`は`Note`と解析済みタグを保持する。作成後の識別子は保存先からの相対パス`<title>.md`であり、本文は先頭の`#todo`タグによって一覧のTodoとして認識される。

### 作成時の本文ルール

- 本文の先頭に独立した`#todo`行を一つ置く。
- 入力本文がすでに先頭の独立行として`#todo`を持つ場合、重複を追加しない。
- それ以外はタグ行の後に入力本文を続ける。空本文でもタグ行だけのMarkdownを保存する。
- 入力本文を正規化・書き換えない。コードブロック開始前にもタグ行を置く。

## RegisteredTagCandidate

保存先とサブフォルダーにある既存Markdownから抽出した登録済みタグ候補。

| Field | Type | Rule |
|---|---|---|
| `tag` | String | タグ階層を含む完全な値（例: `仕事/企画`）。入力文字列を含む候補を表示する |

候補選択時は入力中のタグトークンを候補の完全な値で置き換える。一致候補がない状態でEnterを押した場合は入力値を新規タグとして本文に確定する。新規タグの別途登録処理は行わず、保存された本文から以後の候補として認識する。

## ExistingMarkdownCandidate

保存先とサブフォルダーにある既存`.md`ファイルへのWikiリンク候補。

| Field | Type | Rule |
|---|---|---|
| `noteId` | NoteId | 保存先からの相対パス。候補選択後のデータ識別に使う |
| `title` | String | 拡張子を除いたファイル名。候補UIにはタイトルのみ表示する |

同名タイトルのファイルは個別の候補データとして存在し得るが、UIにはタイトルだけを表示し、選択時は`[[<title>]]`を挿入する。候補がない状態のEnterではリンクを挿入しない。

## TodoCreateOutcome

作成Repositoryと画面間の型付き結果。

| Variant | Meaning | Screen behavior |
|---|---|---|
| Success | 新規Markdownの作成と書込に成功 | 画面を閉じ、一覧を再読込する |
| InvalidTitle | 空白、`.` / `..`、パス区切り、ASCII制御文字 | 入力を保持し、対象の文字と修正方法を示す |
| AlreadyExists | 保存先直下に同名Markdownが存在 | 既存ファイルを保持し、競合を示す |
| FolderUnavailable | 保存先未設定・利用不可 | 作成を行わず、必要な設定を案内する |
| PermissionDenied | 保存先の書込権限がない／期限切れ | 成功扱いせず、作成画面から既存のフォルダー選択フローを開く再選択操作を示す。再選択をキャンセルした場合は旧設定と入力値を保持し、新しい読取・書込権限の永続化に成功した場合のみ保存先設定を更新する |
| WriteFailure | 提供元による名前拒否、I/O・書込後処理で失敗 | 作成画面に留まり、入力を保持する。提供元の理由を示し、詳細がない場合は保存先による拒否と必要な確認事項を示す。後始末に失敗してDocumentが残る場合は相対パスを含め、利用者に確認・手動削除を案内する |

## Screen State Transitions

```text
Editing <--> Preview
Editing -- submit valid draft --> Saving
Saving -- Success --> Closed / Todo list reload
Saving -- any failure --> Editing with draft preserved and error shown
```

プレビュー表示中は本文を編集できない。入力／プレビュー切替、候補表示、候補選択ではタイトルと本文を保持する。
