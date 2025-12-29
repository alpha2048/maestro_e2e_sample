# E2E テスト手順書（Maestro）

本プロジェクトのE2Eテストは **Maestro** に一本化しています。

**動作確認状況**
- iPhone 17 Pro（iOS 26.1）で確認済み
- Pixel 9 Pro（API 36）で確認済み

## 🛠 前提条件と環境セットアップ

### 必須ツール
- **Flutter**: 3.35.7 (stable)
- **Maestro**: 2.0.10+
- **Simulators**: iOS Simulator / Android Emulator

### ビルドの準備
コードを変更した後は、以下のコマンドでテスト用ビルドを作成してください。

**iOS (Maestro用)**
```bash
flutter build ios --simulator --no-codesign -t lib/main.dart
```

**Android (共通)**
```bash
flutter build apk -t lib/main.dart
```

---

## 🎼 Maestro によるテスト

Maestroは、外部からアプリをブラックボックスとして操作するテストフレームワークです。YAMLでフローを記述します。

### 実行コマンド

### 一括実行（全フロー）
全フローを1コマンドで実行するため、`.maestro/config.yaml` に実行順と出力先を定義しています。
```bash
maestro --verbose --device <DEVICE_ID> \
  test maestro/ \
  --debug-output ./maestro-debug \
  --test-output-dir ./maestro-artifacts
```

### デバイスIDの取得
Maestro自体にデバイス一覧表示コマンドはないため、OS標準コマンドで取得します。

**iOS シミュレータ一覧**
```bash
xcrun simctl list devices
```

**Android エミュレータ/実機一覧**
```bash
adb devices
```

### 利用可能なフロー
- `maestro/joke_flow.yaml`: ジョークが表示され、「Get another joke」タップで更新されることを確認します。
  - *Note*: iOSで要素を特定するために `Semantics(identifier: 'joke-text')` を使用しています。
- `maestro/notification_flow.yaml`: 「Send Notification of Joke」で通知を出し、通知タップでアプリに戻ったことを確認します。
  - *Note*: 通知タップ後に `opened-notification-payload` が表示されることをアサートします。
  - *Note*: iOS / Android で通知の開き方が異なるため、`platform` で分岐しています。

---

## 🚨 トラブルシューティング

### 共通: テストが開始しない / フリーズする
シミュレータの状態が不安定な場合や、バックグラウンドプロセスが競合している場合に発生します。

1. **シミュレータの再起動**
   ```bash
   xcrun simctl shutdown all
   xcrun simctl boot <DEVICE_ID>
   ```
2. **デバッグ出力の確認**
   `--debug-output` / `--test-output-dir` に出力された `maestro.log` とスクリーンショットを確認します。
3. **原因不明でハングする場合の一例**
   Dockerの全コンテナを停止・削除して再起動すると改善するケースがあります。

### Maestro: "Element not found" エラー (iOS)
- **原因**: Flutterの `SelectableText` などが、iOSのAccessibility Treeに正しくマッピングされていない可能性があります。
- **対策**: 対象のWidgetを `Semantics(identifier: '...')` でラップし、明示的なIDを付与してください。
- **確認方法**: `maestro studio` を起動して、画面の階層構造を確認できます。

---

## ディレクトリ構造
- `maestro/`: Maestro用テストフロー (YAML)
