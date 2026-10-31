---
name: flutter-apply-architecture-best-practices
description: 推奨されるレイヤードアプローチ（UI、ロジック、データ）を用いて Flutter アプリケーションを設計します。新しいプロジェクトを構成する場合や、拡張性を高めるためにリファクタリングする場合に使用します。
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Tue, 21 Apr 2026 20:11:20 GMT
---
# Flutter アプリケーションのアーキテクチャ設計

## 目次
- [アーキテクチャのレイヤー](#アーキテクチャのレイヤー)
- [プロジェクト構成](#プロジェクト構成)
- [ワークフロー: 新機能の実装](#ワークフロー-新機能の実装)
- [例](#例)

## アーキテクチャのレイヤー

アプリケーションを明確なレイヤーに分割し、関心の分離を徹底します。UI の描画とビジネスロジックやデータ取得を決して混在させないでください。

### UI レイヤー（プレゼンテーション）
UI の状態とロジックの管理には、MVVM（Model-View-ViewModel）パターンを実装します。
*   **ビュー:** 再利用可能で簡潔なウィジェットを作成します。ビュー内のロジックは、アニメーション、レイアウト制約、単純なルーティングなど UI 固有の処理に限定します。必要なデータはすべて ViewModel から渡します。
*   **ViewModel:** UI の状態を管理し、ユーザー操作を処理します。`ChangeNotifier` を継承する（または `Listenable` を使う）ことで状態を公開します。ビューには不変の状態スナップショットを公開します。コンストラクターを介して Repository を ViewModel に注入します。

### Data レイヤー
データアクセスロジックを分離し、信頼できる唯一の情報源を作るために Repository パターンを実装します。
*   **Service:** 必要な場合に限り、プラットフォームプラグインなど外部とのやり取りをラップするクラスを作成します。
*   **Repository:** データの読み書きとモデルの変換を担当し、Domain Model を ViewModel に公開します。Service、キャッシュ、同期、再試行は必要な場合にのみ追加します。

### ロジックレイヤー（Domain - 任意）
*   **ユースケース:** ViewModel が複雑なビジネスロジックで肥大化する場合、または複数の ViewModel 間でロジックを再利用する必要がある場合にのみ、このレイヤーを実装します。ロジックを専用の Use Case（インタラクター）クラスに切り出し、ViewModel と Repository の間に配置します。

## プロジェクト構成

コードを機能ごとにまとめ、その中で必要なレイヤーに分けます。Todo固有のRepository、モデル、画面などは `features/todo/` 内に置き、機能横断の処理だけを `core/` に置きます。詳細は [機能単位の構成ルール](../../../agents/rules/flutter-todo/architecture-vertical-slices.md) に従います。

```text
lib/
├── core/               # 機能横断の共通処理
└── features/
    ├── todo/
    │   ├── data/       # Todo固有のRepositoryなど
    │   ├── domain/     # Todo固有のモデルやルール
    │   └── presentation/
    └── settings/
        ├── data/
        ├── domain/
        └── presentation/
```

これは構成例であり、不要な層やファイルを作る必要はありません。

## ワークフロー: 新機能の実装

アプリケーションに新機能を追加するときは、次の順序でワークフローに従います。進捗を追跡するにはチェックリストをコピーしてください。

### 作業の進捗
- [ ] **ステップ 1: Domain Model を定義する。** 機能に必要な不変データクラスを作成します。コード生成は必要な場合にのみ導入します。
- [ ] **ステップ 2: Service を検討する。** 外部とのやり取りを分離する必要がある場合にのみ Service を作成または更新します。
- [ ] **ステップ 3: Repository を実装する。** 機能内にRepositoryを作成し、必要なデータアクセスとモデルの変換を担当させます。
- [ ] **ステップ 4: 条件付きロジック（Domain レイヤー）を適用する。**
  - *複雑なデータ変換または複数 Repository にまたがるロジックが必要な場合:* Use Case クラスを作成します。
  - *単純な CRUD 操作の場合:* ステップ 5 に進みます。
- [ ] **ステップ 5: ViewModel を実装する。** `ChangeNotifier` を継承する ViewModel を作成します。必要な Repository／Use Case を注入し、不変の状態とコマンドメソッドを公開します。
- [ ] **ステップ 6: ビューを実装する。** UI ウィジェットを作成します。`ListenableBuilder` または `AnimatedBuilder` を使って ViewModel の変更を監視します。
- [ ] **ステップ 7: 依存関係を注入する。** 必要な依存関係を渡します。依存性注入コンテナーは必要な場合にのみ導入します。
- [ ] **ステップ 8: バリデーターを実行する。** ViewModel と Repository の単体テストを実行します。
  - *フィードバックループ:* テストを実行 -> 失敗を確認 -> ロジックを修正 -> 成功するまで再実行します。

## 例

### Data レイヤー: Service と Repository

```dart
// 1. Service（生の API とのやり取り）
class ApiClient {
  Future<UserApiModel> fetchUser(String id) async {
    // HTTP GET の実装...
  }
}

// 2. Repository（信頼できる唯一の情報源。Domain Model を返す）
class UserRepository {
  UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;
  
  final ApiClient _apiClient;
  User? _cachedUser;

  Future<User> getUser(String id) async {
    if (_cachedUser != null) return _cachedUser!;
    
    final apiModel = await _apiClient.fetchUser(id);
    _cachedUser = User(id: apiModel.id, name: apiModel.fullName); // Domain Model に変換
    return _cachedUser!;
  }
}
```

### UI レイヤー: ViewModel とビュー

```dart
// 3. ViewModel（状態管理とプレゼンテーションロジック）
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required UserRepository userRepository}) 
      : _userRepository = userRepository;

  final UserRepository _userRepository;

  User? _user;
  User? get user => _user;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadProfile(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _userRepository.getUser(id);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// 4. ビュー（ロジックを持たない UI コンポーネント）
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final user = viewModel.user;
        if (user == null) {
          return const Center(child: Text('ユーザーが見つかりません'));
        }

        return Column(
          children: [
            Text(user.name),
            ElevatedButton(
              onPressed: () => viewModel.loadProfile(user.id),
              child: const Text('更新'),
            ),
          ],
        );
      },
    );
  }
}
```
