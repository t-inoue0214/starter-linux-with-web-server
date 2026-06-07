# 第14章: OS ログを読む・書く

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第9章: ユーザーとグループを管理する（`sudo` の使い方）
- 第13章: ファイルシステムとディスク使用量を確認する（`/var/log/` の場所の理解）

## 概要

Linux でトラブルが発生したとき、最初に見るべきものが「ログ」です。
この章では、OS がどこにログを記録しているか、リアルタイム監視の方法、
自分でログを書き込む方法、ログを整理する仕組みを学びます。
chapter-20 で nginx をソースビルドした後も、同じ `tail -f` コマンドで動作確認ができるようになります。

## 手順

### 14-1. OS ログとは何か

**ログ**とは、アプリや OS が「今何をしたか」を時系列で記録したテキストファイルです。
エラーが発生したとき、ログを見ることで「いつ・何が・どんな問題を起こしたか」を追跡できます。

Linux のログには大きく 2 つの仕組みがあります。

```text
① rsyslog（従来型）
   アプリ → rsyslog デーモン → /var/log/syslog 等のテキストファイルに書き込む

② systemd journal（新型）
   アプリ → systemd-journald → バイナリ形式で保存 → journalctl コマンドで閲覧
```

**デーモン**とは、バックグラウンドで動き続けるプログラムのことです（Windows のサービスに相当）。
rsyslog はログを受け取って `/var/log/` 以下に書き込み続けるデーモンです。

Codespaces では PID 1（最初に起動するプロセス）が `/bin/sh` のため、
systemd-journald は動作していません。この章では主に rsyslog を使って学びます。

### 14-2. rsyslog を起動する

rsyslog は Codespaces にインストールされていますが、コンテナ起動時には自動起動されません。
まず rsyslog を起動してから、ログを扱う準備をします。

```bash
$ sudo rsyslogd
$ sudo tail -3 /var/log/syslog
```

```text
2026-05-30T07:03:51.317088+00:00 codespaces-bc9305 rsyslogd: [origin software="rsyslogd" swVersion="8.2504.0" x-pid="48328" x-info="https://www.rsyslog.com"] start
```

`rsyslogd` が起動すると `/var/log/syslog` が作成され、ログの記録が始まります。

> **`pidfile ... already exist` エラーが出た場合:**
> rsyslog がすでに起動済みであることを示します。そのまま次のステップに進んで問題ありません。

> **なぜ `sudo` が必要か？**
> `/var/log/syslog` は `root:adm`（パーミッション 640）で作成されるため、
> 一般ユーザーは直接読み取れません。`sudo` を付けて root として読み取ります。

> **[Codespaces 制限]** 実際の Linux サーバーでは rsyslog は OS 起動時に自動起動されます。
> Codespaces ではコンテナを再起動するたびに `sudo rsyslogd` が必要です。

### 14-3. /var/log/ の主要ファイルを確認する

```bash
$ ls /var/log/
$ sudo tail -5 /var/log/syslog
$ sudo tail -5 /var/log/auth.log
$ cat /var/log/dpkg.log | tail -10
$ cat /var/log/apt/history.log | tail -20
```

各ファイルの役割は以下のとおりです。

| ファイル | 内容 | 読み取り権限 |
|:---|:---|:---|
| `/var/log/syslog` | システム全般のログ（Debian 系） | `sudo` 必要 |
| `/var/log/auth.log` | 認証関連（`sudo` の使用・SSH ログイン等） | `sudo` 必要 |
| `/var/log/user.log` | ユーザーアプリのログ | `sudo` 必要 |
| `/var/log/kern.log` | カーネルメッセージ | `sudo` 必要 |
| `/var/log/dpkg.log` | パッケージのインストール・削除履歴 | 一般ユーザー可 |
| `/var/log/apt/history.log` | `apt` コマンドの操作履歴 | 一般ユーザー可 |
| `/var/log/nginx/access.log` | nginx へのアクセス記録（chapter-04 以降） | 一般ユーザー可 |
| `/var/log/nginx/error.log` | nginx のエラー記録（chapter-04 以降） | 一般ユーザー可 |

`/var/log/dpkg.log` には、この Codespaces 環境でインストールしたパッケージの記録があります。

```text
2026-05-27 13:19:58 status installed nodejs:amd64 24.15.0-1nodesource1
2026-05-27 13:19:58 trigproc systemd:amd64 257.13-1~deb13u1 <none>
```

### 14-4. logger でログを書いてみる

`logger` コマンドを使うと、スクリプトや手動操作でログを `/var/log/syslog` に書き込めます。

```bash
$ logger "はじめてのログメッセージ"
$ sudo tail -5 /var/log/syslog
```

```text
2026-05-30T07:04:03.604740+00:00 codespaces-bc9305 vscode: はじめてのログメッセージ
```

タグ（アプリ名）を付けてログを書くこともできます。

```bash
$ logger -t myapp "アプリ起動完了"
$ logger -p user.err "エラーが発生しました"
$ sudo tail -5 /var/log/syslog
```

```text
2026-05-30T07:05:10.123456+00:00 codespaces-bc9305 myapp: アプリ起動完了
2026-05-30T07:05:11.234567+00:00 codespaces-bc9305 vscode: エラーが発生しました
```

**主なオプション:**

| オプション | 意味 |
|:---|:---|
| `-t TAG` | ログにタグ（アプリ名）を付ける |
| `-p FACILITY.LEVEL` | ファシリティ（ログの発生源の分類: `user`=ユーザーアプリ、`auth`=認証、`kern`=カーネル）とログレベルを指定する |

### 14-5. tail -f でリアルタイム監視する

`-f`（follow）オプションを付けると、ファイルの末尾を監視し続けます。

まず 1 つ目のターミナルで監視を開始します。

```bash
$ sudo tail -f /var/log/syslog
```

次に、VS Code で新しいターミナルを開き（Ctrl + Shift + `` ` ``）、logger を実行します。

```bash
$ logger "リアルタイム監視テスト"
```

1 つ目のターミナルにメッセージがリアルタイムで表示されます。

```text
2026-05-30T07:10:00.000000+00:00 codespaces-bc9305 vscode: リアルタイムに表示されました
```

監視を終了するには `Ctrl + C` を押します。

### 14-6. ログレベルを理解する

ログには重大度を示す「ログレベル」があります。数値が小さいほど深刻です。

| 数値 | 名前 | 説明 | `logger` での指定例 |
|:---:|:---|:---|:---|
| 0 | EMERG | システムが使用不可 | `logger -p user.emerg "..."` |
| 1 | ALERT | 即時対応が必要 | `logger -p user.alert "..."` |
| 2 | CRIT | 重大な障害 | `logger -p user.crit "..."` |
| 3 | ERR | エラー | `logger -p user.err "..."` |
| 4 | WARNING | 警告 | `logger -p user.warning "..."` |
| 5 | NOTICE | 注意を要する正常な状態 | `logger -p user.notice "..."` |
| 6 | INFO | 情報メッセージ | `logger -p user.info "..."` |
| 7 | DEBUG | デバッグ情報 | `logger -p user.debug "..."` |

各レベルで実際にログを書いて、syslog に記録される様子を確認しましょう。

```bash
$ logger -p user.info  "情報: 処理を開始します"
$ logger -p user.warning "警告: ディスク残量が少なくなっています"
$ logger -p user.err  "エラー: 設定ファイルが見つかりません"
$ sudo tail -5 /var/log/syslog
```

> **自作アプリのログ設計に活かす:**
> 開発中は `DEBUG`、本番環境では `INFO` 以上を出力するのが一般的な使い分けです。
> `DEBUG` ログを本番に残すと、パスワードや個人情報が記録されてしまうリスクがあります。

### 14-7. auth.log で認証ログを読む

`/var/log/auth.log` には `sudo` コマンドの使用履歴や認証に関するログが記録されます。

```bash
$ sudo tail -10 /var/log/auth.log
```

```text
2026-05-30T07:14:43.568960+00:00 codespaces-bc9305 sudo:   vscode : PWD=/workspaces/starter-linux-with-web-server ; USER=root ; COMMAND=/usr/bin/tail -5 /var/log/syslog
2026-05-30T07:14:43.569536+00:00 codespaces-bc9305 sudo: pam_unix(sudo:session): session opened for user root(uid=0) by (uid=1000)
2026-05-30T07:14:43.571760+00:00 codespaces-bc9305 sudo: pam_unix(sudo:session): session closed for user root
```

この章でここまで実行してきた `sudo` コマンドが、すべて auth.log に記録されているはずです。
実際に確認してみましょう。

> **セキュリティ面での重要性:**
> `auth.log` は不正アクセスの調査に欠かせないログです。
> 見知らぬ IP アドレスからの SSH ログイン試行が記録されていた場合、
> 攻撃を受けた可能性があると判断できます。

### 14-8. journalctl でログを検索する

> **[Codespaces 制限]** Codespaces はコンテナ内で動作しているため、
> `journalctl` のログは空になります。実際のサーバーでの使い方として参考にしてください。

実際に実行すると、以下のように表示されます。

```bash
$ journalctl -n 5
No journal files were found.
-- No entries --
```

実際の Linux サーバーでよく使うコマンドを紹介します。

```bash
$ journalctl -n 20                    # 最新20件を表示
$ journalctl -f                       # リアルタイム監視（tail -f と同様）
$ journalctl -u nginx                 # nginx サービスのログのみ表示
$ journalctl --since "1 hour ago"     # 1時間以内のログを表示
$ journalctl -p err                   # ERR レベル以上のみ表示
$ journalctl -b                       # 今回のブート以降のログを表示
```

`tail -f /var/log/syslog` との使い分けは以下のとおりです。

| 操作 | `sudo tail -f /var/log/syslog` | `journalctl -f` |
|:---|:---|:---|
| データの形式 | rsyslog が書くテキストファイル | systemd journal（バイナリ） |
| フィルタ方法 | `grep` との組み合わせ | `-u`（サービス）、`-p`（レベル）オプション |
| 向いている用途 | Debian 環境でのシステムログ全般 | systemd サービス単位での追跡 |

### 14-9. rsyslog の設定ファイルを読む

rsyslog の設定ファイルを確認してみましょう（閲覧のみ）。

```bash
$ cat /etc/rsyslog.conf
```

重要な箇所を抜粋します。

```text
# ログファイルの作成権限（owner: root, group: adm, パーミッション: 640）
$FileOwner root
$FileGroup adm
$FileCreateMode 0640

# 書き込み先のルール（FACILITY.LEVEL → 書き込み先ファイル）
*.*;auth,authpriv.none    -/var/log/syslog   # 全ログ（認証除く）を syslog へ
auth,authpriv.*            /var/log/auth.log  # 認証ログを auth.log へ
kern.*                    -/var/log/kern.log  # カーネルログを kern.log へ
user.*                    -/var/log/user.log  # ユーザーアプリのログを user.log へ
*.emerg                    :omusrmsg:*        # 緊急ログはログイン中の全ユーザーに通知
```

**ルールの書き方:**

```text
FACILITY.LEVEL    書き込み先

FACILITY（ファシリティ）= ログの発生源の分類
  auth       … 認証関連
  kern       … カーネル
  user       … ユーザーアプリ
  *          … すべて

LEVEL（レベル）= ログの重大度
  err, warning, info, debug, * など
```

先頭に `-` が付いているルール（`-/var/log/syslog` など）は、
書き込みのたびにディスクを同期しない設定で、パフォーマンスを優先しています。

> **[注意] rsyslog.conf は編集しないこと**
> 設定ミスによりログが一切記録されなくなるリスクがあります。この章では閲覧のみです。

---

### コラム: logrotate — ログファイルの自動整理

ログを書き続けると `/var/log/` がどんどん大きくなり、chapter-13 で学んだように
ディスクが満杯になってしまいます。それを防ぐのが `logrotate` です。

```bash
$ cat /etc/logrotate.conf
$ ls /etc/logrotate.d/
$ cat /etc/logrotate.d/rsyslog
```

`/etc/logrotate.conf` の主要設定:

```text
weekly        # 週に1回ローテーション（古いファイルを .1、.2 … と番号付きにリネーム）
rotate 4      # 4世代分を保持（5世代目以降は削除）
create        # ローテーション後に新しい空ファイルを作成
```

`/etc/logrotate.d/rsyslog` の内容（実際の設定）:

```text
/var/log/syslog /var/log/auth.log /var/log/kern.log ...
{
    rotate 4
    weekly
    missingok
    notifempty
    compress         # 古いログを .gz で圧縮
    delaycompress    # 直近1世代は圧縮しない
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate   # ローテーション後に rsyslog に通知
    endscript
}
```

これにより `/var/log/syslog.1`（前週）、`syslog.2.gz`（2週前、圧縮済み）のような
ファイルが自動的に生成・管理されます。

---

### コラム: nginx のアクセスログとエラーログ

chapter-04 で nginx をインストールしてから、nginx は `/var/log/nginx/` にログを書き続けています。

```bash
$ cat /var/log/nginx/access.log | tail -5
$ cat /var/log/nginx/error.log | tail -5
```

アクセスログの1行の構造:

```text
127.0.0.1 - - [30/May/2026:12:00:00 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.88.1"
↑送信元IP    ↑日時                           ↑メソッド  ↑URL ↑ステータスコード  ↑User-Agent
```

chapter-20 で nginx をソースからビルドした後は、ログの保存先が変わります。

```text
apt install で入れた nginx → /var/log/nginx/
ソースビルドした nginx    → /usr/local/nginx/logs/
```

同じ `tail -f` コマンドで、chapter-20 以降もアクセスログをリアルタイムに確認できます。

---

## よくあるミス

| ミス | 症状 | 正しい対処 |
|:---|:---|:---|
| `sudo rsyslogd` をせずに `logger` を実行した | ログがどこにも書き込まれない | 先に `sudo rsyslogd` を実行する |
| `tail /var/log/syslog`（`-f` なし） | 最後の10行を表示して終了する | `-f` を付けると監視モードになる |
| `tail /var/log/syslog`（`sudo` なし） | `Permission denied` エラー | `sudo tail -f /var/log/syslog` とする |
| `journalctl` を実行したが空だった | Codespaces コンテナでは journald が動作していない | `sudo tail -f /var/log/syslog` で代替する |
| ログレベルの番号が逆に感じる | 数字が小さいほど重大（0 = EMERG、7 = DEBUG） | 「ERR = 3、DEBUG = 7」と覚える |

## 類似比較

| コマンド | 見るもの | 特徴 |
|:---|:---|:---|
| `sudo tail -f /var/log/syslog` | rsyslog が書くテキストファイル | `grep` と組み合わせやすい |
| `journalctl -f` | systemd journal（バイナリ） | サービス単位で絞り込める（Codespaces では空） |
| `cat /var/log/dpkg.log` | パッケージ操作の全履歴 | `sudo` 不要で読める |
| `logger` | ログを書く側 | スクリプトやアプリからの手動書き込みに使う |

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| ログの確認 | `tail`、`cat /var/log/syslog` | イベントビューア（`eventvwr.msc`） | Console.app |
| リアルタイム監視 | `tail -f /var/log/syslog` | PowerShell `Get-EventLog` | `log stream` |
| サービス単位の検索 | `journalctl -u nginx` | `Get-EventLog -Source nginx` | `log show --predicate 'process == "nginx"'` |
| 手動書き込み | `logger "message"` | `Write-EventLog` | `logger "message"` |
| ログの自動整理 | `logrotate`（設定ファイルで制御） | 自動削除（イベントビューアの設定） | `newsyslog` |

## 理解度チェック

1. Codespaces 環境でログを読むには、まず何をする必要がありますか?

<details><summary>答え</summary>

`sudo rsyslogd` を実行して rsyslog デーモンを起動する必要があります。

Codespaces では PID 1（最初のプロセス）が `/bin/sh` であり、
systemd が動作していないため rsyslog は自動起動されません。
`sudo rsyslogd` を実行することで `/var/log/syslog` が作成され、ログが記録され始めます。

</details>

2. `logger "テスト"` を実行した後、ログが記録されているか確認するコマンドを書いてください。

<details><summary>答え</summary>

```bash
sudo tail -5 /var/log/syslog
```

`/var/log/syslog` のパーミッションは `root:adm 640` のため、一般ユーザーが直接読むことはできません。`sudo tail -5 /var/log/syslog` で root として末尾5行を確認します。

</details>

3. ログレベル `ERR`（3）と `DEBUG`（7）はどちらが重大なエラーを示しますか?

<details><summary>答え</summary>

`ERR`（3）のほうが重大です。

ログレベルは数値が小さいほど重大度が高く、大きいほど軽微です。

- 0（EMERG）: システムが使用不可
- 3（ERR）: エラー
- 7（DEBUG）: デバッグ情報

本番環境では `INFO`（6）以上のレベルのみ記録する設定が一般的で、
`DEBUG`（7）は開発時にのみ使います。

</details>

4. `sudo tail -f /var/log/syslog` と `journalctl -f` の違いを説明してください。

<details><summary>答え</summary>

| 項目 | `sudo tail -f /var/log/syslog` | `journalctl -f` |
|:---|:---|:---|
| データの形式 | rsyslog が書くテキストファイル | systemd journal（バイナリ形式） |
| フィルタ方法 | `grep` との組み合わせ | `-u`（サービス名）や `-p`（レベル）で絞り込み |
| Codespaces | 使える（rsyslogd 起動後） | 使えない（journald が動作していない） |

Debian 系 Linux での日常的なログ監視には `tail -f /var/log/syslog` が向いています。
`journalctl` は systemd が動作する環境で特定サービスのログを追跡するときに便利です。

</details>

5. logrotate がなければ何が起きますか? chapter-13 で学んだ知識と合わせて説明してください。

<details><summary>答え</summary>

ログファイルが際限なく大きくなり、最終的にはディスクが満杯になります。

chapter-13 で学んだ `df -h` コマンドを実行すると、`/var/log/` が含まれる
ファイルシステムの使用率が 100% に近づいていく様子を確認できます。

logrotate は週次（または日次）でログファイルを `syslog.1`、`syslog.2.gz` のように
リネーム・圧縮し、設定した世代数（デフォルト 4 週分）を超えた古いログを自動削除します。
これにより `/var/log/` のディスク使用量を一定の範囲に抑えられます。

</details>

---

次章では、Linux でプログラムを「サービス」として常時起動・自動再起動させる仕組み（SysVinit と systemd）を学びます。

| [← 第13章: ファイルシステムとディスク使用量を確認する](../chapter-13/README.md) | [全章目次](../README.md) | [第15章: サービス管理（SysVinit 実習 + systemd 説明） →](../chapter-15/README.md) |
|:---|:---:|---:|
