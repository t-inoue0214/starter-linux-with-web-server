# 第18章: logrotate でログを管理する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第14章: OS ログを読む・書く（`/var/log/` のログ構造を理解している）
- 第17章: cron でタスクを自動化する（`/etc/cron.daily/logrotate` がこの章の出発点）

## 概要

第17章で確認した `/etc/cron.daily/logrotate` が毎日呼び出しているのが **logrotate** だ。
nginx のアクセスログは放置すると肥大化し続けるが、`apt install nginx` を実行したときに
自動作成された `/etc/logrotate.d/nginx` がその問題を自動解決していた。
この章でその仕組みを完全に読み解く。

## 手順

### 18-1. logrotate とは・なぜ必要か

**ログ肥大化問題を体感する:**

```bash
$ ls -lh /var/log/nginx/access.log
-rw-r----- 1 www-data adm 160 Jun  1 14:07 /var/log/nginx/access.log
$ df -h /var/log
Filesystem      Size  Used Avail Use% Mounted on
overlay          32G  8.2G   22G  27% /
```

nginx のアクセスログはリクエストのたびに 1 行追記される。
トラフィックが多いサービスでは 1 日で数 GB になることも珍しくない。

**logrotate の役割（世代管理）:**

logrotate は古いログファイルを「世代管理」する仕組みだ。

```text
rotate 前:
  /var/log/nginx/access.log （現在・書き込み中）

1 回目の rotate 後:
  /var/log/nginx/access.log   （新・空ファイル）
  /var/log/nginx/access.log.1 （旧・1世代前）

2 回目の rotate 後:
  /var/log/nginx/access.log    （新・空ファイル）
  /var/log/nginx/access.log.1  （1世代前）
  /var/log/nginx/access.log.2.gz （2世代前・圧縮済み）
```

**cron との関係（第17章の復習）:**

```text
毎日 6:25（/etc/crontab で設定）
  → run-parts /etc/cron.daily/
    → /etc/cron.daily/logrotate
      → /usr/sbin/logrotate /etc/logrotate.conf
        → include /etc/logrotate.d/nginx を処理
```

第17章で `/etc/cron.daily/logrotate` を読み解いたとき、最後の行が
`/usr/sbin/logrotate /etc/logrotate.conf` だったことを思い出してほしい。
この章ではその `logrotate` が何をするのかを深掘りする。

### 18-2. /etc/logrotate.conf を読む

`/etc/logrotate.conf` は logrotate 全体に適用されるグローバル設定だ。

```bash
$ cat /etc/logrotate.conf
```

出力例:

```text
# see "man logrotate" for details

# global options do not affect preceding include directives

# rotate log files weekly
weekly

# keep 4 weeks worth of backlogs
rotate 4

# create new (empty) log files after rotating old ones
create

# use date as a suffix of the rotated file
#dateext

# uncomment this if you want your log files compressed
#compress

# packages drop log rotation information into this directory
include /etc/logrotate.d

# system-specific logs may also be configured here.
```

**グローバル設定の読み方:**

| 設定 | 意味 |
|:---|:---|
| `weekly` | デフォルト: 週次ローテーション（`/etc/logrotate.d/` の設定で上書き可） |
| `rotate 4` | デフォルト: 4 世代分のバックアップを保持 |
| `create` | ローテーション後に空の新しいログファイルを作成する |
| `include /etc/logrotate.d` | `/etc/logrotate.d/` 内のすべてのファイルを追加設定として読み込む |

> **グローバル設定と個別設定の関係:** `include /etc/logrotate.d` で読み込まれる
> 各ファイルに個別の設定（`daily`・`rotate 14` など）があれば、
> グローバル設定より個別設定が優先される。
> `/etc/logrotate.d/nginx` に `daily` と書けば、グローバルの `weekly` より優先される。

### 18-3. /etc/logrotate.d/ の構造

```bash
$ ls /etc/logrotate.d/
```

出力例:

```text
alternatives  apt  btmp  dpkg  exim4-base  exim4-paniclog  nginx  rsyslog  wtmp
```

`apt install nginx` を実行したときに `/etc/logrotate.d/nginx` が自動作成された。
パッケージが「自分のログのローテーション設定」をここに自動配置する仕組みだ。

同様に `rsyslog` も `/etc/logrotate.d/rsyslog` に設定を配置している。
`apt remove nginx` を実行すると `/etc/logrotate.d/nginx` も自動的に削除される。

> **`/etc/logrotate.d/` のファイルに実行権限を付けてはいけない:**
> logrotate はここのファイルを「設定ファイル」として読み込む。
> 実行権限（`chmod +x`）を付けると、`run-parts` の対象になってしまい
> 意図しない動作を引き起こす可能性がある。

### 18-4. /etc/logrotate.d/nginx を読み解く

```bash
$ cat /etc/logrotate.d/nginx
```

出力例:

```text
/var/log/nginx/*.log {
	daily
	missingok
	rotate 14
	compress
	delaycompress
	notifempty
	create 0640 www-data adm
	sharedscripts
	prerotate
		if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
			run-parts /etc/logrotate.d/httpd-prerotate; \
		fi \
	endscript
	postrotate
		invoke-rc.d nginx rotate >/dev/null 2>&1
	endscript
}
```

**各ディレクティブの意味:**

| ディレクティブ | 意味 |
|:---|:---|
| `/var/log/nginx/*.log {` | この `{...}` ブロックの設定を `access.log` と `error.log` 両方に適用する |
| `daily` | 毎日ローテーション（グローバルの `weekly` を上書き） |
| `missingok` | ログファイルが存在しなくてもエラーにしない |
| `rotate 14` | 14 世代分のバックアップを保持（グローバルの `rotate 4` を上書き） |
| `compress` | 古いファイルを `.gz` 圧縮（gzip） |
| `delaycompress` | **直前世代（`.1`）は圧縮しない**（後述） |
| `notifempty` | ファイルが空なら実行しない |
| `create 0640 www-data adm` | ローテーション後に空のファイルを作成（パーミッション・所有者も指定） |
| `sharedscripts` | `postrotate` を `access.log` と `error.log` でも 1 回だけ実行する |

**`delaycompress` が必要な理由（重要）:**

nginx はログファイルを **ファイルディスクリプタ（FD）** で開いたまま動いている。
ファイルディスクリプタとは「このファイルへの通路」のようなものだ。

logrotate がファイル名を `access.log` → `access.log.1` に変更しても、
nginx は古い通路（FD）を使って旧ファイルに書き続ける。
`compress` で `.gz` 圧縮するのは書き込みが終わってからでないと破損するため、
直前世代（`.1`）は圧縮せず、次のローテーションで `.2.gz` にまとめて圧縮する。

```text
1回目 rotate:
  access.log   → access.log.1（compress せず・nginx がまだ書き込んでいる可能性）
  （空）       ← access.log（新規作成）

postrotate で nginx に USR1 シグナル → nginx が新しい access.log に切り替える

2回目 rotate:
  access.log.1 → access.log.2.gz（ここで初めて compress）
  access.log   → access.log.1（compress せず）
  （空）       ← access.log（新規作成）
```

**`postrotate` スクリプト:**

```text
postrotate
    invoke-rc.d nginx rotate >/dev/null 2>&1
endscript
```

`invoke-rc.d` は Debian 系の SysV init 互換サービス管理コマンドだ（`systemctl`・`service` と同様にサービスへの操作を担う）。
`invoke-rc.d nginx rotate` は nginx に **USR1 シグナル** を送り、ログファイルを再オープンさせる（新しい空の `access.log` への書き込みが始まる）。
これをしないと、nginx は rotate 後も旧ファイルへ書き続けてしまう。

> **シグナルとは:** プロセスに送る「合図」のようなもの。
> USR1 は「ユーザー定義シグナル1」で、nginx はこれを受け取ると
> ログファイルを再オープンする動作として実装している。
> `SIGHUP`（設定ファイルの再読み込み）とは異なり、ワーカープロセスを
> 再起動せずにログファイルだけを切り替える。

**`prerotate` スクリプト:**

```text
prerotate
    if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
        run-parts /etc/logrotate.d/httpd-prerotate; \
    fi \
endscript
```

ローテーションの前に実行される処理だ。
`/etc/logrotate.d/httpd-prerotate/` ディレクトリが存在する場合
（Apache モジュールなどが追加設定を置く場所）、その中のスクリプトを実行する。
通常は空のため何もしない。

### 18-5. dry-run で設定を検証する

設定ファイルを変更したときや、動作を確認したいときは `-d`（dry-run）オプションを使う。
実際にはファイルを変更せず、「何が実行されるか」だけを表示する。

```bash
$ sudo logrotate -d /etc/logrotate.d/nginx
```

出力例:

```text
warning: logrotate in debug mode does nothing except printing debug messages!  Consider using verbose mode (-v) instead if this is not what you want.

reading config file /etc/logrotate.d/nginx
Reading state from file: /var/lib/logrotate/status
Allocating hash table for state file, size 64 entries

Handling 1 logs

rotating pattern: /var/log/nginx/*.log after 1 days empty log files are not rotated, (14 rotations), old logs are removed
considering log /var/log/nginx/access.log
  Now: 2026-06-07 07:26
  Last rotated at 2026-06-07 07:00
  log does not need rotating (log has already been rotated)
considering log /var/log/nginx/error.log
  log does not need rotating (log has already been rotated)
not running prerotate script, since no logs will be rotated
not running postrotate script, since no logs were rotated
```

**dry-run 出力の読み方:**

| 出力行 | 意味 |
|:---|:---|
| `warning: logrotate in debug mode does nothing...` | dry-run モードの注意書き。正常なメッセージ |
| `empty log files are not rotated` | `notifempty` の設定が反映されている |
| `(14 rotations), old logs are removed` | `rotate 14` の設定が反映されている |
| `log does not need rotating (log has already been rotated)` | 直近でローテーション済みのためスキップ |
| `not running postrotate script, since no logs were rotated` | ローテーションが発生しなかったため postrotate も実行されない |

`-v`（verbose）オプションも合わせて使うと、より詳細な情報が得られる:

```bash
$ sudo logrotate -dv /etc/logrotate.d/nginx
```

### 18-6. 強制実行で動作確認する

> **Codespaces での注意:** cron が停止中のため、自動では logrotate が実行されない。
> 動作確認には `sudo logrotate -f`（強制実行）を使う。

実行前の状態を確認:

```bash
$ ls -lh /var/log/nginx/
```

出力例（rotate 前）:

```text
-rw-r----- 1 www-data adm 160 Jun  1 14:07 access.log
-rw-r----- 1 www-data adm   0 Jun  1 14:05 error.log
```

強制実行（`-f` は `--force` の省略形）:

```bash
$ sudo logrotate -f /etc/logrotate.d/nginx
```

実行後の状態を確認:

```bash
$ ls -lh /var/log/nginx/
```

出力例（rotate 後）:

```text
-rw-r----- 1 www-data adm   0 Jun  7 06:45 access.log      ← 新しい空ファイル
-rw-r----- 1 www-data adm 160 Jun  7 06:45 access.log.1    ← 旧ファイル（delaycompress で未圧縮）
-rw-r----- 1 www-data adm   0 Jun  1 14:05 error.log       ← 空のためローテーションされない（notifempty）
```

> **なぜ `error.log.1` がないのか:** `notifempty` の設定により、
> `error.log` は 0 バイトのためローテーションがスキップされた。

> **なぜ `.gz` がないのか:** `delaycompress` により直前世代（`.1`）は圧縮されない。
> 次のローテーション時に `.1` が `.2.gz` に圧縮される。

2 回目の強制実行で `.gz` を確認するには、まずログに内容を書き込む:

```bash
# nginx にアクセスしてログを生成するか、直接追記する
$ sudo sh -c 'echo "127.0.0.1 - - [07/Jun/2026:07:30:00 +0000] \"GET / HTTP/1.1\" 200 615" >> /var/log/nginx/access.log'
$ sudo logrotate -f /etc/logrotate.d/nginx
$ ls -lh /var/log/nginx/
```

出力例（2 回目の rotate 後）:

```text
-rw-r----- 1 www-data adm   0 Jun  7 06:50 access.log       ← 新しい空ファイル
-rw-r----- 1 www-data adm  68 Jun  7 06:50 access.log.1     ← 直前世代（未圧縮）
-rw-r----- 1 www-data adm 103 Jun  7 06:50 access.log.2.gz  ← 2世代前（圧縮済み）
-rw-r----- 1 www-data adm   0 Jun  1 14:05 error.log
```

`.gz` ファイルの内容を確認するには `zcat`（gzip 圧縮ファイルを展開せずに中身を標準出力へ表示するコマンド。`cat` の gzip 版）を使う:

```bash
$ zcat /var/log/nginx/access.log.2.gz
```

### 18-7. 総合実習: 自作ログをローテーション

第16・17 章で作った `nginx_manager.sh` の cron ログ（`/tmp/cron-nginx-summary.log`）を
ローテーションする設定を作成する。

まずログファイルを用意する:

```bash
$ echo "$(date): nginx manager summary test" >> /tmp/cron-nginx-summary.log
$ cat /tmp/cron-nginx-summary.log
```

`/etc/logrotate.d/nginx-manager` を作成する:

```bash
$ sudo tee /etc/logrotate.d/nginx-manager << 'EOF'
/tmp/cron-nginx-summary.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 vscode vscode
}
EOF
```

dry-run で設定を検証する:

```bash
$ sudo logrotate -d /etc/logrotate.d/nginx-manager
```

強制実行して動作を確認する:

```bash
$ sudo logrotate -f /etc/logrotate.d/nginx-manager
$ ls -lh /tmp/cron-nginx-summary.log*
```

出力例:

```text
-rw-r--r-- 1 vscode vscode   0 Jun  7 07:00 /tmp/cron-nginx-summary.log
-rw-r--r-- 1 vscode vscode  37 Jun  7 07:00 /tmp/cron-nginx-summary.log.1
```

**この章で学んだことのまとめ:**

```text
apt install nginx
  └── /etc/logrotate.d/nginx が自動作成される
        ↓
/etc/cron.daily/logrotate（毎日 cron が実行）
  └── /usr/sbin/logrotate /etc/logrotate.conf
        └── include /etc/logrotate.d/nginx
              ├── daily でローテーション
              ├── compress + delaycompress で世代圧縮
              └── postrotate: nginx に USR1 シグナルを送り新ファイルへ切り替え
```

## よくあるミス

| ミス | 症状 | 正しい対処 |
|:---|:---|:---|
| `delaycompress` なしで `compress` のみ | nginx が旧ファイルに書き込もうとして失敗することがある | `compress` と `delaycompress` を必ずセットで指定する |
| `postrotate` で nginx を通知しない | rotate 後も nginx が旧ファイルへ書き続ける | `invoke-rc.d nginx rotate` で USR1 シグナルを送る |
| cron が停止中で logrotate が実行されない | Codespaces では cron が停止中のため自動実行されない | `sudo logrotate -f` で手動実行する。自動化するには `sudo service cron start` |
| `rotate 0` の設定 | バックアップなしで古いログが即削除される | 必ず `rotate 1` 以上を指定する |
| `/etc/logrotate.d/` のファイルに実行権限を付ける | `run-parts` の対象になり意図しない動作になる可能性がある | logrotate.d の設定ファイルには実行権限は不要（付けない） |

## 類似比較

| 比較軸 | 説明 |
|:---|:---|
| `logrotate -d` vs `logrotate -f` | dry-run（確認のみ・ファイル変更なし）vs 強制実行（実際にローテーション） |
| `rotate N` vs `maxage N` | 世代数での保持（例: `rotate 14`）vs 日数での保持（例: `maxage 30`） |
| `compress` vs `delaycompress` | 直前世代も含めて圧縮 vs 直前世代は圧縮しない（nginx のように書き込み中のケースに必要） |
| `daily` vs `weekly` vs `monthly` | ローテーションの頻度（グローバル設定より個別設定が優先） |
| `postrotate` vs `prerotate` | ローテーション後に実行（nginx への USR1 通知など）vs ローテーション前に実行（前処理） |

## 他OSとの比較

| 操作 | Linux (logrotate) | Windows | macOS |
|:---|:---|:---|:---|
| ログのローテーション | `logrotate` | イベントビューアー（自動管理）・各アプリ依存 | `newsyslog`（BSD 由来） |
| 設定ファイル | `/etc/logrotate.conf`・`/etc/logrotate.d/` | レジストリ・アプリ設定 | `/etc/newsyslog.conf` |
| 圧縮形式 | `compress`（gzip・デフォルト）| アプリ依存 | `compress` / `bzip2` / `zstd` |
| サービスへの通知 | `postrotate` スクリプト | アプリ依存 | `signal` ディレクティブ |
| dry-run 検証 | `logrotate -d` | なし（アプリ依存） | `newsyslog -n` |

## 理解度チェック

1. logrotate を手動で強制実行するオプションはどれか。また、実際には変更せず動作を確認するオプションはどれか。

<details><summary>答え</summary>

強制実行: `sudo logrotate -f /etc/logrotate.d/nginx`
確認のみ（dry-run）: `sudo logrotate -d /etc/logrotate.d/nginx`

`-f` は `--force`（強制）、`-d` は `--debug`（dry-run）の省略形。

</details>

2. `/etc/logrotate.d/nginx` に `compress` と `delaycompress` が両方書かれている理由を説明せよ。

<details><summary>答え</summary>

`compress` だけだと直前世代（`.1`）も即座に `.gz` 圧縮されてしまう。
しかし nginx はローテーション直後もファイルディスクリプタ（FD）で旧ファイルに書き込んでいる可能性があり、
書き込み中のファイルを圧縮すると破損する危険がある。

`delaycompress` を追加することで「直前世代は圧縮しない」ようにし、
`postrotate` で nginx に USR1 シグナルを送って新ファイルへ切り替えさせてから、
次のローテーション時に安全に圧縮する。

</details>

3. `/etc/logrotate.conf` に `weekly` と書かれているのに、nginx のログは毎日ローテーションされる。なぜか。

<details><summary>答え</summary>

`/etc/logrotate.conf` のグローバル設定より、`/etc/logrotate.d/nginx` の個別設定が優先されるためだ。

`/etc/logrotate.d/nginx` に `daily` が明示されているため、
グローバルの `weekly` は nginx には適用されない。
`rotate 4`（グローバル）についても、nginx は `rotate 14` を個別に指定しているため 14 世代保持される。

</details>

4. `postrotate` スクリプトで `invoke-rc.d nginx rotate` を実行しないと、どんな問題が起きるか。

<details><summary>答え</summary>

nginx はログファイルをファイルディスクリプタ（FD）で開いたまま動き続ける。
logrotate がファイル名を `access.log` → `access.log.1` に変更しても、
nginx は古い FD を通して旧ファイル（`access.log.1`）に書き続けてしまう。

その結果、新しい `access.log`（空ファイル）には何も書き込まれず、
アクセスログが旧ファイルに混在し、ローテーションが機能しない状態になる。

`invoke-rc.d nginx rotate` で USR1 シグナルを送ることで、nginx が新しい `access.log` を
開き直し、以降のログが正しく新ファイルへ書き込まれる。

</details>

5. `/etc/logrotate.d/` に置く設定ファイルで、`/etc/crontab` と同様に「ユーザー名」列が必要かどうか。

<details><summary>答え</summary>

必要ない。

`/etc/crontab` は `分 時 日 月 曜日 **ユーザー名** コマンド` の 6 列形式が必要だが、
`/etc/logrotate.d/` の設定ファイルにユーザー名列はない。
操作ユーザーは `create 0640 www-data adm` のように `create` ディレクティブ内で指定する。

logrotate 自体は `sudo` で root として実行されるため、
設定ファイル内にユーザー名列は不要。

</details>

次章では、Linux のセキュリティ強化機構である SELinux・AppArmor の概念と、Codespaces（Debian）で有効な AppArmor のプロファイル確認方法を学びます。

---

| [← 第17章: cron でタスクを自動化する](../chapter-17/README.md) | [全章目次](../README.md) | [第19章: SELinux・AppArmor の概念を知る →](../chapter-19/README.md) |
|:---|:---:|---:|
