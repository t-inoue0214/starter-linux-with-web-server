# 第19章: SELinux・AppArmor の概念を知る

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第11章: パーミッションを管理する（DAC の基礎 — `chmod`/`chown` を理解している）
- 第15章: systemd でサービスを管理する（サービスプロセスの概念を理解している）

## 概要

第11章で学んだ `chmod`/`chown` によるパーミッション管理（DAC）は、
ファイルの所有者が自由にアクセス権を設定できる仕組みだ。
しかし DAC には「root には制限がかけられない」という根本的な限界がある。

この章では DAC を超えた「強制アクセス制御（MAC）」の概念を学ぶ。
業務で広く使われる **RHEL 系の SELinux** を主軸に、
Debian/Codespaces 環境での **AppArmor** も合わせて確認する。

## 手順

### 19-1. DAC の限界 — プロセス侵害のリスク

第11章で学んだ DAC（任意アクセス制御）をおさらいする。

**通常の nginx の動作（DAC のみ）:**

nginx プロセスは `www-data` ユーザーとして動作している。

```text
$ ps aux | grep nginx
www-data   123  0.0  ...  /usr/sbin/nginx -g daemon on; ...
```

> **注:** 本コマンドは nginx 起動中の出力例だ。Codespaces での nginx 起動方法は
> 第15章で確認した `sudo service nginx start` を使う。

`www-data` が読み書きできるファイルは、DAC（`chmod`/`chown`）で制御されている。
これは正常な状態では問題ない。

**nginx のプロセスが乗っ取られた場合:**

```text
【DAC のみの環境で nginx が攻撃者に侵害された場合】

攻撃者は www-data としてコマンドを実行できる。

www-data でできること（DACのみ）:
  /var/log/nginx/ への書き込み    → ○（設計通り）
  /etc/nginx/nginx.conf の読み取り → ○（設定ファイル）
  /etc/passwd の読み取り           → ○（誰でも読めるファイル）
  /tmp に実行ファイルを作成・実行  → ○（条件次第）

→ DAC は「正常な権限の範囲内」でしか保護できない
```

DAC は「正当なユーザーが誤操作しないよう守る」仕組みだ。
「プロセスが乗っ取られた場合の被害を最小化する」には、別の仕組みが必要になる。

### 19-2. MAC とは — 強制アクセス制御とその価値

**MAC（Mandatory Access Control）** は、
システム管理者がポリシーを定義し、プロセスが許可された操作のみを実行できるよう強制する仕組みだ。

| 比較軸 | DAC（任意アクセス制御） | MAC（強制アクセス制御） |
|:---|:---|:---|
| 正式名称 | Discretionary Access Control | Mandatory Access Control |
| 制御主体 | ファイルの所有者 | システムポリシー（管理者が定義） |
| root の制約 | ない（root は何でもできる） | プロセスのコンテキストで縛れる |
| 設定方法 | `chmod`・`chown` | SELinux / AppArmor のポリシー |
| 主な用途 | 一般的なファイル保護 | サーバーの重要プロセス保護 |

**MAC がある環境で nginx が侵害された場合:**

```text
【MAC（SELinux）がある環境で nginx が侵害された場合】

攻撃者は www-data かつ httpd_t コンテキストとして動く。

httpd_t コンテキストで許可されていること:
  /var/log/nginx/*.log への書き込み → ○（ポリシーで許可）
  /var/www/html/ の読み取り         → ○（ポリシーで許可）

httpd_t コンテキストで拒否されること:
  /etc/shadow の読み取り → ✗（MAC がブロック）
  外部への任意接続       → ✗（ポリシー次第でブロック）
  /tmp への実行ファイル作成 → ✗（ポリシー次第でブロック）

→ プロセスが侵害されても、MAC が被害を最小化する
```

**「root がポリシーファイルを変更できるのでは？」**

その通りだ。MAC は「完全無敵の防御」ではない。
MAC の本当の価値は「**プロセス侵害の被害範囲を最小化する**」点にある。

ポリシーファイルの変更には root 権限が必要だが、変更はすべて監査ログに記録される。

```text
監査ログの場所: /var/log/audit/audit.log（RHEL 系）

→ 「誰がいつポリシーを変更したか」が追跡できる
→ 不正な変更を検出しやすい
```

「nginx を侵害し root を取得してポリシーを変更する」という段階的な攻撃には、
より根本的な root 権限管理（sudo の制限・SSH 鍵管理など）で対応する。

### 19-3. SELinux の仕組みを知る（RHEL 系）

業務で RHEL/CentOS/AlmaLinux を使う場合、MAC の実装は **SELinux** だ。

#### SELinux コンテキスト

SELinux はすべてのリソース（ファイル・プロセス）に「**コンテキスト（セキュリティラベル）**」を付ける。
コンテキストは `ユーザー:ロール:タイプ:レベル` の形式で表される。

```text
# RHEL/CentOS での確認コマンド（参照用）
$ ls -Z /var/log/nginx/
system_u:object_r:httpd_log_t:s0 access.log
system_u:object_r:httpd_log_t:s0 error.log

$ ps -Z | grep nginx
system_u:system_r:httpd_t:s0  nginx
```

SELinux で最も重要なのは「**タイプ**」の部分だ。

```text
httpd_t   → nginx などの Web サーバープロセスに付くタイプ
httpd_log_t → Web サーバーのログファイルに付くタイプ
shadow_t  → /etc/shadow に付くタイプ

ポリシー例:
  httpd_t は httpd_log_t に書き込める   → ○ ログ書き込みを許可
  httpd_t は shadow_t を読み取れない    → ✗ /etc/shadow を保護
```

#### SELinux モード

| モード | コマンド | 動作 | 使いどころ |
|:---|:---|:---|:---|
| `enforcing` | `sudo setenforce 1` | ポリシー違反を拒否する | 本番環境 |
| `permissive` | `sudo setenforce 0` | 拒否せずログに記録する | 設定調整中 |
| `disabled` | `/etc/selinux/config` 変更後にリブート | SELinux が機能しない | （非推奨） |

#### SELinux 主要コマンド（RHEL 系・参照用）

```text
# SELinux の現在の状態を確認
$ getenforce
Enforcing

# 詳細な状態を確認
$ sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing

# ファイルのコンテキストを確認（-Z オプション）
$ ls -Z /var/www/html/
unconfined_u:object_r:httpd_sys_content_t:s0 index.html

# コンテキストを変更（一時的）
$ sudo chcon -t httpd_sys_content_t /data/www/index.html

# デフォルトのコンテキストに戻す
$ sudo restorecon -v /data/www/index.html

# デフォルトのコンテキストを永続的に定義
$ sudo semanage fcontext -a -t httpd_sys_content_t "/data/www(/.*)?"
$ sudo restorecon -Rv /data/www/
```

#### RHEL + nginx でよくある SELinux トラブル

**ケース1: nginx を標準以外のポートで起動しようとする**

nginx の設定で `listen 8888;` と書いて起動すると、`enforcing` モードでは失敗する場合がある。

```text
# 症状
$ sudo systemctl start nginx
Job for nginx.service failed.

# 原因の確認（audit ログ）
$ sudo grep nginx /var/log/audit/audit.log | grep denied
type=AVC ... avc: denied { name_bind } ...
              tcontext=system_u:object_r:unreserved_port_t:s0

# 対処: SELinux に 8888 番ポートを nginx が使ってよいと許可する
$ sudo semanage port -a -t http_port_t -p tcp 8888
$ sudo systemctl start nginx  # 再起動
```

**ケース2: nginx のドキュメントルートを変更した場合**

`/data/www/` を nginx のドキュメントルートに設定すると、デフォルトのコンテキストは
`httpd_sys_content_t` ではないため、403 Forbidden エラーを返す可能性がある。

```text
# 症状: ブラウザで 403 Forbidden

# 原因: /data/www/ のコンテキストが httpd_sys_content_t でない
$ ls -Z /data/www/
unconfined_u:object_r:default_t:s0 index.html  ← default_t は nginx からアクセス不可

# 対処: コンテキストを付与する
$ sudo semanage fcontext -a -t httpd_sys_content_t "/data/www(/.*)?"
$ sudo restorecon -Rv /data/www/
$ ls -Z /data/www/
unconfined_u:object_r:httpd_sys_content_t:s0 index.html  ← 修正完了
```

> **覚えておく鉄則:** RHEL 系で nginx が突然 403 を返したときは、
> まず SELinux のコンテキストを疑え。`ls -Z` でコンテキストを確認し、
> `restorecon` で修正するのが定石だ。

### 19-4. Codespaces で AppArmor を確認する（Debian 系）

Debian/Ubuntu 系の Linux では、MAC の実装として **AppArmor** が使われる。
SELinux がコンテキスト（タイプ）で制御するのに対し、
AppArmor は**プログラムのパス**ベースでポリシーを定義する。

#### ライブラリの確認

Codespaces でインストール済みのパッケージを確認する。

```bash
$ dpkg -l | grep -E "apparmor|selinux"
```

出力例:

```text
ii  libapparmor1:amd64  4.1.0-1  amd64  changehat AppArmor library
ii  libselinux1:amd64   3.8.1-1  amd64  SELinux runtime shared libraries
```

ライブラリはインストールされているが、カーネルモジュールは未ロードの状態だ。

#### AppArmor プロファイルディレクトリの確認

```bash
$ ls /etc/apparmor.d/
```

出力例:

```text
local  usr.bin.man
```

```bash
$ ls /etc/apparmor.d/local/
```

出力例:

```text
usr.bin.man
```

`/etc/apparmor.d/` が AppArmor の設定ディレクトリ（SELinux でいうポリシーの保存場所）だ。
`local/` 内のファイルはサイト固有のカスタマイズを追記するための空ファイルだ。

#### AppArmor カーネルモジュールの確認

```bash
$ ls /sys/kernel/security/
```

出力なし（カーネルモジュールが未ロードのため空）。

> **[コンテナ制限] Codespaces 環境での注意**
> GitHub Codespaces は Docker コンテナ内で動作しているため、
> AppArmor カーネルモジュールが無効になっています。
> `aa-status` コマンドも未インストールです。
> 本章では実際のプロファイルファイルを読み解くことで AppArmor の仕組みを理解します。

#### 実際のプロファイルを読む

```bash
$ cat /etc/apparmor.d/usr.bin.man
```

出力例（主要部分・注釈付き。実際のファイルは 80 行以上ある）:

```text
# vim:syntax=apparmor

#include <tunables/global>

/usr/bin/man {
  #include <abstractions/base>

  # man が groff 系ツールを呼ぶときは専用プロファイルを使う
  /usr/bin/troff rmCx -> &man_groff,
  /usr/bin/tbl   rmCx -> &man_groff,

  # man が解凍ツールを呼ぶときは専用プロファイルを使う
  /{,usr/}bin/gzip rmCx -> &man_filter,
  /{,usr/}bin/bzip2 rmCx -> &man_filter,

  # man 自体はファイルシステムへのアクセスを広く許可
  /** mrixwlk,

  deny capability dac_override,       # この能力を使おうとしても拒否
  deny capability dac_read_search,

  signal peer=@{profile_name},

  #include <local/usr.bin.man>        # ローカルカスタマイズを読み込む
}

profile man_groff {
  #include <abstractions/base>
  /usr/bin/troff rm,
  /usr/share/groff/** r,
  /tmp/groff* rw,
}

profile man_filter {
  #include <abstractions/base>
  /** r,
  /var/cache/man/** w,
}
```

**プロファイルの主要な構文:**

| 記法 | 意味 |
|:---|:---|
| `#include <abstractions/base>` | 共通の基本権限セットを取り込む |
| `/path/to/file r,` | ファイルの読み取りを許可 |
| `/path/to/file rw,` | ファイルの読み書きを許可 |
| `/path/to/file mr,` | メモリマップ読み取りを許可（共有ライブラリ等） |
| `/path/** r,` | ディレクトリ以下すべてを読み取り可能 |
| `rmCx -> &man_groff,` | 子プロセスを `man_groff` プロファイルで実行 |
| `deny capability dac_override,` | 特定のカーネル能力（Capability）を明示的に拒否 |

### 19-5. SELinux vs AppArmor — どちらを覚えるべきか

| 項目 | SELinux | AppArmor |
|:---|:---|:---|
| 主な採用ディストリビューション | RHEL, CentOS, Fedora, AlmaLinux | Debian, Ubuntu |
| 制御の単位 | セキュリティコンテキスト（タイプ） | プログラムのパス |
| 設定の難易度 | 高（全リソースにラベルが必要） | 中（パスベースで直感的） |
| モード | `enforcing` / `permissive` / `disabled` | `enforce` / `complain` / `disabled` |
| 主要コマンド | `getenforce`, `sestatus`, `ls -Z`, `chcon`, `semanage` | `aa-status`, `aa-enforce`, `aa-complain` |
| LPIC-1 出題 | 出題あり（概念として） | 出題あり（概念として） |

**どちらを優先するか:**

- 業務で **RHEL/CentOS を使うなら SELinux を優先**して習得する
- Debian/Ubuntu が中心なら AppArmor を習得する
- 「MAC の概念（コンテキスト・モード・ポリシー）」は両者に共通しているため、
  一方を理解すればもう一方も習得しやすい

### 19-6. chapter-20 への橋渡し

この章で学んだ MAC の知識は、次の chapter-20（Nginx ソースビルド）で具体的な意味を持つ。

**ソースビルド nginx と MAC の問題:**

```text
apt でインストールした nginx:
  パス: /usr/sbin/nginx
  Ubuntu では AppArmor プロファイルが /etc/apparmor.d/usr.sbin.nginx に存在する
  RHEL では SELinux の httpd_t コンテキストが自動的に付与される

chapter-20 でソースビルドする nginx:
  パス: /usr/local/nginx/sbin/nginx
  AppArmor プロファイル → 存在しない（MAC の保護なし）
  SELinux コンテキスト  → デフォルトのまま（httpd_t として認識されないことも）
```

ソースビルドは柔軟性が高い一方で、「パッケージが自動で設定してくれるセキュリティ設定」を
自分で用意しなければならない。

**Docker との比較（chapter-22 への伏線）:**

```text
MAC（SELinux/AppArmor）:
  プロセス単位でポリシーを手動定義する
  → 新しいプログラムを導入するたびにポリシーを書く必要がある

Docker:
  コンテナ単位で自動的にセキュリティ境界を設定する
  → Linux Namespace（プロセスから見えるリソースを隔離する仕組み）・
     cgroups（CPU・メモリの使用量を制限するカーネル機能）・
     seccomp（プロセスが呼び出せるシステムコールを制限するカーネル機能）が自動で隔離してくれる
  → デフォルトで seccomp プロファイルと AppArmor プロファイルを自動適用
```

「なぜコンテナが『安全な実行環境』として普及したのか」—
その答えの一端が、ここで見えてくる。

## よくあるミス

| ミス | 症状 | 対処 |
|:---|:---|:---|
| RHEL で `aa-status` を実行 | `command not found` エラー | RHEL は SELinux。`getenforce` を使う |
| `enforcing` モードで設定ミス | nginx が突然起動しなくなる | `permissive` モードで確認後に `enforcing` に戻す |
| ドキュメントルート変更後に SELinux コンテキストを忘れる | 403 Forbidden が返る | `semanage fcontext` + `restorecon` でコンテキストを付与する |
| SELinux を `disabled` にして放置 | MAC の保護がなくなる。再有効化にはリブートが必要 | 本番環境では `enforcing` を維持し `permissive` で調整する |
| `chcon` で変更後に `restorecon` を実行 | コンテキストが元に戻る | `semanage fcontext` で永続定義してから `restorecon` を実行する |

## 類似比較

| 比較軸 | DAC | SELinux（MAC） | AppArmor（MAC） |
|:---|:---|:---|:---|
| 制御主体 | ファイル所有者 | システムポリシー（タイプ） | システムポリシー（パス） |
| root の制約 | なし | プロセスコンテキストで縛れる | プロセスのパスで縛れる |
| 設定コマンド | `chmod`, `chown` | `setenforce`, `chcon`, `semanage` | `aa-enforce`, `aa-complain` |
| 違反ログの場所 | なし | `/var/log/audit/audit.log` | `/var/log/syslog` |
| 主な採用 OS | 全 Linux | RHEL 系 | Debian 系 |

## 他OSとの比較

| 操作 | Linux（RHEL/SELinux） | Linux（Debian/AppArmor） | Windows | macOS |
|:---|:---|:---|:---|:---|
| MAC の仕組み | SELinux（コンテキスト） | AppArmor（パスベース） | MIC / Credential Guard | TCC / SIP |
| プロセス保護 | `httpd_t` コンテキスト | AppArmor プロファイル | Windows Defender | Gatekeeper |
| 設定場所 | `/etc/selinux/`, `semanage` | `/etc/apparmor.d/` | レジストリ・グループポリシー | `システム設定` > `プライバシーとセキュリティ` |
| 違反ログ | `/var/log/audit/audit.log` | `/var/log/syslog` | イベントビューアー | `/var/log/system.log` |

## 理解度チェック

1. DAC（任意アクセス制御）と MAC（強制アクセス制御）の違いを説明してください。
   特に「root の扱い」に着目してください。

<details><summary>答え</summary>

DAC はファイルの所有者が自由にアクセス権を設定できる仕組みで、root はすべての DAC ルールを無視できる。
MAC はシステム管理者が定義したポリシーにより、プロセスの動作を強制的に制限する仕組みで、
root 権限でプロセスを動かしていてもポリシーの範囲外の操作は拒否される。
MAC の目的は「プロセスが侵害された場合の被害範囲を最小化する」ことにある。

</details>

2. RHEL 系 Linux で nginx を起動したところ失敗しました。
   `audit.log` に `avc: denied { name_bind }` と記録されていました。
   どのような原因が考えられますか？また、どのように対処しますか？

<details><summary>答え</summary>

SELinux が nginx の指定ポートへのバインドを拒否している。
`http_port_t` として許可されていないポート番号を nginx の設定に書いた可能性が高い。

対処: `sudo semanage port -a -t http_port_t -p tcp <ポート番号>` で
そのポートを nginx が使用できるよう SELinux に許可を追加し、nginx を再起動する。

</details>

3. SELinux の `enforcing` モードと `permissive` モードの違いは何ですか？
   新しいサーバーを設定する際にはどちらを使うべきですか？

<details><summary>答え</summary>

`enforcing` モードはポリシー違反を実際に拒否し、`permissive` モードは拒否せずに違反をログに記録するだけだ。

新しいサーバーを設定する際は `permissive` モードで動作確認し、
`audit.log` に記録される違反（`avc: denied`）を確認しながらポリシーを調整する。
設定が完成したら `enforcing` モードに戻す。
本番環境で最初から `enforcing` を使うと、設定ミスで即座なサービス停止を招くため注意が必要だ。

</details>

4. `/data/www/` を nginx のドキュメントルートに変更したところ、403 Forbidden が返るようになりました。
   SELinux が有効な RHEL 環境での原因と対処を説明してください。

<details><summary>答え</summary>

`/data/www/` のファイルに付いている SELinux コンテキスト（タイプ）が
`httpd_sys_content_t` でないため、`httpd_t`（nginx プロセスのタイプ）から読み取れない状態になっている。

対処:

```bash
$ sudo semanage fcontext -a -t httpd_sys_content_t "/data/www(/.*)?"
$ sudo restorecon -Rv /data/www/
```

`semanage fcontext` でデフォルトのコンテキストを永続定義し、
`restorecon` で既存ファイルへ適用する。`chcon` は再起動後にリセットされてしまう。

</details>

5. chapter-20 でソースビルドした nginx（`/usr/local/nginx/sbin/nginx`）は、
   `apt install nginx` でインストールした nginx と比べてセキュリティ上どのような違いがありますか？

<details><summary>答え</summary>

`apt install nginx` でインストールした nginx には、パッケージが自動的に AppArmor プロファイル（Debian/Ubuntu 系）
または SELinux コンテキスト（RHEL 系）を設定する。
一方、ソースビルドした nginx（`/usr/local/nginx/sbin/nginx`）にはパスが異なるため
既存の MAC プロファイルが適用されず、MAC による保護がない状態になる。

ソースビルドを本番環境で使う場合は、自分で AppArmor プロファイルを作成するか、
SELinux コンテキストを設定する必要がある。これが chapter-22 の Docker の優位性につながる：
Docker はコンテナ単位で自動的にセキュリティ境界を設定するため、この問題を意識せずに済む。

</details>

次章では、この章で学んだ MAC の概念を念頭に置きながら、nginx をソースコードからビルドし、apt インストールとの違いを実感します。

---

| [← 第18章: logrotate でログを管理する](../chapter-18/README.md) | [全章目次](../README.md) | [第20章: Nginx をソースからビルドする →](../chapter-20/README.md) |
|:---|:---:|---:|
