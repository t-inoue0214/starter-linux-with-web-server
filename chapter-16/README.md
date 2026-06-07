# 第16章: シェルスクリプトを書く

## 前提知識

この章を始める前に、以下の章を完了していること:

- [第07章: 環境変数・入力補完・カラー表示](../chapter-07/README.md)（変数の概念・`export`）
- [第11章: パーミッションを理解する](../chapter-11/README.md)（`chmod +x` でファイルを実行可能にする）
- [第14章: OS ログを読む・書く](../chapter-14/README.md)（`logger` コマンドで syslog に書く）
- [第15章: サービス管理](../chapter-15/README.md)（`service` コマンド・`/etc/init.d/` の構造）

## 概要

スクリプトとは、コマンドを並べた「設計図」ファイルである。chapter-15 で読んだ `/etc/init.d/nginx` も、この章の構文を使って書かれたシェルスクリプトだ。この章を終えると、あのスクリプトが自分で書けるようになる。

chapter-17（cron）では「このスクリプトを定期実行する」、chapter-18（logrotate）では「`postrotate` にスクリプトを書く」という形で、この章の知識が直接使われる。

## 手順

### 16-1. 最初のスクリプト — シバン行と実行権限

作業ディレクトリを作って最初のスクリプトを書く。

```bash
$ mkdir -p ~/scripts
$ cd ~/scripts
```

`nano hello.sh` または `vi hello.sh` を開き、以下を入力して保存する。

```bash
#!/bin/bash
echo "nginx の状態を確認します"
service nginx status
```

1行目の `#!/bin/bash` を **シバン行（shebang）** と呼ぶ。このファイルを bash で実行するという宣言で、省略するとシステムのデフォルトシェル（`/bin/sh`）で実行される。`/bin/sh` は POSIX 準拠の最小シェルであり、bash 固有の構文（`[[ ]]` や `$(( ))` 等）は使えない場合がある。

実行権限を付与して実行する。

```bash
$ chmod +x hello.sh
$ ./hello.sh
```

出力例（nginx が起動中の場合）:

```text
nginx の状態を確認します
nginx is running.
```

> **`./` が必要な理由:** カレントディレクトリ（`.`）は `$PATH` に含まれていないため、スクリプト名だけでは見つからない。`./` を付けることで「ここにあるファイルを実行する」と明示する。

---

### 16-2. 変数・引数・クォーティング

#### 変数

```bash
#!/bin/bash
SERVICE="nginx"
echo "$SERVICE の状態を確認します"
service "$SERVICE" status
```

変数のルール:

- 代入は `VAR=value`（`=` の前後に空白を入れない）
- 参照は `$VAR` または `${VAR}`（波括弧は後に文字が続くとき必須: `${VAR}_log`）
- **必ずダブルクォートで囲む** — スペースを含む値を正しく扱うため

#### 引数

スクリプトに渡された値は位置パラメータで受け取る。

```bash
#!/bin/bash
# check_service.sh — 引数で指定したサービスの状態を確認する
SERVICE="$1"

if [ -z "$SERVICE" ]; then
    echo "使い方: $0 サービス名"
    exit 1
fi

echo "$SERVICE の状態を確認します"
service "$SERVICE" status
```

```bash
$ chmod +x check_service.sh
$ ./check_service.sh nginx
```

| 特殊変数 | 内容 |
|:---|:---|
| `$0` | スクリプト自身のファイル名 |
| `$1` `$2` ... | 第1引数・第2引数 |
| `$#` | 引数の数 |
| `"$@"` | 全引数（各引数を個別のクォートで保持） |

---

### 16-3. 終了コードと条件分岐

#### 終了コード（`$?`）

すべてのコマンドは終了後に **終了コード** を返す。

- `0` — 成功
- `1` 以上 — 失敗（数値は失敗の種類を表す）

```bash
$ service nginx status
$ echo $?   # 0（起動中）または 1（停止中）
```

> **`$?` は次のコマンドを実行すると上書きされる。** 直後に変数へ保存するか、すぐに `if` で使う。

#### `if` 文と条件分岐

```bash
#!/bin/bash
if service nginx status > /dev/null 2>&1; then
    echo "nginx は起動中"
else
    echo "nginx は停止中"
fi
```

`> /dev/null 2>&1` は出力を捨てて終了コードだけを見るイディオムです。

> **`/dev/null` と `2>&1` の読み方**
> `/dev/null` は書き込んだ内容がすべて消える「ゴミ箱」ファイルです。
> Linux では出力先をファイルディスクリプタという番号で管理しており、`1` が**標準出力**（通常のメッセージ）、`2` が**標準エラー出力**（エラーメッセージが流れる別の出力先）を指します。
> `> /dev/null` で標準出力を、`2>&1` で「標準エラー出力も標準出力（`/dev/null`）と同じ場所に向ける」と指定し、すべての出力を捨てています。

#### ファイルテスト演算子

`[ -f ファイルパス ]` でファイルの存在を確認できる。

```bash
#!/bin/bash
MAINTENANCE_FLAG="/var/www/html/maintenance.html"
NGINX_MAINT_CONF="/etc/nginx/nginx-maintenance.conf"

if [ -f "$MAINTENANCE_FLAG" ]; then
    NGINX_VERSION=$(nginx -v 2>&1)
    logger -t nginx-start "メンテナンスモードで起動: $NGINX_VERSION"
    sudo /usr/sbin/nginx -c "$NGINX_MAINT_CONF"
else
    sudo service nginx start
fi
```

`nginx -v` は **標準エラー出力** にバージョンを出力するため、`2>&1` でコマンド置換にキャプチャする（コマンド置換は 16-5 で詳述）。

主なファイルテスト演算子:

| 演算子 | 真になる条件 |
|:---|:---|
| `[ -f パス ]` | 通常ファイルが存在する |
| `[ -d パス ]` | ディレクトリが存在する |
| `[ -x パス ]` | 実行可能ファイルが存在する |
| `[ -z "$VAR" ]` | 変数が空文字列 |
| `[ "$A" = "$B" ]` | 文字列が等しい |
| `[ "$N" -eq 0 ]` | 数値が等しい |
| `!` | 条件を反転（`if ! コマンド; then`） |

---

### 16-4. `case` 文 — 複数の値で分岐する

`if-elif` を複数書く代わりに `case` を使うと、複数の値での分岐が読みやすくなる。

```bash
#!/bin/bash
# nginx_ctrl.sh — start/stop/status/restart を受け付ける
case "$1" in
    start)
        sudo service nginx start
        ;;
    stop)
        sudo service nginx stop
        ;;
    status)
        service nginx status
        ;;
    restart)
        sudo service nginx stop
        sleep 1
        sudo service nginx start
        ;;
    *)
        echo "使い方: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
```

```bash
$ chmod +x nginx_ctrl.sh
$ ./nginx_ctrl.sh status
nginx is running.
$ ./nginx_ctrl.sh restart
Stopping nginx: nginx.
Starting nginx: nginx.
```

> **なぜ `case` を学ぶか:** `/etc/init.d/nginx` の中核は `case "$1" in ...` 構文。chapter-15 で「読んだ」内容が、この構文を知ることで「書ける」ようになる。

`case` の構文ルール:

- 各パターンは `)` で終わる（`start)` など）
- 各節の最後は `;;`（省略すると次の節に **fall-through**（流れ込み）する）
- `*)` はどのパターンにも一致しない場合のデフォルト

---

### 16-5. コマンド置換 — コマンドの出力を変数に代入する

```bash
PID=$(pgrep nginx)
echo "nginx の PID: $PID"
```

`$(コマンド)` の形で、コマンドの標準出力を変数に代入できる。

実用例:

```bash
#!/bin/bash
# nginx の情報を収集して表示する
NGINX_VERSION=$(nginx -v 2>&1)
ACCESS_COUNT=$(wc -l < /var/log/nginx/access.log 2>/dev/null || echo "0")
PID=$(pgrep -x nginx | head -1)

echo "バージョン: $NGINX_VERSION"
echo "アクセス数: $ACCESS_COUNT"
echo "PID:       ${PID:-（停止中）}"
```

出力例（nginx 起動中の場合）:

```text
バージョン: nginx version: nginx/1.26.3
アクセス数: 42
PID:       12345
```

`${PID:-（停止中）}` は変数が空のときデフォルト値を使う書き方（デフォルト値展開）。`pgrep -x nginx` で nginx が見つからない（停止中）場合、`PID` が空になるためデフォルト値が表示される。

---

### 16-6. `for` ループ — 繰り返し処理

nginx のログファイルを一覧表示するスクリプトを書く。

```bash
#!/bin/bash
# log_summary.sh — nginx ログファイルの行数とサイズを表示する
echo "=== nginx ログ一覧 ==="
for LOG_FILE in /var/log/nginx/*.log; do
    if [ -f "$LOG_FILE" ]; then
        LINE_COUNT=$(wc -l < "$LOG_FILE")
        SIZE=$(du -sh "$LOG_FILE" | awk '{print $1}')
        echo "$LOG_FILE: ${LINE_COUNT} 行 / ${SIZE}"
    fi
done
```

```bash
$ chmod +x log_summary.sh
$ ./log_summary.sh
```

出力例:

```text
=== nginx ログ一覧 ===
/var/log/nginx/access.log: 42 行 / 8.0K
/var/log/nginx/error.log: 3 行 / 512
```

> **`awk '{print $1}'` について:** `awk` は空白（スペース・タブ）で区切られた出力の列を取り出すコマンド。`'{print $1}'` は1番目の列を表す。`du -sh` の出力（例: `8.0K  /var/log/nginx/access.log`）からサイズ部分だけを取得するために使っている。

> **ログファイルの読み取り権限について:** `/var/log/nginx/` のファイルは `adm` グループが読み取り可能（`rw-r-----`）。chapter-14 で `adm` グループに追加していない場合は `Permission denied` になる。`sudo usermod -aG adm $USER` を実行してから再ログインすること。

`for VAR in リスト; do ... done` の構文。`/var/log/nginx/*.log` はシェルがグロブ展開してファイルパスのリストに変換する。

---

### 16-7. `while` ループとカウンター — リトライ処理

nginx が応答を返すまで繰り返し確認する「待機スクリプト」は、サービス起動後の確認処理として現場でよく使われる。

```bash
#!/bin/bash
# wait_nginx.sh — nginx が HTTP 応答を返すまで待機する
MAX_RETRIES=10
RETRY_INTERVAL=3
count=0

while [ "$count" -lt "$MAX_RETRIES" ]; do
    if curl -sf http://localhost > /dev/null 2>&1; then
        logger -t wait-nginx "nginx 応答確認 (${count} 回目)"
        echo "nginx が起動しました"
        exit 0
    fi
    count=$((count + 1))
    logger -t wait-nginx "待機中... ($count/$MAX_RETRIES)"
    echo "待機中... ($count/$MAX_RETRIES)"
    sleep "$RETRY_INTERVAL"
done

logger -t wait-nginx "タイムアウト: nginx が応答しませんでした"
echo "エラー: nginx が ${MAX_RETRIES} 回試行しても応答しませんでした"
exit 1
```

```bash
$ chmod +x wait_nginx.sh
$ sudo service nginx stop
$ ./wait_nginx.sh &   # バックグラウンドで待機させる
$ sudo service nginx start
```

> **`&` でバックグラウンド実行:** コマンドの末尾に `&` を付けると、そのプロセスをバックグラウンドで動かしながら、すぐ次のコマンドを入力できる。ここでは `wait_nginx.sh` を待機させながら別のターミナル操作（nginx の起動）を行うために使う。`&` なしで実行すると、スクリプトが返ってくるまでプロンプトが戻らず、nginx を起動できない。

構文のポイント:

| 構文 | 意味 |
|:---|:---|
| `while [ 条件 ]; do ... done` | 条件が真の間ループ |
| `$((count + 1))` | 算術式展開（整数の加算） |
| `sleep N` | N 秒待機 |
| `curl -sf` | `-s`（silent）`-f`（失敗時に非ゼロ終了） |

---

### 16-8. 関数 — 処理をまとめて名前を付ける

関数を使うと、繰り返す処理をひとまとめにして名前を付けられる。

```bash
#!/bin/bash
# nginx の状態確認・起動・停止を関数で整理する

is_running() {
    service nginx status > /dev/null 2>&1
}

start_nginx() {
    if is_running; then
        echo "nginx はすでに起動中です"
        return 0
    fi
    echo "nginx を起動します..."
    sudo service nginx start
}

stop_nginx() {
    if ! is_running; then
        echo "nginx はすでに停止中です"
        return 0
    fi
    echo "nginx を停止します..."
    sudo service nginx stop
}

check_nginx() {
    local version
    version=$(nginx -v 2>&1)
    echo "バージョン: $version"
    if is_running; then
        echo "状態: 起動中"
    else
        echo "状態: 停止中"
    fi
}

# 引数で呼び出す関数を切り替える
case "$1" in
    start)   start_nginx  ;;
    stop)    stop_nginx   ;;
    check)   check_nginx  ;;
    *)       echo "使い方: $0 {start|stop|check}" ; exit 1 ;;
esac
```

```bash
$ chmod +x nginx_functions.sh
$ ./nginx_functions.sh check
バージョン: nginx version: nginx/1.26.3
状態: 起動中
$ ./nginx_functions.sh start
nginx はすでに起動中です
```

`local 変数名` は **関数スコープのローカル変数**。関数の外からは見えない。

---

### 16-9. `set -e` と `source` — 堅牢なスクリプトと複数ファイル構成

#### `set -e` — エラーで即終了

スクリプトの先頭に `set -e` を書くと、コマンドが失敗したとき（終了コード非ゼロのとき）スクリプトが即座に終了する。

```bash
#!/bin/bash
set -e   # いずれかのコマンドが失敗したら即終了

sudo service nginx stop
sudo service nginx start   # ここが失敗すると続きの処理は実行されない
echo "再起動完了"
```

> **注意:** `if コマンド; then` の条件コマンドは `set -e` の影響を受けない。`if` 自体が終了コードを見ているため、正常に機能する。

#### `source` — 別ファイルを読み込む

設定値を別ファイル（`config.sh`）に分離して `source` で読み込む。

```bash
# ~/scripts/config.sh — 設定値を一元管理
export NGINX_LOG_DIR="/var/log/nginx"
export MAINTENANCE_FLAG="/var/www/html/maintenance.html"
export RETRY_MAX=10
export RETRY_INTERVAL=3
```

```bash
#!/bin/bash
# ~/scripts/main.sh — エントリーポイント
set -e
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/config.sh"

echo "ログディレクトリ: $NGINX_LOG_DIR"
```

`$(dirname "$(readlink -f "$0")")` は、スクリプト自身の絶対パスのディレクトリを取得する。スクリプトをどこから呼んでも `config.sh` を確実に見つけられる。

`source` と `./` の違い:

| 実行方法 | 動作 | 変数・関数 |
|:---|:---|:---|
| `source ./config.sh` | 現在のシェルで実行 | 呼び元に引き継がれる |
| `./config.sh` | 子プロセスで実行 | 呼び元には引き継がれない |

---

### 16-10. 総合実習 — `nginx_manager.sh` を書き、`/etc/init.d/nginx` を読み解く

これまでの構文をすべて使って `nginx_manager.sh` を完成させる。

#### Step 1: 作業ディレクトリと設定ファイルを作る

```bash
$ mkdir -p ~/scripts/nginx_manager
$ cd ~/scripts/nginx_manager
```

`nano config.sh` を開き以下を入力して保存する。

```bash
# config.sh — nginx_manager の設定値
export NGINX_LOG_DIR="/var/log/nginx"
export MAINTENANCE_FLAG="/var/www/html/maintenance.html"
export HEALTH_URL="http://localhost"
export RETRY_MAX=10
export RETRY_INTERVAL=2
```

#### Step 2: `nginx_manager.sh` を書く

`nano nginx_manager.sh` を開き以下を入力して保存する。

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/config.sh"

LOG_TAG="nginx-manager"

log() {
    logger -t "$LOG_TAG" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

is_running() {
    service nginx status > /dev/null 2>&1
}

do_start() {
    if [ -f "$MAINTENANCE_FLAG" ]; then
        local version
        version=$(nginx -v 2>&1)
        log "メンテナンスモードで起動: $version"
        sudo service nginx start
    else
        log "通常モードで起動"
        sudo service nginx start
    fi
}

do_stop() {
    if ! is_running; then
        log "nginx はすでに停止中です"
        return 0
    fi
    log "nginx を停止します"
    sudo service nginx stop
}

do_check() {
    local count=0
    log "nginx ヘルスチェック開始 (最大 $((RETRY_MAX * RETRY_INTERVAL)) 秒)"
    while [ "$count" -lt "$RETRY_MAX" ]; do
        if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
            log "ヘルスチェック OK ($count 回目)"
            return 0
        fi
        count=$((count + 1))
        log "待機中... ($count/$RETRY_MAX)"
        sleep "$RETRY_INTERVAL"
    done
    log "タイムアウト: nginx が応答しませんでした"
    return 1
}

do_summary() {
    echo "=== nginx ログ一覧 ==="
    for LOG_FILE in "$NGINX_LOG_DIR"/*.log; do
        if [ -f "$LOG_FILE" ]; then
            local lines size
            lines=$(wc -l < "$LOG_FILE")
            size=$(du -sh "$LOG_FILE" | awk '{print $1}')
            echo "  $LOG_FILE: ${lines} 行 / ${size}"
        fi
    done
}

case "$1" in
    start)    do_start   ;;
    stop)     do_stop    ;;
    restart)  do_stop ; sleep 1 ; do_start ;;
    check)    do_check   ;;
    summary)  do_summary ;;
    *)
        echo "使い方: $0 {start|stop|restart|check|summary}"
        exit 1
        ;;
esac
```

```bash
$ chmod +x nginx_manager.sh
$ bash -n nginx_manager.sh    # 構文チェック（実行しない）
$ ./nginx_manager.sh summary
$ ./nginx_manager.sh check
$ ./nginx_manager.sh restart
```

#### Step 3: `/etc/init.d/nginx` と比較する

```bash
$ cat /etc/init.d/nginx
```

`nginx_manager.sh` で使った構文が `/etc/init.d/nginx` にも登場する。

| `nginx_manager.sh` | `/etc/init.d/nginx` | 役割 |
|:---|:---|:---|
| `#!/bin/bash` | `#!/bin/sh` | シバン行。init.d スクリプトは POSIX sh で書く慣習がある |
| `case "$1" in` | `case "$1" in` | 引数で動作を切り替える |
| `start)` `stop)` | `start)` `stop)` | 各コマンドの処理 |
| `is_running()` | `nginx_status()` | 状態確認を関数化 |
| `log()` で `logger` | `log_daemon_msg` | ログ出力を関数化 |
| `set -e` | `set -e` | エラー時に即終了 |
| `source ./config.sh` | `. /etc/default/nginx` | 別ファイルを読み込む。`.` は `source` の POSIX 互換版 |

`/etc/init.d/nginx` は LSB ヘッダ・`start-stop-daemon` などより複雑な構造を持つが、骨格は同じだ。

---

## よくあるミス

| ミス | 症状・エラーメッセージ | 正しい対処 |
|:---|:---|:---|
| シバン行なし（`#!/bin/bash` を省略） | bash 固有の構文がエラーになる場合がある | 必ず1行目に `#!/bin/bash` を書く |
| `chmod +x` を忘れる | `Permission denied` | `chmod +x スクリプト名` |
| `VAR = value`（`=` の前後に空白） | `VAR: command not found` | `VAR=value`（空白なし） |
| `$?` を直後以外で使う | 別コマンドの終了コードが入っている | コマンドの直後で使うか変数に保存する |
| `"$VAR"` のダブルクォートなし | スペースを含む値が複数の引数に分割される | `"$VAR"` と必ずクォートする |
| `case` の `;;` を忘れる | 次の節に fall-through して意図しない動作 | 各節の最後に必ず `;;` を書く |
| `set -e` + `if` の誤解 | `if コマンド; then` で失敗するとスクリプトが終了すると誤解 | `if` 内の条件コマンドは `set -e` の影響を受けない（正常動作） |
| `source` のパスを固定で書く | スクリプトを別の場所に移動すると壊れる | `$(dirname "$(readlink -f "$0")")` を起点にする |

---

## 類似比較

| 比較軸 | 説明 |
|:---|:---|
| `$()` vs バッククォート（`` ` `` `` ` ``） | どちらもコマンド置換。`$()` はネスト可能で推奨。バッククォートは古い書き方 |
| `[ ]` vs `[[ ]]` | `[ ]` は POSIX sh 互換（`/etc/init.d/` は `sh` で書かれることがある）。`[[ ]]` は bash 拡張でパターンマッチが使えるが POSIX 非互換 |
| `case` vs `if-elif` | 文字列の多分岐は `case` が可読性が高い。数値計算や複合条件は `if-elif` を使う |
| `source ./file.sh` vs `./file.sh` | `source`（または `.`）は現在のシェルで実行し変数・関数を引き継ぐ。`./` は子プロセスで実行するため引き継がない |

---

## 他OSとの比較

| 操作 | Linux (bash) | Windows | macOS |
|:---|:---|:---|:---|
| スクリプト実行 | `./script.sh` | `.bat` / `.ps1` を実行 | `./script.sh` |
| 変数代入 | `VAR=value` | `set VAR=value`（cmd）/ `$VAR = "value"`（PS）| `VAR=value` |
| 条件分岐 | `if [ ]` / `case` | `if ... goto`（cmd）/ `switch`（PS）| `if [ ]` / `case` |
| 別ファイル読み込み | `source ./file.sh` | `call file.bat`（cmd）/ `. ./file.ps1`（PS）| `source ./file.sh` |
| エラー時即終了 | `set -e` | `if errorlevel 1 goto :error`（手動）| `set -e` |

---

## 理解度チェック

1. スクリプトの1行目に書く `#!/bin/bash` は何と呼ばれ、省略するとどうなるか？

<details>
<summary>答え</summary>

**シバン行（shebang）** と呼ばれる。省略すると、システムのデフォルトシェル（多くの場合 `/bin/sh`）で実行される。`/bin/sh` は POSIX 準拠の最小シェルであるため、`[[ ]]` や `$(( ))` などの bash 固有の構文が使えず、エラーになることがある。

</details>

---

2. `VAR=value` と `VAR = value` はどちらが正しいか？ また間違いの場合、どのようなエラーが出るか？

<details>
<summary>答え</summary>

正しいのは `VAR=value`（空白なし）。

`VAR = value` と書くと、シェルは `VAR` というコマンドに `=` と `value` を引数として渡そうとし、`VAR: command not found` のようなエラーが出る。

</details>

---

3. 以下のスクリプトが期待どおりに動かない理由を説明せよ。

```bash
#!/bin/bash
service nginx status
if [ $? -eq 0 ]; then
    echo "起動中"
fi
```

<details>
<summary>答え</summary>

このコード自体は問題なく動作する。ただし `$?` は「直前のコマンドの終了コード」を持つため、`service nginx status` と `if [ $? -eq 0 ]` の間に別のコマンドが入ると、`$?` が上書きされてしまう。

より安全な書き方は、コマンドを直接 `if` の条件に書く:

```bash
if service nginx status > /dev/null 2>&1; then
    echo "起動中"
fi
```

</details>

---

4. `source ./config.sh` と `./config.sh` の実行結果の違いを説明せよ。

<details>
<summary>答え</summary>

- `source ./config.sh`（または `. ./config.sh`）: 現在のシェルプロセス内で実行される。`config.sh` で `export` した変数や定義した関数が、呼び元のシェルに引き継がれる。
- `./config.sh`: 子プロセスとして実行される。`config.sh` 内の変数は子プロセスのスコープに閉じており、呼び元のシェルには影響を与えない。

設定ファイルを読み込む用途では `source` を使う。

</details>

---

5. `/etc/init.d/nginx` を読んで、`case "$1" in` の構文がある。`nginx_ctrl.sh` を自作するとき、`case` の各節の最後に `;;` を書き忘れるとどうなるか？

<details>
<summary>答え</summary>

`;;` を省略すると **fall-through**（次の節への流れ込み）が発生し、意図しない処理が実行される。

例えば `start)` の `;;` を省略すると、`start` を渡したにもかかわらず `stop)` の処理も続けて実行されてしまう。必ず各節の末尾に `;;` を書く。

</details>

---

次章では、この章で書いたシェルスクリプトを定時・定期で自動実行する仕組み（cron・crontab）を学びます。

| [← 第15章: サービス管理（SysVinit 実習 + systemd 説明）](../chapter-15/README.md) | [全章目次](../README.md) | [第17章: cron でタスクを自動化する →](../chapter-17/README.md) |
|:---|:---:|---:|
