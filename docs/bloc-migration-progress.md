# Riverpod → flutter_bloc 移行進捗

## 完了済み

### Phase 0: セットアップ ✅
- pubspec.yaml: flutter_riverpod, hooks_riverpod, riverpod_annotation, riverpod_generator 削除
- pubspec.yaml: flutter_bloc, bloc_test 追加
- .g.dart ファイル3つ削除 (Riverpod codegen出力)

### Phase 1: BridgeService DI + Stream Cubits ✅
- `lib/providers/stream_cubit.dart` — 汎用 `StreamCubit<T>` 作成
- `lib/providers/bridge_cubits.dart` — typedef (ConnectionCubit, ActiveSessionsCubit, RecentSessionsCubit, GalleryCubit, FileListCubit, ProjectHistoryCubit)
- `lib/providers/server_discovery_cubit.dart` — ServerDiscoveryCubit 作成
- `lib/main.dart` — ProviderScope → RepositoryProvider<BridgeService> + MultiBlocProvider
- 削除: bridge_providers.dart, discovery_provider.dart

### Phase 2: DiffView移行 ✅
- `lib/features/diff/state/diff_view_cubit.dart` 作成
- `diff_screen.dart` — ConsumerWidget → StatelessWidget + BlocProvider + BlocBuilder
- 削除: diff_view_notifier.dart

### Phase 3: SessionList移行 ✅
- `lib/features/session_list/state/session_list_cubit.dart` 作成 (session_list_notifier.dart → Cubit化)
- `session_list_screen.dart` — ConsumerStatefulWidget → StatefulWidget + BlocListener + context.read/watch
- `main.dart` — SessionListCubitをMultiBlocProviderに追加
- `test/session_list_cubit_test.dart` — ProviderContainer → Cubit直接テストに書き換え (12テスト全合格)
- 削除: session_list_notifier.dart

### Phase 4: Chat移行 ✅
- `lib/features/chat/state/streaming_state_cubit.dart` 作成
- `lib/features/chat/state/chat_session_cubit.dart` 作成 (Family → 画面スコープMultiBlocProvider)
- `chat_screen.dart` — HookConsumerWidget → StatelessWidget (MultiBlocProvider) + _ChatScreenBody (HookWidget)
- `chat_message_list.dart` — ConsumerStatefulWidget → StatefulWidget + MultiBlocListener
- `chat_input_with_overlays.dart` — HookConsumerWidget → HookWidget
- `mock_preview_screen.dart` — ProviderScope → RepositoryProvider + MultiBlocProvider
- 削除: chat_session_notifier.dart

### Phase 5: Gallery + 残りWidget + エントリポイント ✅
- `gallery_screen.dart` — HookConsumerWidget → HookWidget (context.watch/read)
- `driver_main.dart` — ProviderScope → RepositoryProvider + MultiBlocProvider
- `marionette_main.dart` — 同上
- Riverpod importが lib/ 以下に残っていないことを確認 (文字列リテラル内のみ)

### Phase 6: テスト更新 ✅
- `test/providers/bridge_providers_test.dart` → `test/providers/bridge_cubits_test.dart` (StreamCubitテスト)
- `test/diff_view_notifier_test.dart` → `test/diff_view_cubit_test.dart` (DiffViewCubit直接テスト)
- `test/diff_screen_test.dart` — ProviderScope → RepositoryProvider<BridgeService>
- `test/gallery_screen_test.dart` — ProviderScope + bridgeServiceProvider → RepositoryProvider + BlocProvider
- `test/chat_session_notifier_test.dart` → `test/chat_session_cubit_test.dart` (ChatSessionCubit + StreamingStateCubit直接テスト)
- `test/widget_test.dart` — RepositoryProvider + MultiBlocProviderでラップ
- 削除: bridge_providers_test.dart, diff_view_notifier_test.dart, chat_session_notifier_test.dart

### Phase 7: 検証 ✅
- `dart analyze apps/mobile` — Riverpod関連のエラー/warning なし
- `dart format apps/mobile` — フォーマット済み
- `flutter test apps/mobile` — 全287テスト合格

## 設計方針 (参照用)

| 決定事項 | 方針 |
|---------|------|
| BridgeService DI | RepositoryProvider (flutter_bloc標準) |
| StreamProvider代替 | StreamCubit<T> (汎用) |
| Family (sessionId) | 画面スコープで MultiBlocProvider → AutoDisposeと同等 |
| ref.listen (副作用) | BlocListener ウィジェット |
| flutter_hooks | 維持 (HookConsumerWidget → HookWidget) |
| Freezed | 維持 (変更なし) |
| コード生成 | riverpod_generator削除済み。Freezedのみ残す |

## コミット履歴

1. `65d5acd` refactor(state): replace Riverpod with flutter_bloc infrastructure (Phase 0+1)
2. `5bd659e` refactor(diff): migrate DiffViewNotifier to DiffViewCubit (Phase 2)
3. `3c134ba` refactor(session_list): migrate SessionListNotifier to SessionListCubit (Phase 3)
4. `5b2e112` refactor(chat): migrate ChatSessionNotifier to ChatSessionCubit (Phase 4)
5. `ecc71f8` refactor(gallery): migrate gallery + entry points to flutter_bloc (Phase 5)
