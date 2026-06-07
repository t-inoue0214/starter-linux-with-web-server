# 第20章: Nginx をソースからビルドする

## 前提知識

- 第4章: パッケージ管理（`apt install nginx` を実行した。この章でその全工程を手動で再現する）
- 第10章: プロセスを管理する（`make` の並列コンパイルなどに活用できる）
- 第11章: パーミッションを管理する（`sudo` の使い方・インストール先の権限）
- 第15章: systemd でサービスを管理する（`service` コマンドとの違いを理解している）
- 第19章: SELinux・AppArmor の概念を知る（ソースビルド nginx に AppArmor プロファイルが存在しない事実）

## 概要

第4章で実行した `apt install nginx` は、以下の工程をすべて自動で処理していた。

1. ソースコードのダウンロード
2. コンパイル（Debian のビルドサーバーで事前に完了済み）
3. 依存ライブラリの解決と配置
4. バイナリ・設定ファイル・ログディレクトリの設置
5. systemd サービスファイルの登録
6. AppArmor プロファイルの生成

この章では `apt purge nginx` でいったん削除し、上記すべての工程を手動で再現する。
`apt` が隠していた工程を体験することで、Linux でソフトウェアが動く仕組みを理解する。

## 手順

### 20-1. apt purge で nginx を削除する

第4章からずっと使ってきた nginx を完全に削除する。
目的は「削除すること」ではなく、「ゼロから再現するための準備」だ。

現在の nginx を確認する。

```bash
$ nginx -v
nginx version: nginx/1.26.3

$ which nginx
/usr/sbin/nginx
```

nginx と関連パッケージを削除する。`apt remove` は設定ファイルを残すが、`apt purge` は `/etc/nginx/` ごと完全に削除する。

```bash
$ sudo apt purge -y nginx nginx-common
$ sudo apt autoremove -y
```

出力例:

```text
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages will be REMOVED:
  nginx* nginx-common*
0 upgraded, 0 newly installed, 2 to remove and 37 not upgraded.
After this operation, 1085 kB disk space will be freed.
Removing nginx (1.26.3-3+deb13u5) ...
Purging configuration files for nginx (1.26.3-3+deb13u5) ...
Removing nginx-common (1.26.3-3+deb13u5) ...
Purging configuration files for nginx-common (1.26.3-3+deb13u5) ...
Processing triggers for man-db (2.12.1-3) ...
```

削除できたか確認する。

```bash
$ nginx -v
bash: nginx: command not found

$ which nginx
（出力なし）

$ ls /etc/nginx/
ls: cannot access '/etc/nginx/': No such file or directory
```

apt が配置していたファイルがすべて消えた。次のセクションからソースで再現する。

### 20-2. ビルド依存パッケージを確認する

`apt install nginx` は依存ライブラリを自動で解決していた。ソースビルドでは自分で把握してインストールする必要がある。

```bash
$ sudo apt install -y build-essential libpcre2-dev libssl-dev zlib1g-dev
```

インストール済みか確認する。

```bash
$ dpkg -l | grep -E "build-essential|libpcre2-dev|libssl-dev|zlib1g-dev"
```

出力例:

```text
ii  build-essential       12.12               amd64  Informational list of build-essential packages
ii  libpcre2-dev:amd64    10.46-1~deb13u1     amd64  New Perl Compatible Regular Expressions Library
ii  libssl-dev:amd64      3.5.6-1~deb13u1     amd64  Secure Sockets Layer toolkit - development files
ii  zlib1g-dev:amd64      1:1.3.dfsg+...+b1   amd64  compression library - development
```

| パッケージ | 役割 |
|:---|:---|
| `build-essential` | `gcc`・`make` などのコンパイラ一式 |
| `libpcre2-dev` | nginx の URL パターンマッチ（正規表現）に使用 |
| `libssl-dev` | HTTPS（SSL/TLS）に必要 |
| `zlib1g-dev` | HTTP レスポンスの gzip 圧縮に使用 |

> `apt install nginx` はこれらを依存関係として自動でインストールしていた。
> ソースビルドでは自分で明示的にインストールする必要がある。

### 20-3. ソースコードを取得する

nginx.org からソースコードの tarball（圧縮アーカイブ）をダウンロードする。

#### バージョンの確認

nginx.org には「Mainline version」（最新開発版）と「Stable version」（安定版）がある。
本番環境では Stable version を使うのが基本だ。

```bash
$ curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\d+\.\d+\.\d+\.tar\.gz' | head -3
```

出力例:

```text
nginx-1.31.1.tar.gz
nginx-1.30.2.tar.gz
nginx-1.28.3.tar.gz
```

1 番目が Mainline version（奇数のマイナーバージョン: 1.31）、2 番目が Stable version（偶数のマイナーバージョン: 1.30）だ。
この章では Stable version の `nginx-1.30.2` を使う。

#### ダウンロードと展開

作業ディレクトリを作成してダウンロードする。

```bash
$ mkdir ~/nginx-build && cd ~/nginx-build
$ wget https://nginx.org/download/nginx-1.30.2.tar.gz
```

出力例:

```text
--2026-06-07 09:40:00--  https://nginx.org/download/nginx-1.30.2.tar.gz
Resolving nginx.org... 3.125.197.172
Connecting to nginx.org|3.125.197.172|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1350729 (1.3M) [application/octet-stream]
Saving to: 'nginx-1.30.2.tar.gz'
nginx-1.30.2.tar.gz  100%[=========>]  1.29M  1.82MB/s  in 0.7s
'nginx-1.30.2.tar.gz' saved (1350729 bytes)
```

tarball を展開してソースツリーを確認する。

```bash
$ tar xzf nginx-1.30.2.tar.gz
$ cd nginx-1.30.2
$ ls
```

出力例:

```text
CHANGES  CHANGES.ru  CODE_OF_CONDUCT.md  CONTRIBUTING.md  LICENSE
README.md  SECURITY.md  SUPPORT.md  auto  conf  configure  contrib  html  man  src
```

`configure` スクリプトと `src/`（ソースコード本体）が確認できる。

### 20-4. `./configure` でビルドオプションを設定する

`configure` スクリプトはビルドの「設計図」となる `Makefile` を生成するツールだ。
インストール先とモジュールの選択をここで決める。

```bash
$ ./configure \
    --prefix=/usr/local/nginx \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-pcre
```

出力例（要約部分）:

```text
checking for OS
 + Linux 6.8.0-1052-azure x86_64
checking for C compiler ... found
 + using GNU C compiler
 + gcc version: 14.2.0 (Debian 14.2.0-19)
...
Configuration summary
  + using system PCRE2 library
  + using system OpenSSL library
  + using system zlib library

  nginx path prefix: "/usr/local/nginx"
  nginx binary file: "/usr/local/nginx/sbin/nginx"
  nginx configuration file: "/usr/local/nginx/conf/nginx.conf"
  nginx pid file: "/usr/local/nginx/logs/nginx.pid"
  nginx error log file: "/usr/local/nginx/logs/error.log"
  nginx http access log file: "/usr/local/nginx/logs/access.log"
```

| オプション | 意味 |
|:---|:---|
| `--prefix=/usr/local/nginx` | インストール先（apt は `/usr/sbin/nginx` だったが、ここに集約される） |
| `--with-http_ssl_module` | HTTPS（SSL/TLS）対応 |
| `--with-http_v2_module` | HTTP/2 対応 |
| `--with-pcre` | PCRE 正規表現ライブラリを使用 |

configure が完了すると `Makefile` が生成される。

```bash
$ ls Makefile
Makefile
```

> **対比ポイント:** `apt install nginx` のモジュール構成は Debian パッケージが決めていた。
> ソースビルドでは `--with-stream`（TCP プロキシ）の追加や不要モジュールの除外を自由に選択できる。

### 20-5. `make` でコンパイルし `make install` でインストールする

#### コンパイル（`make`）

ソースコードをバイナリに変換する。数分かかるので待つ。

```bash
$ make
```

出力例（最初と最後の部分）:

```text
make -f objs/Makefile
make[1]: Entering directory '/home/vscode/nginx-build/nginx-1.30.2'
cc -c -pipe  -O -W -Wall -Wpointer-arith -Wno-unused-parameter ...
    src/core/nginx.c
...
cc -pipe  -O -W ... objs/nginx
make[1]: Leaving directory '/home/vscode/nginx-build/nginx-1.30.2'
```

> この `make` の数分が、`apt install nginx` では見えなかった工程だ。
> Debian のビルドサーバーが事前にコンパイルし、パッケージに含めて配布していた。

#### インストール（`sudo make install`）

コンパイルしたバイナリを `/usr/local/nginx/` に配置する。root 権限が必要だ。

```bash
$ sudo make install
```

出力例:

```text
make -f objs/Makefile install
make[1]: Entering directory '/home/vscode/nginx-build/nginx-1.30.2'
test -d '/usr/local/nginx' || mkdir -p '/usr/local/nginx'
install -m755 objs/nginx '/usr/local/nginx/sbin/nginx'
install -m644 conf/nginx.conf '/usr/local/nginx/conf/nginx.conf'
cp conf/nginx.conf '/usr/local/nginx/conf/nginx.conf.default'
test -d '/usr/local/nginx/logs' || mkdir -p '/usr/local/nginx/logs'
test -d '/usr/local/nginx/html' || cp -R html '/usr/local/nginx'
make[1]: Leaving directory '/home/vscode/nginx-build/nginx-1.30.2'
```

インストール先を確認する。

```bash
$ ls /usr/local/nginx/
conf  html  logs  sbin

$ ls /usr/local/nginx/sbin/
nginx

$ /usr/local/nginx/sbin/nginx -v
nginx version: nginx/1.30.2
```

### 20-6. ソースビルド nginx を起動して動作確認する

#### 起動

apt でインストールしたときは `/usr/sbin/nginx` だったが、ソースビルドでは `/usr/local/nginx/sbin/nginx` のフルパスで起動する。ポート 80 をバインドするために `sudo` が必要だ。

```bash
$ sudo /usr/local/nginx/sbin/nginx
```

#### プロセス確認

```bash
$ ps aux | grep nginx | grep -v grep
```

出力例:

```text
root    8683  0.0  0.0  13364  2584 ?  Ss  09:56  0:00 nginx: master process /usr/local/nginx/sbin/nginx
nobody  8684  0.0  0.0  15160  4700 ?  S   09:56  0:00 nginx: worker process
```

> **apt nginx との違い:** ワーカープロセスが `www-data` ではなく `nobody` で動作している。
> ソースビルドのデフォルト設定（`/usr/local/nginx/conf/nginx.conf`）では `user` ディレクティブがコメントアウトされており、`nobody` がデフォルトになる。
> 本番環境では `user www-data;` のように変更して運用する。

#### ポート確認

```bash
$ ss -tlnp | grep :80
```

出力例:

```text
LISTEN 0  511  0.0.0.0:80  0.0.0.0:*
```

#### HTTP での動作確認

```bash
$ curl -s http://localhost/ | head -8
```

出力例:

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
```

VS Code の「ポート」タブまたはブラウザで `http://localhost/` を開くと「Welcome to nginx!」ページが表示される。

#### ログの確認

```bash
$ ls /usr/local/nginx/logs/
access.log  error.log  nginx.pid

$ cat /usr/local/nginx/logs/access.log
127.0.0.1 - - [07/Jun/2026:09:56:16 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.14.1"
```

> **ログ場所の違い:** apt nginx は `/var/log/nginx/`（システム標準パス）に配置していた。
> ソースビルドは `--prefix=/usr/local/nginx` で指定した場所の `logs/` に集約される。

> **[コンテナ制限] systemd へのサービス登録について**
> GitHub Codespaces は Docker コンテナ内で動作しているため `systemctl enable nginx` は使用できない。本章では `sudo /usr/local/nginx/sbin/nginx` での直接起動を使用する。実際の RHEL/Ubuntu サーバーでは nginx.service ユニットファイルを作成して `systemctl` で管理する。

参考として、本番サーバーで使用するユニットファイルの例を示す。

```text
# /etc/systemd/system/nginx.service（参照用）
[Unit]
Description=The NGINX HTTP Server (source build)
After=network.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID

[Install]
WantedBy=multi-user.target
```

> **ユニットファイル内のシグナルと変数について:**
> `$MAINPID` は systemd がサービス起動時に自動でセットする変数で、マスタープロセスの PID（プロセス番号）を保持する。シェルスクリプトの変数と同じ記法だが、systemd 専用の仕組みだ。
> `HUP`（SIGHUP）は「設定ファイルを再読み込みせよ」というシグナルで、第18章の `USR1`（ログ再オープン）とは用途が異なる。
> `QUIT` は「現在処理中のリクエストを完了してから止まれ（graceful stop: グレースフルストップ）」というシグナルだ。

### 20-7. apt install との違いを整理する

#### apt install との比較

| 比較軸 | apt install nginx | ソースビルド |
|:---|:---|:---|
| バイナリの場所 | `/usr/sbin/nginx` | `/usr/local/nginx/sbin/nginx` |
| 設定ファイル | `/etc/nginx/nginx.conf` | `/usr/local/nginx/conf/nginx.conf` |
| ログの場所 | `/var/log/nginx/` | `/usr/local/nginx/logs/` |
| ワーカーユーザー | `www-data` | `nobody`（デフォルト設定のまま） |
| モジュール選択 | Debian パッケージが決定済み | `./configure` オプションで選択可能 |
| バージョン指定 | Debian リポジトリの最新 | nginx.org から任意バージョンを選択可能 |
| 依存関係解決 | 自動（apt が処理） | 手動（`libpcre2-dev` などを自分でインストール） |
| systemd 登録 | 自動（パッケージに含まれる） | 手動（ユニットファイルを自分で作成） |
| AppArmor プロファイル | `/etc/apparmor.d/usr.sbin.nginx` が自動生成 | プロファイルなし（第19章の伏線を回収） |

#### ソースビルドのメリット・デメリット

| | 内容 | 具体例 |
|:---|:---|:---|
| **メリット** | バージョンを自由に選べる | Debian リポジトリが 1.26 でも、nginx.org から 1.30 をビルドできる |
| | モジュールを選択できる | `--with-stream` で TCP プロキシ追加、不要モジュールを除外してバイナリ軽量化 |
| | カスタムパッチを当てられる | 自社向け改修や OSS パッチを適用したバイナリを作れる |
| | 最新バージョンをすぐ使える | セキュリティパッチ公開の翌日にビルド・適用できる |
| **デメリット** | 更新を自分で管理しなければならない | `apt upgrade` だけではセキュリティパッチが当たらない |
| | AppArmor プロファイルが自動生成されない | 第19章で学んだ MAC の保護が受けられない |
| | 再ビルドに時間がかかる | バージョンアップのたびに `make` の数分が必要 |

> **chapter-22 への伏線:** Docker はコンテナ単位でバージョン・モジュール・セキュリティ設定をパッケージングできる。
> 「ソースビルドの自由度」を持ちながら「管理コストの高さ」を解消するのがコンテナの価値だ。

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| `configure` 前に依存パッケージが未インストール | `./configure: error: SSL modules require the OpenSSL library.` | `sudo apt install libssl-dev` を実行してから再試行する |
| `make install` を `sudo` なしで実行 | `install: cannot create regular file '/usr/local/nginx/sbin/nginx': Permission denied` | `sudo make install` で実行する |
| ポート 80 を `sudo` なしで起動しようとする | `nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)` | `sudo /usr/local/nginx/sbin/nginx` で起動する |
| バージョン番号を URL にハードコードして古いものを使う | （エラーなし。古いバージョンがインストールされる） | nginx.org で最新 stable を必ず確認する |
| `apt purge` 後に `nginx` コマンドが使えると思い込む | `bash: nginx: command not found` | `/usr/local/nginx/sbin/nginx` のフルパスを使う |

## 類似比較

| 比較軸 | `make install` | `apt install` |
|:---|:---|:---|
| ソース | 自分でダウンロードしたソースコード | Debian パッケージリポジトリ |
| コンパイル | 自分の環境でリアルタイムに実施 | Debian がコンパイル済みのバイナリを配布 |
| バージョン | nginx.org の任意バージョンを選択可能 | Debian リポジトリのバージョンのみ |
| アップデート | tarball を再ダウンロードして再ビルド | `sudo apt upgrade` で自動更新 |
| アンインストール | `sudo rm -rf /usr/local/nginx/` | `sudo apt purge nginx` |
| セキュリティパッチ | 自分で管理（手動ビルドが必要） | Debian が配布（apt upgrade で適用） |

## 他OSとの比較

| 操作 | Linux（Debian/RHEL） | Windows | macOS |
|:---|:---|:---|:---|
| ソースからビルド | `./configure && make && make install` | MSBuild / Visual Studio | `./configure && make && make install`（Homebrew も可） |
| パッケージインストール | `apt install` / `dnf install` | winget / MSI インストーラー | `brew install` |
| バイナリの場所 | `/usr/sbin/` または `/usr/local/` | `C:\Program Files\` | `/usr/local/bin/` |
| ビルドツール | `gcc`・`make`（apt でインストール） | Visual Studio Build Tools | Xcode Command Line Tools |

## 理解度チェック

1. `apt install nginx` と `./configure && make && make install` では、コンパイルのタイミングが異なる。それぞれいつコンパイルされるか説明してください。

<details>
<summary>答え</summary>

`apt install nginx` の場合、Debian のビルドサーバーが事前にコンパイルし、バイナリをパッケージに含めて配布している。`apt install` 実行時にコンパイルは行われない。一方、`./configure && make && make install` の場合は自分の Codespaces 環境でリアルタイムにコンパイルが行われる（`make` の数分がその工程）。

</details>

2. ソースビルドした nginx のバイナリが `/usr/local/nginx/sbin/nginx` に配置されるのはなぜか。どこでこの場所が決まるか答えてください。

<details>
<summary>答え</summary>

`./configure --prefix=/usr/local/nginx` の `--prefix` オプションで決まる。`--prefix` を変えればインストール先を自由に変更できる。`apt install nginx` は Debian パッケージ側で `/usr/sbin/nginx` に固定している。

</details>

3. `sudo apt purge nginx nginx-common` と `sudo apt remove nginx` の違いを説明してください。

<details>
<summary>答え</summary>

`apt remove` はバイナリを削除するが `/etc/nginx/` などの設定ファイルを残す。`apt purge` はバイナリと設定ファイルの両方を削除する。この章では「ゼロから再現する」ために `apt purge` を使った。

</details>

4. ソースビルドした nginx には AppArmor プロファイルが存在しない。これはどのような問題を引き起こす可能性があるか、第19章の内容をもとに説明してください。

<details>
<summary>答え</summary>

AppArmor プロファイルがないと MAC（強制アクセス制御）による保護を受けられない。nginx プロセスが侵害された場合、アクセスを制限できず被害拡大のリスクがある。本番環境でソースビルド nginx を使う場合は、AppArmor プロファイルを手動で作成するか、SELinux のコンテキストを適切に設定する必要がある。

</details>

5. ソースビルドした nginx にセキュリティパッチを適用するには何をすればよいか、手順を説明してください。

<details>
<summary>答え</summary>

1. nginx.org で新しい stable バージョンの tarball をダウンロードする
2. `tar xzf nginx-X.X.X.tar.gz` で展開する
3. `cd nginx-X.X.X` でソースディレクトリへ移動する
4. `./configure` で同じオプションを指定する
5. `make` でコンパイルする
6. 実行中の nginx を停止する（`sudo /usr/local/nginx/sbin/nginx -s stop`）
7. `sudo make install` でバイナリを上書きする
8. `sudo /usr/local/nginx/sbin/nginx` で再起動する

`apt upgrade` のような一発更新はできないため、バージョン管理の手間がかかる。

</details>

次章では、この章で動かしたソースビルド nginx に OpenSSL で作成した自己署名の証明書を組み合わせ、HTTPS 化を設定します。

---

| [← 第19章: SELinux・AppArmor の概念を知る](../chapter-19/README.md) | [全章目次](../README.md) | [第21章: OpenSSL 証明書で HTTPS 化する →](../chapter-21/README.md) |
|:---|:---:|---:|
