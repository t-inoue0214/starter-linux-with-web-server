# 第17章: cron でタスクを自動化する

## 前提知識

この章を始める前に、以下の章を完了していること:

- [第14章: OS ログを読む・書く](../chapter-14/README.md)（`/var/log/syslog` で cron の実行ログを確認する）
- [第15章: サービス管理](../chapter-15/README.md)（`service cron status / start`）
- [第16章: シェルスクリプトを書く](../chapter-16/README.md)（cron から呼び出すスクリプトを作る）

## 概要

chapter-16 でシェルスクリプトを「書けるようになった」。この章では、そのスクリプトを **「決まった時刻に自動実行する」** 仕組みを学ぶ。

`apt install nginx` を実行したとき、`/etc/cron.daily/logrotate` というファイルが自動で作られた。これが毎日 nginx のアクセスログを自動整理している。「一体どこで誰が動かしているのか」——その答えが cron だ。

chapter-18（logrotate）では `/etc/cron.daily/logrotate` の中身をさらに深く読み解く。この章はその橋渡しである。

## 手順

### 17-1. cron とは — スケジューラーデーモン

**cron** は「決められた日時・間隔でコマンドを自動実行するデーモン」（バックグラウンドで動き続けるプログラム）。Windows のタスクスケジューラーに相当する。

Codespaces では cron が起動していない場合がある。まず状態を確認する。

```bash
$ service cron status
```

出力例（停止中）:

```text
cron is not running ... failed!
```

停止中の場合は起動する。

```bash
$ sudo service cron start
```

出力例:

```text
Starting periodic command scheduler: cron.
```

起動後に再確認する。

```bash
$ service cron status
```

出力例:

```text
cron is running.
```

---

### 17-2. cron の書式を読む

cron の設定は 5 列の時刻指定とコマンドで構成される。

```text
# 分(0-59)  時(0-23)  日(1-31)  月(1-12)  曜日(0-7)  コマンド
  *          *          *          *          *          コマンド
```

| 書き方 | 意味 |
|:---|:---|
| `*` | すべて（毎分・毎時・毎日…） |
| `*/N` | N 単位（`*/5` は 5 分ごと） |
| `N` | 指定した値のみ（`0` は 0 分・0 時など） |
| `N,M` | 複数指定（`9,18` は 9 時と 18 時） |
| `N-M` | 範囲（`1-5` は月曜〜金曜） |

読み方の例:

```text
0  2  *  *  *  コマンド      # 毎日 02:00 に実行
*/5 *  *  *  *  コマンド     # 5 分ごとに実行
0  9  *  *  1   コマンド     # 毎週月曜 09:00 に実行
0  0  1  *  *  コマンド      # 毎月 1 日 0:00 に実行
0  9,18 * *  *  コマンド     # 毎日 09:00 と 18:00 に実行
```

> **曜日の 0 と 7:** どちらも日曜日を表す。歴史的に両方が使われてきたため、POSIX 標準で両方を日曜日として受け入れている。

---

### 17-3. crontab コマンドで登録・確認・削除

ユーザー crontab（自分専用のスケジュール）を操作するコマンド。

```bash
$ crontab -e    # crontab をエディタで開く（初回は EDITOR を選択）
$ crontab -l    # 現在の crontab を表示
$ crontab -r    # crontab をすべて削除（確認なし・取り消し不可）
```

> **`crontab -r` の危険性:** `-e`（編集）と `-r`（削除）は 1 文字違い。誤って入力すると確認なしで全エントリが消える。編集前に `crontab -l > ~/crontab.bak` でバックアップを取る習慣をつける。

#### テスト: 1 分ごとに日時を記録する

`crontab -e` を開いて以下を追記し、保存する。

```text
* * * * * date >> /tmp/cron-test.log 2>&1
```

1 分ほど待ってから確認する。

```bash
$ cat /tmp/cron-test.log
```

出力例:

```text
Sun Jun  1 10:01:01 UTC 2026
Sun Jun  1 10:02:01 UTC 2026
```

動作を確認したら `crontab -e` で該当行を削除しておく。

---

### 17-4. cron 実行時の環境変数問題

cron はログインシェルとは **別の最小環境** で実行される。`$PATH` は `/usr/bin:/bin` 程度しかなく、cron は bash ではなく `/bin/sh` でコマンドを実行する。

失敗例（コマンドが見つからない）:

```text
* * * * * nginx_manager.sh summary >> /tmp/cron.log 2>&1
```

出力（`/tmp/cron.log` で確認）:

```text
/bin/sh: 1: nginx_manager.sh: not found
```

`/bin/sh: 1:` の部分が「`/bin/sh` の 1 行目でエラーが発生した」ことを意味する。`service` コマンドも同様に `/usr/sbin/` 配下にあるため、フルパスなしでは見つからない。

**解決策1: フルパスで記述する**

```text
* * * * * /home/vscode/scripts/nginx_manager/nginx_manager.sh summary >> /tmp/cron.log 2>&1
```

**解決策2: crontab の先頭で `PATH` を設定する**

```text
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/vscode/scripts/nginx_manager

* * * * * nginx_manager.sh summary >> /tmp/cron.log 2>&1
```

> どちらの場合も `>> /tmp/cron.log 2>&1` でエラーを記録しておかないと、失敗しても原因がまったく分からなくなる（17-6 で詳述）。

---

### 17-5. 実行ユーザーと権限問題

`crontab -e` で登録したジョブは **登録したユーザー（vscode）** の権限で実行される。

#### sudo を含むスクリプトで起きる問題

chapter-16 の `nginx_manager.sh` は `sudo service nginx start` を呼んでいる。cron からこのスクリプトを実行すると、本番サーバーでは問題になることがある。

**なぜ問題になるか:** cron は TTY（端末: キーボード入力を受け取るターミナル画面のこと）を持たない。通常の `sudo` はパスワードを端末で入力させるため、TTY のない環境では待ち続けてジョブが止まる。

**確認方法（Codespaces では問題なし）:**

```bash
$ sudo -n service nginx status
```

`-n` は「パスワードを聞かない。聞く必要があるならエラーにする」オプション。出力が得られれば NOPASSWD 設定済みを意味する。

> **Codespaces では vscode ユーザーが NOPASSWD 設定済み**のため、cron からの `sudo` は問題なく動作する。ただし本番サーバーでは設定されていない場合がほとんどであり、次の解決策が必要になる。

#### 解決策1: `/etc/sudoers` に NOPASSWD を追加

```bash
$ sudo visudo    # 直接 /etc/sudoers を編集してはいけない
```

```text
# 追加する行（特定コマンドのみ許可）
vscode ALL=(ALL) NOPASSWD: /usr/sbin/service
```

#### 解決策2: root の crontab または `/etc/cron.d/` に登録する

```bash
$ sudo crontab -e    # root の crontab を編集
```

`/etc/cron.d/` に配置する形式は「5 列の時刻 + **ユーザー名** + コマンド」の 6 列構成。

```text
# /etc/cron.d/nginx-manager — root として実行するため sudo 不要
0 * * * * root /home/vscode/scripts/nginx_manager/nginx_manager.sh summary >> /tmp/cron-nginx.log 2>&1
```

> `/etc/cron.d/` の書式はユーザー crontab と異なり **ユーザー名列がある**。`crontab -e` の書式（5 列）と混同しないよう注意する。

---

### 17-6. ログの記録と確認

cron ジョブは **端末を持たない**。出力をどこかに記録しないと、動いたかどうか・エラーが出たかが一切分からない。

#### 方法1: ファイルへのリダイレクト

```text
# crontab エントリ
* * * * * /path/to/script.sh >> /tmp/cron.log 2>&1
```

- `>>` — ファイルに追記（`>` は毎回上書き）
- `2>&1` — 標準エラー出力も同じファイルに記録

確認:

```bash
$ cat /tmp/cron-test.log
$ tail -f /tmp/cron-test.log    # リアルタイムで追いかける（Ctrl+C で終了）
```

#### 方法2: `logger` で syslog に記録

chapter-14 で学んだ `logger` コマンドと、chapter-16 で `nginx_manager.sh` に実装した `log()` 関数が使える。cron から呼び出しても `/var/log/syslog` に記録が残る。

```bash
$ sudo grep "nginx-manager" /var/log/syslog | tail -10
```

| 方法 | 向いている状況 |
|:---|:---|
| `>> /tmp/cron.log 2>&1` | スクリプト単体のデバッグ・詳細な出力を確認したいとき |
| `logger` で syslog | 他のサービスログと一元管理したいとき・chapter-14 で学んだ知識を活かしたいとき |

---

### 17-7. syslog の cron エントリを読む

cron が実行されると `/var/log/syslog` に記録が残る。Codespaces では cron と同様に rsyslog（syslog への書き込みデーモン）が停止している場合があるため、先に起動する。

```bash
$ sudo rsyslogd     # 停止中の場合のみ実行
$ sudo grep CRON /var/log/syslog | tail -20
```

出力例（Codespaces の形式は ISO 8601 タイムスタンプ）:

```text
2026-06-01T14:42:01.661225+00:00 codespaces-bc9305 CRON[35843]: (vscode) CMD (date >> /tmp/cron-test.log 2>&1)
```

| フィールド | 意味 |
|:---|:---|
| `2026-06-01T14:42:01...` | 実行日時（ISO 8601 形式） |
| `(vscode) CMD (...)` | vscode ユーザーとして実行されたコマンドの記録 |

> **`No MTA installed, discarding output` について:** cron は既定でコマンドの出力をメール送信する設計だが、MTA（メール送信ソフト）がない環境では「破棄した」というメッセージが出る。`>> ファイル 2>&1` でリダイレクトしてコマンドの出力をすべてファイルに向けていれば、cron に渡す出力がなくなるためこのメッセージは表示されない。エラーではないが、表示される場合はリダイレクトが正しく設定されているか確認するとよい。

---

### 17-8. システム cron の構造

cron のスケジュール設定は複数の場所に分散している。

| 場所 | 書式 | 用途 |
|:---|:---|:---|
| `crontab -e` | `分 時 日 月 曜日 コマンド`（5 列） | ユーザー個別のスケジュール |
| `/etc/crontab` | `分 時 日 月 曜日 ユーザー名 コマンド`（6 列） | システム全体のスケジュール |
| `/etc/cron.d/` | `/etc/crontab` と同じ 6 列形式 | パッケージがインストールするサービス別設定 |
| `/etc/cron.daily/` | 実行可能スクリプトを置くだけ | 毎日 `run-parts` で一括実行 |
| `/etc/cron.hourly/` | 同上 | 毎時 `run-parts` で一括実行 |

`/etc/crontab` を確認する。

```bash
$ cat /etc/crontab
```

出力例（抜粋）:

```text
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 6    * * *   root    test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
```

`run-parts ディレクトリ名` は、指定ディレクトリ内の **実行可能ファイルをすべて順番に実行する** コマンド。`/etc/cron.daily/` にスクリプトを置くだけで「毎日実行」になるのはこの仕組みのおかげ。

`test -x /usr/sbin/anacron || { ... }` は「anacron（電源オフ中に実行できなかった定期ジョブを次回起動時に補完するツール）がインストールされていなければ `run-parts` を実行する」という条件式。Codespaces には anacron がないため、cron.daily の実行は `/etc/crontab` が直接担当する。

`/etc/cron.daily/` の中身を確認する。

```bash
$ ls /etc/cron.daily/
```

出力例:

```text
apt-compat  dpkg  exim4-base  logrotate  man-db
```

`logrotate` スクリプトが見える。これが毎日 nginx のログを処理している実体だ。

---

### 17-9. 総合実習 — nginx 定期監視と `/etc/cron.daily/logrotate` を読み解く

#### Step 1: `nginx_manager.sh summary` を毎時 0 分に実行する

`crontab -e` を開いて以下を追記し、保存する（フルパスは環境に合わせて調整）。

```text
0 * * * * /home/vscode/scripts/nginx_manager/nginx_manager.sh summary >> /tmp/cron-nginx-summary.log 2>&1
```

登録を確認する。

```bash
$ crontab -l
```

次の 0 分になったら実行される（それまでは `tail -f /tmp/cron-nginx-summary.log` で待つ）。

#### Step 2: `/etc/cron.daily/logrotate` を読み解く

```bash
$ cat /etc/cron.daily/logrotate
```

出力（Codespaces 環境）:

```bash
#!/bin/sh

# skip in favour of systemd timer
if [ -d /run/systemd/system ]; then
    exit 0
fi

# this cronjob persists removals (but not purges)
if [ ! -x /usr/sbin/logrotate ]; then
    exit 0
fi

/usr/sbin/logrotate /etc/logrotate.conf
EXITVALUE=$?
if [ $EXITVALUE != 0 ]; then
    /usr/bin/logger -t logrotate "ALERT exited abnormally with [$EXITVALUE]"
fi
exit $EXITVALUE
```

この章で学んだ知識を使って、一行ずつ読み解ける。

| コード | 使われている構文・知識 |
|:---|:---|
| `#!/bin/sh` | シバン行（chapter-16）。`bash` ではなく POSIX 最小シェル |
| `if [ -d /run/systemd/system ]; then exit 0; fi` | ディレクトリテスト演算子（chapter-16）。systemd が動いている環境では終了する |
| `if [ ! -x /usr/sbin/logrotate ]; then exit 0; fi` | 実行可能ファイルテスト演算子（chapter-16）。logrotate が存在しなければ終了する |
| `/usr/sbin/logrotate /etc/logrotate.conf` | logrotate の実行（chapter-18 で詳しく学ぶ） |
| `EXITVALUE=$?` | 終了コードの保存（chapter-16） |
| `/usr/bin/logger -t logrotate "..."` | syslog への記録（chapter-14） |
| スクリプトが `/etc/cron.daily/` に置かれている | `run-parts` によって毎日実行される（この章） |

> **Codespaces では `if [ -d /run/systemd/system ]` が偽になる:** Codespaces は systemd を PID 1 として起動しないため `/run/systemd/system` が存在しない。したがって `exit 0` には進まず、logrotate が正常に実行される。

---

## よくあるミス

| ミス | 症状 | 正しい対処 |
|:---|:---|:---|
| cron サービスが停止中 | 登録しても一切実行されない | `service cron status` で確認、停止中なら `sudo service cron start` |
| フルパスを使わない | `command not found`（ログにも残らない） | `/home/vscode/scripts/...` など絶対パスで記述する |
| `>> ファイル 2>&1` なし | エラーが握りつぶされ原因不明 | 必ずリダイレクトしてログを残す |
| `crontab -r` の誤打 | 全エントリが削除される（確認なし） | 事前に `crontab -l > ~/crontab.bak` でバックアップ |
| 書式の列数を間違える | cron が認識しない（保存時エラーになる場合もある） | ユーザー crontab は 5 列、`/etc/crontab` と `/etc/cron.d/` は 6 列 |
| sudo が TTY なしで止まる | ジョブが完了しない（本番環境で発生） | NOPASSWD 設定か root crontab での登録に切り替える |

---

## 類似比較

| 比較軸 | 説明 |
|:---|:---|
| `crontab -e` vs `/etc/crontab` | ユーザー個別 cron（5 列）vs システム全体 cron（6 列・ユーザー名列あり） |
| `/etc/cron.d/` vs `/etc/cron.daily/` | 時刻指定の 6 列形式ファイル vs `run-parts` が一括実行するスクリプト |
| `cron` vs `at` | 繰り返し実行（毎日・毎時など）vs 一度だけ指定時刻に実行 |
| `cron` vs `systemd timer` | SysVinit 時代からある仕組み vs systemd 環境の現代的な代替（Codespaces 非対応） |

---

## 他OSとの比較

| 操作 | Linux (cron) | Windows | macOS |
|:---|:---|:---|:---|
| スケジュール登録 | `crontab -e` | タスクスケジューラー（GUI / PowerShell） | `crontab -e`（launchd も利用可） |
| 書式 | `分 時 日 月 曜日 コマンド` | GUI でトリガー設定 | cron 互換 |
| システム全体の定期処理 | `/etc/cron.daily/` など | サービスのスケジュールタスク | `/etc/periodic/daily/` など |
| 実行ログ確認 | `grep CRON /var/log/syslog` | イベントビューアー | `log show --predicate 'subsystem == "com.apple.xpc.launchd"'` |

---

## 理解度チェック

1. cron の書式 `*/15 9-18 * * 1-5 コマンド` は何を意味するか？

<details>
<summary>答え</summary>

平日（月曜〜金曜）の 9 時から 18 時の間、15 分ごとにコマンドを実行する。

- `*/15` — 0, 15, 30, 45 分
- `9-18` — 9 時から 18 時
- `*` — 毎日・毎月
- `1-5` — 月曜（1）から金曜（5）

</details>

---

2. `crontab -e` で登録する書式と `/etc/crontab` の書式の違いは何か？

<details>
<summary>答え</summary>

`/etc/crontab` と `/etc/cron.d/` には **ユーザー名列** がある（6 列構成）。`crontab -e` で登録するユーザー crontab はユーザー名列がない（5 列構成）。

- `crontab -e`: `分 時 日 月 曜日 コマンド`
- `/etc/crontab`: `分 時 日 月 曜日 ユーザー名 コマンド`

ユーザー crontab にユーザー名列を書くとコマンドが壊れるため注意。

</details>

---

3. cron から呼び出したスクリプトが端末では動くのに cron では動かない。考えられる原因を 2 つ挙げよ。

<details>
<summary>答え</summary>

1. **環境変数 `$PATH` の違い**: cron の `$PATH` は `/usr/bin:/bin` 程度しかなく、コマンドが見つからない（`command not found`）。フルパスで記述するか、crontab 先頭で `PATH=...` を設定する。

2. **`sudo` の TTY 問題**: cron は TTY を持たないため、`sudo` がパスワードを端末で入力させようとして止まる。NOPASSWD 設定または root crontab での実行に切り替える。

その他: `chmod +x` が付いていない、スクリプト内の相対パスが実行ディレクトリに依存している、なども考えられる。

</details>

---

4. cron ジョブの出力を記録する方法として `>> /tmp/cron.log 2>&1` と `logger` の 2 種類がある。それぞれどのような状況で使うか？

<details>
<summary>答え</summary>

- `>> /tmp/cron.log 2>&1`: スクリプト単体の動作確認・デバッグに向いている。コマンドの詳細な出力（標準出力と標準エラー）をファイルに残せる。`tail -f` でリアルタイム確認ができる。

- `logger` でsyslog記録: 複数のサービスのログを `/var/log/syslog` に一元管理したいとき。chapter-16 の `nginx_manager.sh` のように `log()` 関数を実装しておくと、cron から呼び出したときも自動で syslog に記録される。

両方を組み合わせる（ファイルリダイレクト + スクリプト内 `logger`）のが最も情報を残しやすい。

</details>

---

5. `/etc/cron.daily/logrotate` に `if [ -d /run/systemd/system ]; then exit 0; fi` という行がある。Codespaces 環境でこのスクリプトが正常に動作する理由を説明せよ。

<details>
<summary>答え</summary>

`[ -d /run/systemd/system ]` は「`/run/systemd/system` ディレクトリが存在するか」を確認する。存在すれば `exit 0`（何もせず終了）し、systemd timer に任せる。

Codespaces は Docker コンテナとして動作しており、systemd が PID 1 ではない。そのため `/run/systemd/system` ディレクトリが存在しない。条件が偽になるので `exit 0` には進まず、logrotate が正常に実行される。

</details>

---

次章では、cron が毎日呼び出している logrotate の設定ファイル（`/etc/logrotate.conf`）の読み方と、nginx のアクセスログを自動ローテーションする仕組みを学びます。

| [← 第16章: シェルスクリプトを書く](../chapter-16/README.md) | [全章目次](../README.md) | [第18章: logrotate でログを管理する →](../chapter-18/README.md) |
|:---|:---:|---:|
