# GitHub Codespaces

## 1. 無料で使うための前提条件と確認事項

- アカウントの種類が個人であり、クレジットカードを登録していない想定です。この条件であれば上限を超過すると使えなくなるだけです。

### 1-1. アカウント種別の確認

GitHub には以下のアカウント種別があります。

- **個人アカウント (Personal Account)**
  - Free プラン → 無料枠あり（課金なしで利用可能）
  - Pro プラン → 無料枠あり、超過すると課金（クレカ登録が必要）
- **Organization アカウント**
  - Free プランでも、Codespaces は「請求先 Organization」として扱われるため、課金が発生する可能性あり
- **Enterprise アカウント**
  - 完全に請求が発生する契約ベース。無料利用は不可

→　**課金を避けたい場合は、必ず「個人アカウント」かつ「Free プラン」で利用する**

---

### 1-2. プランの確認方法

1. **GitHub の右上プロフィールアイコン**をクリックして **Settings** をクリックする

   ![github-my-icon](/assets/github-my-icon.png)

2. 左メニューの **Billing and licensing** をクリックして、**Licensing**をクリックして開く

   ![github-licensing](/assets/github-licensing.png)

3. **Current GitHub base plan**が以下になっていることを確認

   - `Github Free` であること（Pro / Team / Enterprise ではないこと）

4. 次に**Licensing**の下に**Payment information**があるのでクリックして、**Payment information** が **未登録（未入力）** であることを確認

**個人アカウント + Free プラン + クレカ未登録** → 無料枠を超えると「使えなくなるだけ」で課金なし。

### 1-3. 無料枠の内容（個人 Free プラン）

- **120 core-hours / 月**
  - 例：2 cores × 60 時間 = 無料枠いっぱい
- **15 GB-month のストレージ**
  - 不要な Codespace は削除して節約する

### 1-4. オートサスペンドの設定と意味

#### オートサスペンドとは

- 一定時間操作がなければ Codespace を自動で休止（suspend）状態にする機能
- suspend 中は **CPU 時間が消費されず課金対象外**
- 再開時は数十秒〜数分で復帰
- 「閉じ忘れで無料枠を消費し続ける事故」を防止できる

#### 設定方法

1. **GitHub の右上プロフィールアイコン** → **Settings → Codespaces → Default idle timeout**
2. 「Idle timeout」を設定（例：30 分 / 1 時間）
3. 個別 Codespace ごとに「… → Manage → Idle timeout」で調整も可能

## 2. 開始方法

面倒な環境構築は不要です。ブラウザさえあれば、すぐに学習を始められます。

1. Webブラウザで、このリポジトリの **[ <> Code ]** タブを開き、右上の緑色の **[ <> Code ]** ボタンをクリックします。
2. **[ Codespaces ]** タブを選択します。
3. **[ Create codespace on main ]** ボタンをクリックします。

## 3. 停止方法

1. `Code`タブに移動し、右上にある緑色の`code`のプルダウンメニューを開き、`Codespace`タブを開き、`Active`の右側にある三点リーダー（…）をクリックして`Delete`をクリックします。

   ![stop-code-space](/assets/stop-code-space.png)

1. 確認ダイアログが表示されるので`Delete`をクリックします。

   ![delete-code-space](/assets/delete-code-space.png)
