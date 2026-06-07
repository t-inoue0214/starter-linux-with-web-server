# 第21章: [オプション] OpenSSL 証明書で HTTPS 化する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第12章: ネットワーク基礎（HTTP=80番ポート・HTTPS=443番ポートの知識）
- 第20章: Nginx をソースからビルドする（`--with-http_ssl_module` 付きでビルド済み）

## 概要

第20章でビルドした nginx は `--with-http_ssl_module` オプションが有効になっている。
この章では OpenSSL（暗号ライブラリ）を使って自己署名の証明書を生成し、nginx に HTTPS を設定するまでの全工程を体験する。

「HTTP は平文通信」「HTTPS は暗号化通信」という違いを実際に手を動かして体験することが目標だ。
また、Let's Encrypt（無料の CA）が行う証明書管理を chapter-22（Docker）でコンテナに任せる伏線でもある。

## 手順

### 21-1. HTTP と HTTPS の違い・TLS の仕組みを理解する

HTTP 通信はリクエスト・レスポンスが**平文（暗号化なし）**で送受信される。
ネットワーク上の第三者が通信を傍受すると、パスワードやクレジットカード番号がそのまま見える。

HTTPS は TLS（Transport Layer Security）プロトコルを使って通信を暗号化する。

TLS ハンドシェイクの流れを概念的に示す:

```text
クライアント                    サーバー
    │                              │
    │ ① ClientHello                │  ← 対応する暗号方式を提示
    │──────────────────────────────►
    │                              │
    │ ② ServerHello + 証明書       │  ← 証明書（公開鍵入り）を送る
    │◄──────────────────────────────
    │                              │
    │ ③ 証明書を検証               │  ← CA の署名を確認
    │                              │
    │ ④ セッション鍵の交換         │  ← 公開鍵暗号（異なる鍵で暗号化・復号する方式）で対称鍵（同じ鍵で暗号化・復号する方式）を共有
    │◄─────────────────────────────►
    │                              │
    │ ⑤ 暗号化通信（対称鍵）       │
    │◄─────────────────────────────►
```

**CA（認証局）と自己署名の証明書の違い:**

| | CA 署名証明書 | 自己署名の証明書（オレオレ証明書） |
|:---|:---|:---|
| 署名者 | 信頼された第三者機関（Let's Encrypt 等） | 自分自身 |
| ブラウザの表示 | 鍵マーク（信頼済み） | 警告（「この接続は安全ではありません」） |
| 用途 | 本番サービス | 開発・学習環境 |
| コスト | 無料（Let's Encrypt）〜有料 | 無料 |

この章では自己署名の証明書を使う。ブラウザ警告が出るのは想定通りの動作だ。

**SSL モジュールが有効になっているか確認する:**

```bash
$ /usr/local/nginx/sbin/nginx -V 2>&1 | grep -o 'with-http_ssl_module'
with-http_ssl_module
```

`with-http_ssl_module` が表示されれば、第20章でビルドした nginx に SSL 機能が組み込まれている。

### 21-2. OpenSSL で秘密鍵と証明書を生成する

**学習目標:** 秘密鍵・CSR・証明書の 3 ファイルの関係を理解し、`openssl` コマンドで生成できる。

**openssl のバージョンを確認する:**

```bash
$ openssl version
OpenSSL 3.5.6 7 Apr 2026 (Library: OpenSSL 3.5.6 7 Apr 2026)
```

**作業ディレクトリ（nginx の設定ディレクトリ）に移動する:**

```bash
$ cd /usr/local/nginx/conf
```

**Step 1: 秘密鍵を生成する（AES-256 で暗号化・パスフレーズあり）:**

```bash
$ sudo openssl genrsa -aes256 -out server.key 2048
Enter PEM pass phrase:（任意のパスフレーズ＝秘密の文字列を入力・画面には表示されない）
Verifying - Enter PEM pass phrase:（同じパスフレーズを再入力）
```

> `-aes256` は秘密鍵自体を AES-256 で暗号化するオプション。
> パスフレーズを設定することで、鍵ファイルが漏洩しても単体では悪用されにくくなる。
> `2048` はビット数（鍵の強度）。数字はオプションの後ろに書く。

**Step 2: CSR（証明書の署名要求）を生成する:**

CSR は「この公開鍵で証明書を作ってほしい」というリクエストファイルだ。
本番環境では CA に提出するが、今回は自己署名（自分で署名）するために使う。

```bash
$ sudo openssl req -new \
    -key server.key \
    -out server.csr \
    -subj "/C=JP/ST=Tokyo/O=Learning/CN=localhost"
Enter pass phrase for server.key:（Step 1 のパスフレーズを入力）
```

| オプション | 意味 |
|:---|:---|
| `-key server.key` | 秘密鍵を指定 |
| `-out server.csr` | CSR の出力先 |
| `-subj "/C=JP/..."` | 証明書に埋め込む組織情報（`-subj` で対話入力を省略） |

**SAN 設定ファイルを作成する:**

SAN（Subject Alternative Name）は証明書が有効なドメイン・IP アドレスを列挙する拡張情報だ。
Chrome 58（2017年）以降、SAN がない証明書は `NET::ERR_CERT_COMMON_NAME_INVALID` エラーになる。

```bash
$ printf "subjectAltName=DNS:localhost,IP:127.0.0.1" \
    | sudo tee /usr/local/nginx/conf/san.cnf
subjectAltName=DNS:localhost,IP:127.0.0.1
```

**Step 3: CSR に自己署名して証明書を生成する（san.cnf を使用）:**

```bash
$ sudo openssl x509 -req -days 365 \
    -in server.csr \
    -signkey server.key \
    -out server.crt \
    -extfile /usr/local/nginx/conf/san.cnf
Enter pass phrase for server.key:（Step 1 のパスフレーズを入力）
Certificate request self-signature ok
subject=C=JP, ST=Tokyo, O=Learning, CN=localhost
```

`Certificate request self-signature ok` が表示されれば証明書の生成成功だ。

**生成されたファイルを確認する:**

```bash
$ sudo ls -la /usr/local/nginx/conf/server.* /usr/local/nginx/conf/san.cnf
-rw-r--r-- 1 root root   41 Jun  7 10:31 /usr/local/nginx/conf/san.cnf
-rw-r--r-- 1 root root 1212 Jun  7 10:31 /usr/local/nginx/conf/server.crt
-rw-r--r-- 1 root root  956 Jun  7 10:31 /usr/local/nginx/conf/server.csr
-rw------- 1 root root 1886 Jun  7 10:31 /usr/local/nginx/conf/server.key
```

**各ファイルの役割:**

| ファイル | 役割 | 公開・秘密 |
|:---|:---|:---|
| `server.key` | 秘密鍵（署名・復号に使う。絶対に漏らしてはいけない） | **秘密** |
| `server.csr` | 証明書の署名要求（自己署名後は不要。削除してもよい） | どちらでも可 |
| `server.crt` | 証明書（公開鍵と組織情報入り。クライアントに送る） | **公開** |
| `san.cnf` | SAN 設定ファイル（証明書生成時のみ使用） | どちらでも可 |

> **`server.key` のパーミッション:** `-rw-------`（root のみ読み書き可能）。
> nginx は root で起動するため問題ない。`chmod 644` などで権限を広げないこと。

### 21-3. nginx.conf に HTTPS サーバーブロックを追加する

**学習目標:** nginx の設定ファイルに SSL ブロックを追記し、`-t` で検証・reload できる。

**パスフレーズファイルを作成する:**

パスフレーズ付き秘密鍵を使う場合、nginx の起動・リロードのたびにパスフレーズが必要になる。
`ssl_password_file` ディレクティブでパスフレーズを読み取るファイルを指定することで、
自動化された環境でも nginx を起動できる。

```bash
# パスフレーズを 1 行だけ書いたファイルを作成する（パスフレーズの部分は実際に設定した値に変える）
$ printf 'あなたのパスフレーズ' | sudo tee /usr/local/nginx/conf/ssl_pass.txt > /dev/null
$ sudo chmod 600 /usr/local/nginx/conf/ssl_pass.txt
```

> **`ssl_pass.txt` の権限:** `chmod 600` で root のみ読み書き可能にする。
> このファイルが漏洩するとパスフレーズが露出するため、取り扱いに注意する。

**`/usr/local/nginx/conf/nginx.conf` を開いて HTTPS サーバーブロックを追加する:**

既存の `http { ... }` ブロック内の末尾（最後の `}` の直前）に追記する。

```nginx
    # HTTPS server
    server {
        listen       443 ssl;
        server_name  localhost;

        ssl_certificate      /usr/local/nginx/conf/server.crt;
        ssl_certificate_key  /usr/local/nginx/conf/server.key;
        ssl_password_file    /usr/local/nginx/conf/ssl_pass.txt;

        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
```

| ディレクティブ | 意味 |
|:---|:---|
| `listen 443 ssl;` | ポート 443 で SSL/TLS を受け付ける |
| `ssl_certificate` | 証明書ファイルのパス（公開される） |
| `ssl_certificate_key` | 秘密鍵ファイルのパス（絶対に公開しない） |
| `ssl_password_file` | 秘密鍵のパスフレーズが書かれたファイル |

**設定ファイルの構文テストを行う:**

```bash
$ sudo /usr/local/nginx/sbin/nginx -t
nginx: the configuration file /usr/local/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/nginx/conf/nginx.conf test is successful
```

**設定を反映する:**

```bash
# nginx が起動中の場合は reload（既存の接続を維持したまま設定を切り替える）
$ sudo /usr/local/nginx/sbin/nginx -s reload

# nginx が停止していた場合は起動
$ sudo /usr/local/nginx/sbin/nginx
```

**ポートを確認する（80 と 443 が両方 LISTEN になっていること）:**

```bash
$ ss -tlnp | grep ':80\|:443'
LISTEN 0      511          0.0.0.0:443        0.0.0.0:*
LISTEN 0      511          0.0.0.0:80         0.0.0.0:*
```

### 21-4. HTTPS で動作確認する

**学習目標:** `curl -k` で HTTPS 接続を確認し、ブラウザ警告の理由を説明できる。

**`curl -k` で HTTPS アクセスする:**

```bash
# -k: 自己署名の証明書を無視して接続（本番では -k は使わない）
$ curl -k https://localhost/ | head -5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
```

**`-v` でハンドシェイクの詳細を確認する:**

```bash
$ curl -kv https://localhost/ 2>&1 | grep -E "SSL connection|subject:|issuer:|expire date:|HTTP/"
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519MLKEM768 / RSASSA-PSS
*  subject: C=JP; ST=Tokyo; O=Learning; CN=localhost
*  expire date: Jun  7 10:31:57 2027 GMT
*  issuer: C=JP; ST=Tokyo; O=Learning; CN=localhost
* using HTTP/1.x
< HTTP/1.1 200 OK
```

| フィールド | 確認内容 |
|:---|:---|
| `TLSv1.3` | 最新の TLS バージョンを使用 |
| `subject` | 証明書の発行先（サーバー情報） |
| `issuer` | 証明書の署名者。自己署名のため `subject` と同じ |
| `expire date` | 有効期限（365日後） |

**ブラウザ警告について:**

Codespaces の「ポート」タブからポート 443 を公開してブラウザでアクセスすると、
「この接続は安全でない」という警告が表示される。
これは自己署名の証明書が信頼された CA に署名されていないためで、**想定通りの動作**だ。

「詳細設定 → localhost にアクセスする（安全でない）」で続行できる。

> **本番環境での証明書管理:**
> Let's Encrypt は無料で CA 署名済み証明書を発行する。
> chapter-22（Docker）では Certbot コンテナが証明書の取得・自動更新を管理する例を紹介する。
> 「毎年手動で証明書を更新する手間」をコンテナが解消する具体例になる。

### 21-5. 証明書の内容を確認する

**学習目標:** `openssl x509` コマンドで証明書のメタデータを読み取れる。

```bash
$ openssl x509 -noout -text -in /usr/local/nginx/conf/server.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            07:db:61:ac:ec:02:b8:03:c8:b7:51:bc:b1:28:c7:a1:2c:22:98:ec
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=JP, ST=Tokyo, O=Learning, CN=localhost
        Validity
            Not Before: Jun  7 10:31:57 2026 GMT
            Not After : Jun  7 10:31:57 2027 GMT
        Subject: C=JP, ST=Tokyo, O=Learning, CN=localhost
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
        X509v3 extensions:
            X509v3 Subject Alternative Name:
                DNS:localhost, IP Address:127.0.0.1
```

**確認すべきポイント:**

| フィールド | 確認内容 |
|:---|:---|
| `Issuer` | 「誰が署名したか」。自己署名のため `Subject` と同じ |
| `Validity` | 有効期限（`Not After` が 365日後になっていること） |
| `Subject Alternative Name` | `DNS:localhost` と `IP Address:127.0.0.1` が含まれていること |
| `Signature Algorithm` | `sha256WithRSAEncryption`（SHA-256〔ハッシュ関数〕と RSA〔公開鍵の暗号方式〕を組み合わせた署名アルゴリズム） |

> **`Issuer` と `Subject` が同じ理由:**
> 自己署名の証明書は「自分が発行して自分が署名した証明書」だ。
> CA 署名証明書では `Issuer` が Let's Encrypt 等になる。

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| `server` ブロックを `http {}` の外に書く | `nginx: [emerg] "server" directive is not allowed here` | `server {}` は `http {}` の内側に書く |
| 証明書パスに相対パスを使う | `ssl_certificate ... no such file` | `/usr/local/nginx/conf/server.crt` のように絶対パスで書く |
| `curl -k` なしでアクセス | `curl: (60) SSL certificate problem: self-signed certificate` | 自己署名の証明書には必ず `-k` を付ける |
| SAN なしで証明書を生成 | Chrome で `NET::ERR_CERT_COMMON_NAME_INVALID` | `san.cnf` を用意して `-extfile san.cnf` を付けて再生成する |
| `ssl_pass.txt` の権限が広すぎる | `nginx: [warn] "ssl_password_file" ... permission problem` | `chmod 600 ssl_pass.txt` で root のみ読み取り可能にする |
| パスフレーズを忘れる | `nginx: [emerg] cannot load certificate key ... bad password read` | パスフレーズを必ずメモしておく。忘れた場合は鍵を作り直す |

## 類似比較

| 比較軸 | `openssl genrsa -aes256` | `openssl genrsa`（パスフレーズなし） |
|:---|:---|:---|
| 鍵ファイルの状態 | AES-256 で暗号化（ファイルが漏洩しても安全） | 平文（ファイルが漏洩すると即座に悪用可能） |
| nginx 起動時 | パスフレーズが必要（`ssl_password_file` で自動化） | パスフレーズ不要（即座に起動できる） |
| 用途 | セキュリティを重視する環境 | 開発・テスト環境 |

| 比較軸 | 自己署名の証明書 | Let's Encrypt（ACME） |
|:---|:---|:---|
| 署名者 | 自分自身 | 信頼された CA（認証局） |
| コスト | 無料 | 無料 |
| 有効期限 | 任意（今回は 365日） | 90日（自動更新可能） |
| ブラウザ | 警告が出る | 信頼済み（警告なし） |
| 用途 | 開発・学習 | 本番サービス |

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| 証明書の生成 | `openssl genrsa` + `openssl req` + `openssl x509` | `New-SelfSignedCertificate`（PowerShell）または openssl | `openssl`（Homebrew でインストール）または Keychain Access |
| 証明書のインストール（信頼済みに） | ブラウザやシステムの CA ストアに追加 | 証明書マネージャー（certmgr.msc） | キーチェーンアクセス |
| HTTPS サーバー設定 | nginx.conf を手動編集 | IIS マネージャー（GUI） | Apache/nginx の設定ファイル |
| Let's Encrypt | Certbot（apt または Docker） | win-acme | Certbot（Homebrew） |

## 理解度チェック

1. HTTP と HTTPS の通信の違いを説明してください。
   特に「傍受された場合」に何が起きるかを含めて答えてください。

<details><summary>答え</summary>

HTTP は通信内容が平文（暗号化なし）で送受信される。ネットワーク上の第三者が通信を傍受すると、
パスワードや個人情報がそのまま見える。

HTTPS は TLS で通信を暗号化するため、傍受されても内容を解読できない。
「① クライアントとサーバーが鍵を交換 → ② 共有した鍵で通信を暗号化」という流れで実現する。

</details>

2. 今回生成した `server.key`・`server.csr`・`server.crt` の 3 ファイルはそれぞれ何のためのファイルですか？

<details><summary>答え</summary>

- `server.key`: 秘密鍵。データの署名・復号に使う。絶対に公開してはいけない。
- `server.csr`: 証明書の署名要求。「この公開鍵で証明書を作ってほしい」というリクエストファイル。
  本番環境では CA に提出する。自己署名後は不要。
- `server.crt`: 証明書。公開鍵と組織情報が CA（今回は自分）の署名で保護されたファイル。
  クライアントに送られ、接続先の正当性を証明する。

</details>

3. 自己署名の証明書を使うと、ブラウザが警告を表示するのはなぜですか？
   CA 署名証明書との違いも含めて答えてください。

<details><summary>答え</summary>

自己署名の証明書は「信頼された第三者機関（CA）による署名」がない。
ブラウザは「この証明書を信頼してよいか」を CA の署名で確認するが、
自己署名の証明書は自分自身で署名しているため「誰が保証したか分からない」と判断して警告を表示する。

CA 署名証明書（Let's Encrypt 等）は信頼された CA が「このサーバーは確かに本人だ」と署名しているため、
ブラウザは警告なしに接続できる。

</details>

4. `ssl_password_file` ディレクティブを設定する目的は何ですか？
   設定しない場合と比較して答えてください。

<details><summary>答え</summary>

`ssl_password_file` はパスフレーズ付き秘密鍵のパスフレーズをファイルから自動的に読み取るディレクティブ。

**設定しない場合:** nginx の起動・リロードのたびに対話的なパスフレーズ入力が必要になる。
スクリプトや自動再起動（サーバー再起動後）でパスフレーズが入力できず、nginx が起動できない。

**設定した場合:** パスフレーズをファイルに保存しておくことで自動起動・リロードが可能になる。
ただし `ssl_pass.txt` の権限を `600`（root のみ読み書き可能）にして管理する必要がある。

</details>

5. `openssl x509 -noout -text -in server.crt` の出力で「`Issuer` と `Subject` が同じ」になっているのはなぜですか？

<details><summary>答え</summary>

自己署名の証明書は「自分自身が署名者になっている」からだ。

- `Subject`: 証明書が誰（どのサーバー）のものかを示す
- `Issuer`: 誰が署名（発行）したかを示す

CA 署名証明書では `Issuer` が「Let's Encrypt Authority X3」のような CA 名になる。
自己署名の証明書は自分自身が署名者なので `Issuer` = `Subject` になる。

</details>

次章では、この章で体験した HTTPS 設定・証明書管理をコンテナ（Docker）に任せることで、手動作業との差を実感します。

---

| [← 第20章: Nginx をソースからビルドする](../chapter-20/README.md) | [全章目次](../README.md) | [第22章: Docker で全部まとめて自動化する →](../chapter-22/README.md) |
|:---|:---:|---:|
