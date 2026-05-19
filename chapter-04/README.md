# 第4章: パッケージ管理

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第2章: 基本コマンドを使いこなす
- 第3章: ディレクトリ構成を知る

---

## 概要

Linux のソフトウェア管理には「パッケージ管理システム」があります。
Windows の「アプリストア」や macOS の「Homebrew」と同じ考え方で、コマンド1つでソフトウェアのインストール・削除・更新ができます。
この章では Debian 系 Linux 標準の `apt` と `dpkg` を使い、パッケージ管理の全体像を体験します。
第3章の予告通り、`tree` コマンドもここでインストールします。

---

## 手順

### 4-1. パッケージとは — ソフトウェアの「梱包箱」

Linux でソフトウェアを配布するときの単位を**パッケージ**と言います。
Debian 系 Linux では `.deb` という形式のファイルを使います。

> **「パッケージ」とは?**
> ソフトウェア本体（バイナリ）・設定ファイルのひな型・マニュアル・依存関係の情報をひとまとめにしたファイルです。
> Windows の `.exe` インストーラーや macOS の `.app` に相当します。

パッケージ管理には3つの概念があります。

| 概念 | 説明 | 例 |
|:---|:---|:---|
| **パッケージ** | ソフトウェアの梱包箱（`.deb` ファイル） | `tree_2.2.1-1_arm64.deb` |
| **リポジトリ** | パッケージを配布するサーバー | `http://deb.debian.org/debian` |
| **依存関係** | 動作に必要な他のパッケージ | `vim` は `libc6` に依存する |

#### apt と dpkg の役割分担

Linux のパッケージ管理ツールには高レベルと低レベルの2種類があります。

```text
apt（高レベル）: 依存関係を自動解決 → リポジトリからダウンロード → dpkg を呼び出す
dpkg（低レベル）: .deb ファイルを直接インストール・管理する
```

日常的な操作は `apt` を使います。`dpkg` はパッケージの調査や問題の診断に使います。

> **`apt` と `apt-get` について**
> ネット上のドキュメントや古いチュートリアルでは `sudo apt-get install vim` のように `apt-get` が使われています。
> `apt-get` は `apt` の前身で、2014年以前から使われてきたツールです。`apt` は `apt-get` をより使いやすく改良した現代版です。
> コマンドの対応: `apt install` ≒ `apt-get install` / `apt search` ≒ `apt-cache search` / `apt show` ≒ `apt-cache show`
> シェルスクリプト内では `apt-get` が推奨されます（`apt` の WARNING にある通り、将来の互換性が保証されないため）。
> 検索で `apt-get` を見かけたら、基本的に `apt` に読み替えて問題ありません。

---

### 4-2. リポジトリを更新する

`apt` はパッケージを探すために「どのリポジトリに何があるか」のリストを手元に保持しています。
まずこのリストを最新化します。

```bash
$ sudo apt update
Hit:1 http://deb.debian.org/debian trixie InRelease
Hit:2 http://deb.debian.org/debian trixie-updates InRelease
Hit:3 http://deb.debian.org/debian-security trixie-security InRelease
Reading package lists...
Building dependency tree...
Reading state information...
55 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

| 表示 | 意味 |
|:---|:---|
| `Hit:` | リストに変更なし（最新の状態） |
| `Get:` | 新しいリストをダウンロードした |
| `Ign:` | 無視（差分なし等） |

> **`apt update` と `apt upgrade` の違い**
> `apt update` はリストの更新のみで、実際のパッケージは変更しません。
> `apt upgrade` は手元のパッケージを最新バージョンに更新します。
> `upgrade` はダウンロードに時間がかかるため、この章では `update` のみ実行します。

#### リポジトリの設定ファイルを見る

どのリポジトリを参照するかは設定ファイルで管理されています。
Debian trixie（この Codespaces 環境）では deb822 形式の設定ファイルを使います。

```bash
$ cat /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
```

| フィールド | 意味 | 例 |
|:---|:---|:---|
| `Types` | パッケージ種別（`deb` = バイナリ） | `deb` |
| `URIs` | リポジトリの URL | `http://deb.debian.org/debian` |
| `Suites` | ディストリビューション名とバリアント | `trixie`, `trixie-updates` |
| `Components` | ライセンス区分（`main` = 自由ソフトウェア） | `main` |
| `Signed-By` | パッケージの署名検証に使う鍵 | `/usr/share/keyrings/...pgp` |

> **従来の一行形式（旧スタイル）**
> 古い Debian や多くのドキュメントでは `/etc/apt/sources.list` に一行形式で記述します。
> `deb http://deb.debian.org/debian trixie main`
> 意味は deb822 形式と同じです。どちらの形式も広く使われています。

#### Suites と Components を理解する

設定ファイルの `Suites` と `Components` は、「どのバージョンの・どの種類のパッケージを使うか」を決める重要なフィールドです。

**`apt-cache policy` でリポジトリ全体を確認する**

現在参照しているリポジトリの一覧とその優先度を確認できます。

```bash
$ apt-cache policy
Package files:
 100 /var/lib/dpkg/status
     release a=now
 500 http://deb.debian.org/debian-security trixie-security/main arm64 Packages
     release v=13,o=Debian,a=stable-security,n=trixie-security,l=Debian-Security,c=main,b=arm64
     origin deb.debian.org
 500 http://deb.debian.org/debian trixie-updates/main arm64 Packages
     release v=13-updates,o=Debian,a=stable-updates,n=trixie-updates,l=Debian,c=main,b=arm64
     origin deb.debian.org
 500 http://deb.debian.org/debian trixie/main arm64 Packages
     release v=13.5,o=Debian,a=stable,n=trixie,l=Debian,c=main,b=arm64
     origin deb.debian.org
```

各行の `n=trixie` が Suite 名、`c=main` が Component 名です。数値（`500`、`100`）は優先度で、高いほど優先されます。

**Suites の選び方**

Suite はディストリビューションの「バージョン名」です。コード名（`trixie`）とエイリアス（`stable`）の2種類があります。

| Suite | 意味 | 使う場面 |
|:---|:---|:---|
| `trixie` | Debian 13（コード名で固定） | 本番・学習環境。メジャーアップグレードが不意に起きない |
| `stable` | 現在の安定版（エイリアス） | 常に最新の安定版を追いかけたい場合 |
| `trixie-updates` | セキュリティ以外の重要な更新 | 通常は `trixie` と一緒に設定する |
| `trixie-security` | セキュリティ修正のみ | 必ず含める（`debian-security` リポジトリで提供） |
| `testing` | 次期リリース候補 | 新しいパッケージを試したい開発環境 |
| `unstable`（sid） | 常に最新開発版 | Debian 開発者以外には非推奨 |

> **コード名 vs エイリアスの使い分け**
> `stable` を指定すると、次のリリース（Debian 14 など）が出たとき、`apt upgrade` で自動的に移行します。
> `trixie` を指定すれば、明示的に書き換えるまで Debian 13 のままです。
> 業務サーバーでは `trixie` のようにコード名で固定するのが一般的です。

**Components の選び方**

Component はパッケージの「ライセンス区分」です。

| Component | 内容 | 追加が必要になる典型例 |
|:---|:---|:---|
| `main` | DFSG 準拠の完全自由ソフトウェア | デフォルト。通常はこれだけで十分 |
| `contrib` | 自由ソフトだが非自由なソフトウェアに依存する | Steam（ゲームプラットフォーム）など |
| `non-free` | プロプライエタリ（非自由）ソフトウェア | NVIDIA GPU ドライバなど |
| `non-free-firmware` | 非自由なハードウェアファームウェア | Wi-Fi・Bluetooth ドライバなど |

> **DFSG（Debian フリーソフトウェアガイドライン）とは?**
> ソフトウェアが「自由ソフトウェア」かどうかを判断する Debian の基準です。
> `main` に入るためには、ソースコードの公開・改変・再配布が自由でなければなりません。

**パッケージがどの Component にあるか調べる**

`apt-cache show` の `Section` フィールドでコンポーネントを確認できます。

```bash
$ apt-cache show tree 2>/dev/null | grep Section
Section: utils
```

`Section: utils` の場合、ドット（`.`）がないので `main` コンポーネントに属します。
`non-free` や `contrib` のパッケージは `Section: non-free/utils` のようにプレフィックスが付きます。

```bash
$ apt-cache madison tree
      tree |    2.2.1-1 | http://deb.debian.org/debian trixie/main arm64 Packages
```

`apt-cache madison` はパッケージがどのリポジトリのどの Suite・Component に存在するかを一行で確認できます。
`trixie/main` の部分がそのまま Suite と Component を示しています。

> **パッケージが見つからないときの調べ方**
> `apt search <パッケージ名>` で出てこない場合は、`non-free` や `contrib` にある可能性があります。
> Debian 公式のパッケージ検索サイト `https://packages.debian.org` でパッケージ名を検索すると、
> Suite・Component・対応アーキテクチャを一覧で確認できます。

---

### 4-3. パッケージを検索・確認する

#### apt search — パッケージを検索する

第3章で予告した `tree` コマンドを検索してみましょう。
まず `apt search tree` をそのまま実行すると、名前や説明文に "tree" を含む多数のパッケージが表示されます。

```bash
$ apt search tree 2>/dev/null | head -6
Sorting...
Full Text Search...
ack/stable 3.8.1-1 all
  grep-like program specifically for large source trees
altree/stable 1.3.2-2+b4 arm64
  program to perform phylogeny-based association and localization analysis
```

`apt search` はパッケージ名だけでなく説明文も含めて検索するため、多数の結果が出ます。
パッケージ名が `tree` で始まるものだけに絞るには `grep` を使います。

```bash
$ apt search tree 2>/dev/null | grep "^tree/"
tree/stable 2.2.1-1 arm64
  displays an indented directory tree, in color
```

> **`2>/dev/null` とは?**
> 第2章で学んだリダイレクトの応用です。`apt search` は `WARNING: apt does not have a stable CLI interface.` という警告を標準エラー出力（stderr）に出します。
> `2>/dev/null` でその警告を捨て、検索結果だけを表示しています。

#### apt show — パッケージの詳細情報を確認する

```bash
$ apt show tree 2>/dev/null
Package: tree
Version: 2.2.1-1
Priority: optional
Section: utils
Maintainer: Florian Ernst <florian@debian.org>
Installed-Size: 173 kB
Depends: libc6 (>= 2.38)
Download-Size: 57.9 kB
Description: displays an indented directory tree, in color
```

`Depends: libc6 (>= 2.38)` は依存関係です。`tree` を使うには `libc6` バージョン 2.38 以上が必要で、`apt` が自動的に解決します。

#### apt list --installed — インストール済みパッケージを一覧する

```bash
$ apt list --installed 2>/dev/null | head -10
Listing...
adduser/stable,now 3.152 all [installed,automatic]
apt/stable,now 3.0.3 arm64 [installed,automatic]
apt-utils/stable,now 3.0.3 arm64 [installed]
bash/now 5.2.37-2+b5 arm64 [installed,upgradable to: 5.2.37-2+b9]
binutils/stable,now 2.44-3 arm64 [installed,automatic]
build-essential/stable,now 12.12 arm64 [installed]
coreutils/stable,now 9.7-3 arm64 [installed,automatic]
curl/now 8.14.1-2+deb13u2 arm64 [installed,upgradable to: 8.14.1-2+deb13u3]
dash/stable,now 0.5.12-12 arm64 [installed,automatic]
```

| タグ | 意味 |
|:---|:---|
| `[installed]` | 手動でインストールしたパッケージ |
| `[installed,automatic]` | 依存関係として自動インストールされたパッケージ |
| `[installed,upgradable to: ...]` | 更新可能なパッケージ |

---

### 4-4. パッケージをインストール・削除する

#### sudo apt install — インストールする

第3章で「chapter-04 でインストールできる」と予告した `tree` をインストールします。

```bash
$ sudo apt install tree
Reading package lists...
Building dependency tree...
Reading state information...
Installing:
  tree
Summary:
  Upgrading: 0, Installing: 1, Removing: 0, Not Upgrading: 55
  Download size: 57.9 kB
  Space needed: 173 kB / 35.3 GB available
Get:1 http://deb.debian.org/debian trixie/main arm64 tree arm64 2.2.1-1 [57.9 kB]
Fetched 57.9 kB in 0s (958 kB/s)
Selecting previously unselected package tree.
Preparing to unpack .../tree_2.2.1-1_arm64.deb ...
Unpacking tree (2.2.1-1) ...
Setting up tree (2.2.1-1) ...
Processing triggers for man-db (2.13.1-1) ...
```

インストールできたら、第3章で学んだ `/usr/local` を `tree` で眺めてみましょう。
`-L 1` は「第1階層のみ表示する」オプションです。数字を変えると表示階層を調整できます（`-L 2` なら2階層まで）。

```bash
$ tree -L 1 /usr/local
/usr/local
|-- bin
|-- etc
|-- games
|-- include
|-- lib
|-- libexec
|-- man -> share/man
|-- sbin
|-- share
`-- src

11 directories, 0 files
```

> **第17章との繋がり:**
> 第17章では nginx を `/usr/local/nginx/` にインストールします。
> `apt install nginx` を使えばこのような手順は不要ですが、
> ソースからビルドすることで独自設定や特定バージョンを選べます。
> 理由はこの章末のコラムで詳しく説明します。

#### sudo apt purge — 完全削除（設定ファイルも削除）

`tree` をインストールしたままの状態から、`apt purge` で完全に削除します。

```bash
$ sudo apt purge tree
Reading package lists...
Building dependency tree...
Reading state information...
REMOVING:
  tree*
Summary:
  Upgrading: 0, Installing: 0, Removing: 1, Not Upgrading: 55
  Freed space: 173 kB
Removing tree (2.2.1-1) ...
Processing triggers for man-db (2.13.1-1) ...
```

`REMOVING: tree*` の `*` は「設定ファイルも削除する（purge）」を意味します。

> **`apt remove` と `apt purge` の違い**
> `apt remove` はパッケージ本体を削除しますが、設定ファイルは残します。
> `apt purge` はパッケージ本体と設定ファイルをまとめて完全削除します。
> 再インストール時に設定を引き継ぎたいなら `remove`、完全に削除したいなら `purge` を使います。
>
> `remove` 後に設定ファイルが残っているパッケージは `dpkg -l | grep "^rc"` で確認できます。
> `rc` は「`r`emoved（削除済み）・`c`onfig-files（設定ファイルあり）」を意味します。

#### sudo apt autoremove — 不要な依存パッケージを削除する

パッケージを削除した後、そのパッケージ専用の依存パッケージは不要になっても自動では削除されません。
`autoremove` でまとめて削除します。

```bash
$ sudo apt autoremove
Reading package lists...
Building dependency tree...
Reading state information...
0 upgraded, 0 newly installed, 0 to remove and 55 not upgraded.
```

`tree` はインストール時に依存パッケージを追加しなかったため、削除後に不要なパッケージは残りませんでした。
`python3-pip` のように多くの依存パッケージを引き連れるソフトウェアを削除したとき、`autoremove` が効果を発揮します。

---

### 4-5. dpkg でパッケージを深掘りする

`dpkg` は `.deb` ファイルを直接操作する低レベルツールです。
インストール済みパッケージのファイル構成や、あるファイルがどのパッケージに属するかを調べるときに便利です。

#### dpkg -l — インストール済みパッケージを一覧する

```bash
$ dpkg -l | head -10
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name           Version      Architecture Description
+++-==============-============-============-=================================
ii  adduser        3.152        all          add and remove users and groups
ii  apt            3.0.3        arm64        commandline package manager
ii  apt-utils      3.0.3        arm64        package management related utility programs
ii  bash           5.2.37-2+b5  arm64        GNU Bourne Again SHell
ii  binutils       2.44-3       arm64        GNU binary utilities
```

先頭の `ii` は「Desired=Install, Status=installed」を意味します。正常にインストール済みという状態です。

#### dpkg -S — ファイルが属するパッケージを調べる

第2章で学んだ `ls` コマンドがどのパッケージに含まれているか調べてみましょう。

```bash
$ dpkg -S /usr/bin/ls
coreutils: /usr/bin/ls
```

`/usr/bin/ls` は `coreutils` パッケージに含まれていることが分かります。
`ls`・`cp`・`mv`・`cat` など基本コマンドは、すべて `coreutils` という1つのパッケージで管理されています。

#### dpkg -L — パッケージに含まれるファイルを一覧する

```bash
$ dpkg -L coreutils | head -20
/.
/usr
/usr/bin
/usr/bin/[
/usr/bin/arch
/usr/bin/b2sum
/usr/bin/base32
/usr/bin/base64
/usr/bin/basename
/usr/bin/basenc
/usr/bin/cat
/usr/bin/chcon
/usr/bin/chgrp
/usr/bin/chmod
/usr/bin/chown
/usr/bin/cksum
/usr/bin/comm
/usr/bin/cp
/usr/bin/csplit
/usr/bin/cut
```

第3章で学んだ FHS のディレクトリ構成通りに、`coreutils` のコマンドが `/usr/bin/` 以下へ配置されていることが確認できます。

---

### コラム: apt でインストールできるのに、なぜソースからビルドするのか?

`apt install nginx` を使えば nginx を数秒でインストールできます。
それでも第17章でソースからビルドする理由は何でしょうか。

| 理由 | 詳細 |
|:---|:---|
| **特定バージョンを使いたい** | `apt` が提供するバージョンは選べない。ソースビルドなら任意のバージョンを選択できる |
| **カスタムモジュールを組み込みたい** | `apt` 版にない HTTP/3（QUIC）対応モジュールなどを追加できる |
| **コンパイルオプションを調整したい** | 特定の機能を有効化・無効化してビルドできる |
| **インストール先を自由に決めたい** | デフォルトの `/usr/` ではなく `/usr/local/nginx/` などに配置できる |

実際の業務では、ほとんどの場合 `apt` で十分です。
ソースからのビルドは「パッケージが要件を満たせないとき」の手段です。
第17章では nginx のビルドを通じて、Linux システムの深い理解を養います。

---

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| `apt install` の前に `apt update` を忘れる | `E: Unable to locate package` または古いバージョンのインストール | まず `sudo apt update` を実行してリポジトリ情報を最新化する |
| `sudo` なしで `apt install` を実行する | `E: Could not open lock file ... Permission denied` | `sudo apt install` として root 権限で実行する |
| `remove` と `purge` の違いを知らない | — | `remove` は設定ファイルを残す。完全削除には `purge` を使う |
| `apt update` と `apt upgrade` を混同する | — | `update` はリスト更新のみ。`upgrade` は実際のパッケージを更新する |
| 依存関係エラーを無視する | `dpkg: error processing package...` | `sudo apt -f install` で依存関係の修復を試みる |

---

## 類似比較

| 項目A | 項目B | 違い |
|:---|:---|:---|
| `apt install` | `apt update` | `install` はパッケージ追加、`update` はパッケージリスト更新 |
| `apt remove` | `apt purge` | `remove` は設定ファイルを残す、`purge` は設定ファイルごと完全削除 |
| `apt` | `dpkg` | `apt` は依存関係を自動解決する高レベルツール、`dpkg` は個別 `.deb` を直接操作する低レベルツール |
| `apt search` | `apt show` | `search` は名前・説明文でパッケージを検索、`show` は特定パッケージの詳細情報を表示 |
| `apt remove` | `apt autoremove` | `remove` は指定パッケージを削除、`autoremove` は不要な依存パッケージを一括削除 |
| `apt` | `apt-get` | `apt` は現代版の高機能ツール、`apt-get` は前身で現在もスクリプト用途に推奨される |

---

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| パッケージリスト更新 | `sudo apt update` | `winget source update` | `brew update` |
| インストール | `sudo apt install tree` | `winget install tree` | `brew install tree` |
| 検索 | `apt search tree` | `winget search tree` | `brew search tree` |
| 削除 | `sudo apt remove tree` | `winget uninstall tree` | `brew uninstall tree` |
| 全パッケージ更新 | `sudo apt upgrade` | `winget upgrade --all` | `brew upgrade` |

---

## 理解度チェック

1. `sudo apt install tree` を実行する前に必ず行うべきコマンドは何か?

<details><summary>答え</summary>

`sudo apt update` です。
リポジトリのパッケージリストを最新化しないと、古いバージョンがインストールされたり `E: Unable to locate package` エラーが出たりすることがあります。

</details>

1. `apt remove vim` と `apt purge vim` の違いを説明せよ。

<details><summary>答え</summary>

`apt remove vim` は vim 本体を削除しますが、設定ファイル（`/etc/vim/` 配下など）は残します。
`apt purge vim` は本体と設定ファイルをまとめて完全に削除します。
再インストール時に設定を引き継ぎたい場合は `remove`、クリーンな状態に戻したい場合は `purge` を使います。

</details>

1. `/usr/bin/ls` がどのパッケージに含まれているか調べるコマンドは何か?

<details><summary>答え</summary>

`dpkg -S /usr/bin/ls` です。
出力: `coreutils: /usr/bin/ls`

`ls`・`cp`・`mv`・`cat` などの基本コマンドは、`coreutils` という1つのパッケージで管理されています。

</details>

1. リポジトリとは何か、ひと言で説明せよ。

<details><summary>答え</summary>

パッケージを配布するサーバーです。
スマートフォンの「App Store のサーバー部分」に相当します。
`/etc/apt/sources.list.d/debian.sources` にアクセス先の URL が記述されています。

</details>

1. `apt` と `dpkg` の役割の違いは何か?

<details><summary>答え</summary>

`apt` は依存関係を自動で解決し、リポジトリからダウンロードして `dpkg` を呼び出す高レベルツールです。
`dpkg` は個別の `.deb` ファイルを直接インストール・管理する低レベルツールです。
日常的な操作は `apt` を使い、パッケージの調査や問題の診断に `dpkg` を使います。

</details>

---

| [← 第3章: ディレクトリ構成を知る](../chapter-03/README.md) | [全章目次](../README.md) | [第5章: テキストエディタ3種を使う →](../chapter-05/README.md) |
|:---|:---:|---:|
