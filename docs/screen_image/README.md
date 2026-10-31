# 画面イメージ

要件をもとに作成したスマートフォン向けの画面イメージです。SVGファイルをブラウザーなどで開いて確認できます。画面内のデータは表示例です。

| 画面・状態 | イメージ | 主な操作 |
| --- | --- | --- |
| Todo一覧 | [01-todo-list.svg](./01-todo-list.svg) | タイトル・タグ検索、関連情報の展開、左スワイプで完了、タップで詳細、長押しで編集 |
| Todo作成・タグ候補 | [02-todo-create.svg](./02-todo-create.svg) | タイトル・Markdown本文の入力、タグ候補の絞り込み |
| Todo作成・プレビュー | [03-todo-preview.svg](./03-todo-preview.svg) | 入力内容のMarkdown表示、入力モードへの切り替え |
| 関連情報の作成 | [04-related-create.svg](./04-related-create.svg) | 既存Todoに紐づく情報の入力、Markdownリンク候補の絞り込み |
| Todo詳細 | [05-todo-detail.svg](./05-todo-detail.svg) | Markdown表示、関連情報へのリンク、戻る |
| Todo編集 | [06-todo-edit.svg](./06-todo-edit.svg) | タイトル・Markdown本文の編集 |
| 設定 | [07-settings.svg](./07-settings.svg) | Markdownを参照・保存するフォルダーの選択 |

## 補足

- 関連情報の作成は、既存Todoの詳細画面から開始する例です。関連元へのリンクは関連情報に自動で付与されます。
- 一覧での関連情報の展開方法や、編集画面のプレビュー切り替えなど、要件で操作方法が明示されていない箇所は画面イメージ上の提案です。
- 詳細画面のタグリンク押下後の動作は要件が途中で終わっているため、ここでは定義していません。
