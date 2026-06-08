# 第15章: サービス管理（SysVinit 実習 + systemd 説明）

## 前提知識

- [第09章: ユーザーとグループを管理する](../chapter-09/README.md)（`sudo` の使い方）
- [第14章: OS ログを読む・書く](../chapter-14/README.md)（サービスが書き出すログの読み方）

## 概要

chapter-14 でログを読んだとき、nginx がアクセスのたびに `/var/log/nginx/access.log` へ書き込んでいることを確認した。
この章では、そのログを吐き出しているサービス（デーモン）を止めたり・再起動したりする操作を学ぶ。

また、Linux のサービス管理には「SysVinit（古い仕組み）」と「systemd（現代の仕組み）」の2系統が存在する。
Codespaces では SysVinit 互換の `service` コマンドで実習し、systemd の概念は chapter-19 の nginx.service 自作に向けて説明で理解する。

## 手順

> **Codespaces でなぜ `service` を使うのか:**
> Codespaces はコンテナ環境のため、systemd が PID 1 で動いていない。
> そのため `systemctl start nginx` のような systemd コマンドの多くが使えない。
> この章の実習では SysVinit 互換の `service` コマンドを使う。
> 実際のサーバーでは `systemctl start/stop/enable` を使うのが標準だ。
> chapter-19（Nginx ソースビルド）でユニットファイルを自分で書くとき、初めて本物の systemd 体験ができる。

### 15-1. サービスとは何か（概念）

**サービス（デーモン）の役割:**

バックグラウンドで常駐し、リクエストを待ち受けるプロセスを「サービス」または「デーモン」と呼ぶ。
Windows のタスクマネージャー → サービスタブで確認できるプログラムに相当する。

代表的なサービス:

| サービス名 | 役割 |
|:---|:---|
| nginx | Web サーバー。HTTP リクエストを受け付ける |
| sshd | SSH サーバー。リモートログインを受け付ける |
| rsyslog | ログデーモン（chapter-14 で学んだ） |
| cron | 定期実行スケジューラー |

**SysVinit と systemd の歴史:**

| 項目 | SysVinit | systemd |
|:---|:---|:---|
| 登場時期 | 1983年〜 | 2010年〜（Debian 8 から） |
| 初期化スクリプト | `/etc/init.d/サービス名` | ユニットファイル（`.service`） |
| 操作コマンド | `service サービス名 start` | `systemctl start サービス名` |
| 依存関係管理 | スクリプト内に手続き的に記述 | `After=`・`Requires=` で宣言的に記述 |
| 並列起動 | 不可（逐次） | 可能（高速起動） |
| ログ管理 | `/var/log/*.log`（rsyslog） | journald（`journalctl` で閲覧） |

`service` コマンドは SysVinit・systemd どちらの環境でも動く互換ラッパーで、
内部的に systemd が動いていれば `systemctl` に委譲し、そうでなければ `/etc/init.d/` スクリプトを直接呼び出す。

> **[Codespaces 制限]** Codespaces では PID 1 が `/bin/sh` のため systemd が動作しない。
> `service` コマンドが `/etc/init.d/nginx` を直接呼び出す形で動作する。
> `systemctl` は実サーバー向け参考コマンドとして後述する。

---

### 15-2. service コマンドで nginx を操作する（実習）

chapter-04 でインストールした nginx を操作する。
`apt install nginx` によって `/etc/init.d/nginx` が作成され、`service` コマンドはこのスクリプトを呼び出す。

まず nginx が起動しているか確認する（セッション再起動時は停止している場合がある）:

```bash
$ service nginx status
```

起動中の場合の出力例:

```text
 * nginx is running
```

停止中の場合の出力例:

```text
 * nginx is not running
```

停止していた場合は起動する:

```bash
$ sudo service nginx start
$ service nginx status
```

起動後の確認:

```bash
$ curl http://localhost
```

nginx が動いていれば HTML が返ってくる。

---

### 15-3. service の stop/start/restart を試す（実習）

nginx を止めてからブラウザや curl でアクセスすると「接続拒否」になることを確認する。

```bash
$ sudo service nginx stop
$ curl http://localhost
```

停止後の出力例:

```text
curl: (7) Failed to connect to localhost port 80 after 0 ms: Connection refused
```

起動し直す:

```bash
$ sudo service nginx start
$ curl http://localhost
```

起動後は再び HTML が返ってくる。

設定変更後に使う restart（stop → start の短縮形）:

```bash
$ sudo service nginx restart
```

> **なぜ stop/start に `sudo` が必要か:**
> nginx はポート 80（特権ポート: 1024 未満）を使うため、stop/start には root 権限が必要。
> `status` は一般ユーザーでも実行できる。

---

### 15-4. /etc/init.d/ スクリプトを確認する（実習 — 閲覧のみ）

`service` コマンドが実際に呼び出しているスクリプトを見てみる。

```bash
$ ls /etc/init.d/
```

出力例（インストール済みのサービスが一覧表示される）:

```text
cron  dbus  exim4  nginx  procps  rsync  sudo
```

`nginx` が含まれていることを確認したら、スクリプトの冒頭を見る:

```bash
$ head -15 /etc/init.d/nginx
```

出力例:

```bash
#!/bin/sh

### BEGIN INIT INFO
# Provides:          nginx
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the nginx web server
# Description:       starts nginx using start-stop-daemon
### END INIT INFO
```

`### BEGIN INIT INFO` から `### END INIT INFO` の部分は「LSB ヘッダ」と呼ばれる標準的な記述形式。

**ランレベル**とは Linux の起動状態を表す番号（0〜6）で、SysVinit がどの状態でサービスを起動・停止するかを制御する。

| フィールド | 意味 |
|:---|:---|
| `Required-Start` | このサービスより先に起動すべきサービス |
| `Default-Start: 2 3 4 5` | 起動するランレベル（マルチユーザーモード） |
| `Default-Stop: 0 1 6` | 停止するランレベル（poweroff・シングルユーザー・reboot） |

> init スクリプトの編集は行わず、閲覧のみ。

---

### 15-5. service --status-all でサービス一覧を確認する（実習）

```bash
$ service --status-all
```

出力例:

```text
 [ + ]  nginx
 [ - ]  cron
 [ - ]  dbus
 [ - ]  rsync
```

記号の意味:

| 記号 | 意味 |
|:---:|:---|
| `[ + ]` | 起動中（running） |
| `[ - ]` | 停止中（stopped） |
| `[ ? ]` | 状態不明（init スクリプトが `status` 未対応） |

nginx を止めると `[ + ]` が `[ - ]` に変わることを確認してみる:

```bash
$ sudo service nginx stop
$ service --status-all | grep nginx
```

---

### 15-6. ps コマンドでプロセスを確認する（実習）

サービスの停止・起動をプロセスレベルで確認する。

```bash
$ ps aux | grep nginx
```

nginx が動いているときの出力例:

```text
root      1234  0.0  0.1  55284  1864 ? Ss 12:00   0:00 nginx: master process /usr/sbin/nginx
www-data  1235  0.0  0.0  55584  1012 ? S  12:00   0:00 nginx: worker process
www-data  1236  0.0  0.0  55584  1012 ? S  12:00   0:00 nginx: worker process
```

nginx のプロセス構造:

| プロセス | 起動ユーザー | 役割 |
|:---|:---|:---|
| `master process` | root | 設定の読み込み・ワーカーの管理 |
| `worker process` | www-data | 実際のリクエスト処理 |

nginx を停止してから再確認:

```bash
$ sudo service nginx stop
$ ps aux | grep nginx        # nginx のプロセスが消える
$ sudo service nginx start
$ ps aux | grep nginx        # 再び表示される
```

---

### 15-7. systemctl コマンドを知る（参考 — Codespaces 制限）

> **[Codespaces 制限]** 以下のコマンドは Codespaces では動作しない。
> 実際のサーバーでの使い方として参考にしてほしい。

Codespaces で実行すると次のメッセージが表示される:

```bash
$ systemctl status nginx
"systemd" is not running in this container due to its overhead.
Use the "service" command to start services instead. e.g.:

service --status-all
```

実サーバーでの代表的な使い方:

```bash
$ systemctl status nginx              # 状態確認
$ sudo systemctl start nginx          # 起動
$ sudo systemctl stop nginx           # 停止
$ sudo systemctl restart nginx        # 再起動
$ sudo systemctl reload nginx         # 設定リロード（プロセスを止めずに設定を再読み込み）
$ sudo systemctl enable nginx         # OS 起動時の自動起動を有効化
$ sudo systemctl disable nginx        # 自動起動を無効化
$ systemctl list-units --type=service # 全サービス一覧
$ systemctl list-units --failed       # 失敗しているサービス一覧
$ sudo systemctl daemon-reload        # ユニットファイル変更後に必要
```

`service` vs `systemctl` の対応表:

| 操作 | service コマンド | systemctl コマンド |
|:---|:---|:---|
| 状態確認 | `service nginx status` | `systemctl status nginx` |
| 起動 | `sudo service nginx start` | `sudo systemctl start nginx` |
| 停止 | `sudo service nginx stop` | `sudo systemctl stop nginx` |
| 再起動 | `sudo service nginx restart` | `sudo systemctl restart nginx` |
| 設定リロード | `sudo service nginx reload` | `sudo systemctl reload nginx` |
| 一覧 | `service --status-all` | `systemctl list-units --type=service` |

> **引数の順序に注意:** `service` は `service サービス名 動詞`、`systemctl` は `systemctl 動詞 サービス名` と順序が逆になっている。

---

### 15-8. systemd ユニットファイルの構造を知る（説明 — chapter-19 の前準備）

Debian の nginx パッケージには、`/etc/init.d/nginx`（SysVinit 用）のほかに
`/usr/lib/systemd/system/nginx.service`（systemd 用）も含まれている。

systemd 環境で `apt install nginx` を実行した場合のユニットファイル（実際の内容）:

```ini
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target
ConditionFileIsExecutable=/usr/sbin/nginx

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```

セクションの役割:

| セクション | 内容 |
|:---|:---|
| `[Unit]` | サービスの説明・起動順序（`After=`）・起動条件（`ConditionFileIsExecutable=`） |
| `[Service]` | 起動コマンド（`ExecStart`）・停止コマンド（`ExecStop`）・PID ファイル（起動中プロセスの番号を記録するファイル）の場所 |
| `[Install]` | どの起動ターゲットで有効化するか |

**ランレベル ↔ systemd ターゲット対応:**

| ランレベル | systemd ターゲット | 意味 |
|:---:|:---|:---|
| 0 | `poweroff.target` | シャットダウン |
| 1 | `rescue.target` | シングルユーザーモード（メンテナンス） |
| 2, 3 | `multi-user.target` | マルチユーザー（GUI なし） |
| 5 | `graphical.target` | マルチユーザー（GUI あり） |
| 6 | `reboot.target` | 再起動 |

`WantedBy=multi-user.target` は「マルチユーザーモードで起動する」という意味で、
通常の Linux サーバー起動時、nginx が自動的に起動する設定を意味する。

chapter-19 では nginx をソースからビルドした後、このユニットファイルを参考に
インストール先（`/usr/local/nginx/`）に合わせた nginx.service を自作する。

---

### コラム: シングルユーザーモード（runlevel 1）

本番サーバーのメンテナンス時に使う「安全な最小起動状態」。Codespaces では試せないが概念を説明する。

| 項目 | 内容 |
|:---|:---|
| 起動するサービス | 最小限のみ（ネットワーク・nginx 等は起動しない） |
| ログイン | root のみ |
| 用途 | パスワードリセット・ファイルシステム修復・壊れた設定の修正 |
| 抜け出し方 | `exit` または `reboot` |

> **注意:** 誤って本番サーバーをシングルユーザーモードで再起動すると、
> ネットワーク接続が切断されてリモートからアクセスできなくなる。
> 物理コンソールか ILO/iDRAC/BMC（リモート管理ポート）が必要になる。

---

## よくあるミス

| ミス | 症状 | 対処 |
|:---|:---|:---|
| `service nginx start` と `systemctl start nginx` の引数順序混同 | コマンドエラー | `service` は「サービス名 → 動詞」、`systemctl` は「動詞 → サービス名」 |
| `sudo` なしで stop/start | `Permission denied` または無言で失敗 | `sudo service nginx start` |
| `systemctl` を Codespaces で実行 | `"systemd" is not running...` | `service` コマンドを使う |
| ユニットファイル編集後に `daemon-reload` を忘れる | 古い設定で動き続ける | `sudo systemctl daemon-reload` を実行してから再起動 |
| `enable` と `start` の混同 | `enable` だけでは今すぐ起動しない | `enable` は「次回起動時の自動起動設定」。今すぐ起動するには `start` も必要 |

---

## 類似比較

| コマンド | 動作環境 | 特徴 |
|:---|:---|:---|
| `service nginx status` | SysVinit・systemd 両対応 | どの環境でも動く互換コマンド |
| `systemctl status nginx` | systemd 専用 | 詳細な状態・ジャーナルログも表示（実サーバー向け） |
| `/etc/init.d/nginx status` | SysVinit | スクリプトを直接実行（`service` の内部動作と同じ） |
| `ps aux \| grep nginx` | 全環境 | プロセスの存在を直接確認する低レベルな方法 |

---

## 他OSとの比較

| OS | サービス管理ツール | 確認コマンド例 |
|:---|:---|:---|
| Linux (Debian/Ubuntu) | systemd / SysVinit | `systemctl status nginx` / `service nginx status` |
| Linux (RHEL/CentOS 7+) | systemd | `systemctl status nginx` |
| Windows | サービスコントロールマネージャー | `sc query nginx` / タスクマネージャー → サービスタブ |
| macOS | launchd | `launchctl list` / `brew services list` |

---

## 理解度チェック

1. `service nginx stop` を実行した後、`curl http://localhost` で接続しようとするとどうなるか？

<details>
<summary>答え</summary>

`curl: (7) Failed to connect to localhost port 80 after 0 ms: Connection refused` のようなエラーが返る。nginx が停止しているため、ポート 80 でリクエストを受け付けていない。

</details>

---

2. `service nginx start` と `systemctl start nginx` の違いは何か？

<details>
<summary>答え</summary>

- `service nginx start`: SysVinit・systemd どちらの環境でも動く互換コマンド。`/etc/init.d/nginx` を呼び出す（systemd 非環境の場合）
- `systemctl start nginx`: systemd が動いている環境専用。Codespaces では `"systemd" is not running...` のエラーになる
- 引数の順序も逆（`service サービス名 動詞` vs `systemctl 動詞 サービス名`）

</details>

---

3. `service --status-all` の出力で `[ + ]` `[ - ]` `[ ? ]` はそれぞれ何を意味するか？

<details>
<summary>答え</summary>

- `[ + ]`: 起動中（running）
- `[ - ]`: 停止中（stopped）
- `[ ? ]`: init スクリプトが `status` コマンドをサポートしていないため状態不明

</details>

---

4. nginx のプロセスに `master process` と `worker process` の2種類があるのはなぜか？

<details>
<summary>答え</summary>

役割を分離するため。

- `master process`（root 権限）: 設定の読み込み・ワーカーの管理・シグナル処理
- `worker process`（www-data 権限）: 実際のリクエスト処理

worker が root 権限を持たないことで、万一 worker プロセスが乗っ取られてもシステム全体への影響を最小化できる（最小権限の原則）。

</details>

---

5. systemd ユニットファイルの `[Install]` セクションに `WantedBy=multi-user.target` と書く意味は何か？

<details>
<summary>答え</summary>

「マルチユーザーモード（通常の Linux 起動状態）で nginx を自動起動する」という設定。`systemctl enable nginx` を実行することで有効になる。

`multi-user.target` は SysVinit のランレベル 2〜3 に相当し、ネットワークが有効・GUI なしの標準的なサーバー起動状態を指す。

</details>

---

次章では、繰り返し作業を自動化するためのシェルスクリプトの書き方（変数・条件分岐・ループ・関数）を学びます。

| [← 第14章: OS ログを読む・書く](../chapter-14/README.md) | [全章目次](../README.md) | [第16章: シェルスクリプトを書く →](../chapter-16/README.md) |
|:---|:---:|---:|
