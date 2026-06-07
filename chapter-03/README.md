# 第3章: ディレクトリ構成を知る

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第2章: 基本コマンドを使いこなす

---

## 概要

Linux のファイルシステム（**ファイルシステム**: ファイルをディスクに保存・管理する仕組み。Windows の NTFS や FAT に相当）には「どこに何を置くか」を定めた国際標準（FHS）があります。
この章では `ls /` からシステムを探索し、主要ディレクトリの役割を体験的に学びます。
「見知らぬサーバーにログインしても迷わず目的のファイルを探せる」状態を目標とします。

---

## 手順

### 3-1. FHS とは — ファイルシステムの「住所録」

**FHS（Filesystem Hierarchy Standard）** は、Linux のディレクトリ配置を定めた国際標準規格です。

> **「FHS」とは?**
> Filesystem Hierarchy Standard の略。Linux Foundation が管理する、Linux ディレクトリ配置の国際標準規格です。
> Debian・Ubuntu・RHEL・Arch など主要ディストリビューションはいずれも FHS に準拠しています。

Windows には「C:\Program Files にアプリを入れる慣習」がありますが、FHS はそれを**標準として定義**したものです。
この標準があるおかげで「見知らぬサーバーにログインしても `/etc` を見れば設定ファイルが見つかる」と分かります。

主要ディレクトリの早見表:

| ディレクトリ | 役割 | 主な内容 |
|:---|:---|:---|
| `/bin`, `/sbin` | 基本コマンド | 現代 Linux では `/usr/bin` へのシンボリックリンク |
| `/etc` | 設定ファイル | `passwd`, `fstab`, `nginx.conf` など |
| `/home` | ユーザーホーム | `/home/vscode/` など |
| `/root` | root ユーザーのホーム | — |
| `/usr` | ユーザーランドプログラム | `/usr/bin/`, `/usr/lib/`, `/usr/local/` |
| `/usr/local` | 手動インストールアプリ | 第20章で nginx をここに配置する |
| `/var` | 変化するデータ | `/var/log/`, `/var/spool/` |
| `/var/log` | ログファイル | `syslog`, `auth.log` など |
| `/tmp` | 一時ファイル | 再起動で消える |
| `/proc` | カーネル情報の仮想 FS | CPU・メモリ・プロセス情報 |
| `/sys` | デバイス情報の仮想 FS | ドライバ・ハードウェア情報 |
| `/dev` | デバイスファイル | `/dev/null`, `/dev/random` など |
| `/opt` | オプションアプリ | サードパーティソフト |
| `/mnt` | 手動マウントポイント | 第13章で使用 |
| `/media` | 自動マウントポイント | USB・CD-ROM |
| `/boot` | ブートローダ・カーネル | vmlinuz, initrd |

---

### 3-2. ルートディレクトリを全体的に眺める

まず `/`（ルート）ディレクトリを確認します。

```bash
$ ls /
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var  vscode  workspaces
```

> `vscode`・`workspaces` は GitHub Codespaces 固有のディレクトリで、VS Code のランタイムとリポジトリデータが格納されています。
> 通常の Linux サーバーには表示されません。

`-la` オプションで詳細情報を確認します:

```bash
$ ls -la /
total 88
drwxr-xr-x    1 root   root 4096 May 27 13:15 .
drwxr-xr-x    1 root   root 4096 May 27 13:15 ..
drwxr-xr-x    3 root   root 4096 May 27 13:15 .codespaces
-rwxr-xr-x    1 root   root    0 May 27 13:15 .dockerenv
lrwxrwxrwx    1 root   root    7 Jan  2 12:35 bin -> usr/bin
drwxr-xr-x    2 root   root 4096 Jan  2 12:35 boot
drwxr-xr-x   13 root   root 3940 Jun  7 09:41 dev
drwxr-xr-x    1 root   root 4096 Jun  7 10:50 etc
drwxr-xr-x    1 root   root 4096 May 28 15:34 home
lrwxrwxrwx    1 root   root    7 Jan  2 12:35 lib -> usr/lib
lrwxrwxrwx    1 root   root    9 Jan  2 12:35 lib64 -> usr/lib64
drwxr-xr-x    2 root   root 4096 Feb 23 00:00 media
drwxr-xr-x    2 root   root 4096 Feb 23 00:00 mnt
drwxr-xr-x    1 root   root 4096 Jun  7 10:49 opt
dr-xr-xr-x  240 root   root    0 Jun  7 09:41 proc
drwx------    1 root   root 4096 Jun  7 10:51 root
drwxr-xr-x    1 root   root 4096 Jun  7 10:51 run
lrwxrwxrwx    1 root   root    8 Jan  2 12:35 sbin -> usr/sbin
drwxr-xr-x    2 root   root 4096 Feb 23 00:00 srv
dr-xr-xr-x   12 root   root    0 Jun  7 09:23 sys
drwxr-xrwt+   5 root   root 4096 Jun  7 12:03 tmp
drwxr-xr-x    1 root   root 4096 Feb 23 00:00 usr
drwxr-xr-x    1 root   root 4096 Jun  1 14:05 var
drwxr-xr-x    5 root   root 4096 Jun  7 09:40 vscode
drwxr-xrwx+   4 vscode root 4096 May 27 13:15 workspaces
```

注目すべき3点:

1. `bin -> usr/bin` — `/bin` は `/usr/bin` へのシンボリックリンク（`ls -la` では `->` で表示）
2. `dr-xr-xr-x` の `/proc` と `/sys` — 通常のディレクトリと異なり書き込み不可の仮想ファイルシステム
3. `.codespaces`・`vscode`・`workspaces` — GitHub Codespaces 固有のエントリ。通常の Linux サーバーには存在しない

> 先頭の `drwxr-xr-x` や `lrwxrwxrwx` はパーミッション文字列（ファイルの読み書き実行権限を表す9文字の記号）です。
> 詳細な読み方は第11章で学びます。ここでは「`d` で始まればディレクトリ、`l` で始まればシンボリックリンク」と覚えておけばOKです。

> 日付・パーミッション数値は実行環境・タイミングにより異なります。

> **「マウント」とは?**
> 記憶装置（HDD・SSD・USB メモリなど）をファイルシステムへ接続する操作です。
> `/mnt` や `/media` はその接続ポイント（マウントポイント）として使われます。
> 詳しくは第13章で学びます。

---

### 3-3. システムコマンドの格納庫: /bin, /sbin, /usr

#### /bin と /usr/bin の関係

`ls -la /` の出力で `bin -> usr/bin` と表示されていたとおり、
現代の Debian では `/bin` は `/usr/bin` へのシンボリックリンクです。

```bash
$ readlink /bin
usr/bin
$ readlink /sbin
usr/sbin
$ readlink /lib
usr/lib
```

第2章で学んだ `readlink` コマンドを活用して、シンボリックリンクの指し先を確認します。

> **歴史的背景:**
> かつての Linux では `/bin`（基本コマンド）と `/usr/bin`（追加コマンド）は別々のディレクトリでした。
> 管理の複雑さを解消するために統合（usrmerge）が行われ、
> 現代の Debian では `/bin`・`/sbin`・`/lib` はすべて `/usr/` 以下へのシンボリックリンクになっています（この統合操作を **usrmerge** といいます）。

#### /usr/bin の中身

`/usr/bin` には数百のコマンドが収録されています。

```bash
$ ls /usr/bin | head -20
[
addr2line
apropos
apt
apt-cache
apt-cdrom
apt-config
apt-extracttemplates
apt-ftparchive
apt-get
apt-mark
apt-sortpkgs
ar
arch
as
awk
b2sum
base32
base64
basename
```

第2章で使った `ls`・`grep`・`cat` といったコマンドもすべてここに収録されています。

#### /usr/local — 手動インストールアプリの置き場

`/usr/local/` は「**手動でビルドしてインストールするソフトウェア**の置き場」です。
パッケージマネージャー（apt など）が管理する `/usr/bin/` とは分けることで、「どれが自分でインストールしたものか」を区別できます。

```bash
$ ls /usr/local
bin  etc  games  include  lib  libexec  man  sbin  share  src
```

この Codespaces 環境では `/usr/local/bin` に VS Code や Git が配置されています:

```bash
$ ls /usr/local/bin
code  devcontainer-info  git  git-cvsserver  git-receive-pack
git-shell  git-upload-archive  git-upload-pack  gitk  scalar  systemctl
```

> **第20章との繋がり:**
> この章で学ぶ `/usr/local` は、第20章で nginx をソースからビルドする際に重要になります。
> nginx は `/usr/local/nginx/` 以下にインストールされます。

---

### 3-4. 設定・ログ・一時ファイル: /etc, /var, /tmp

#### /etc — 設定ファイルの置き場

`/etc` にはシステムやアプリケーションの設定ファイルが集中しています。
この Codespaces 環境だけで 114 個のファイル・ディレクトリが存在します。

```bash
$ ls /etc | head -15
X11
adduser.conf
alternatives
apache2
apparmor.d
apt
bash.bashrc
bash_completion
bash_completion.d
bindresvport.blacklist
ca-certificates
ca-certificates.conf
cron.daily
cron.weekly
dbus-1
```

よく触れる設定ファイルをいくつか確認します:

```bash
$ cat /etc/hostname
codespaces-bc9305

$ cat /etc/os-release
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
NAME="Debian GNU/Linux"
VERSION_ID="13"
VERSION="13 (trixie)"
VERSION_CODENAME=trixie
DEBIAN_VERSION_FULL=13.3
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

> `/etc/hostname` に表示されるホスト名は Codespaces の起動ごとに異なります。`DEBIAN_VERSION_FULL` もパッケージ更新により変わることがあります。

`/etc/os-release` でディストリビューション名やバージョンを素早く確認できます。

#### /var — 変化し続けるデータ

`/var` には「実行中に増減するデータ」が入ります。ログ・キャッシュ・スプールなどが格納されます。

```bash
$ ls /var/log
README  alternatives.log  apt  auth.log  btmp  cron.log  docker.log
dpkg.log  exim4  journal  kern.log  lastlog  private  syslog  user.log  wtmp
```

| ファイル | 内容 |
|:---|:---|
| `syslog` | システム全体のログ（OS・サービスのイベントが集まる） |
| `auth.log` | 認証・sudoの記録 |
| `apt/` | apt コマンドによるパッケージ操作の履歴 |
| `dpkg.log` | パッケージインストール・削除の詳細ログ |
| `alternatives.log` | update-alternatives の操作ログ |
| `btmp` | ログイン失敗の記録（`lastb` コマンドで閲覧） |
| `wtmp` | ログイン成功の記録（`last` コマンドで閲覧） |
| `cron.log` | cron による定期実行の記録 |

> `syslog`・`auth.log` など多くのログファイルは Codespaces 環境でも生成されます（第14章で詳しく扱います）。
> 表示されるファイルの種類・数は環境や起動タイミングによって異なります。

#### /tmp — 一時ファイル置き場

`/tmp` には一時ファイルが置かれます。

```bash
$ ls /tmp
claude-1000  dev-container-features  mcp-9Hxf1l  vscode-git-bfb7774ef0.sock
```

> **注意: /tmp は再起動で消える**
> `/tmp` の内容は OS の再起動（またはシステムの設定）で削除されます。
> 長期保存が必要なファイルは `/var/` や `/home/` に置いてください。
> 再起動後も残る一時ファイルが必要な場合は `/var/tmp/` を使います。

---

### 3-5. ユーザー領域: /home, /root, /opt

#### /home — 一般ユーザーのホームディレクトリ

`/home` 以下に各ユーザーのホームディレクトリが作成されます。

```bash
$ ls /home
vscode
```

この Codespaces 環境では `vscode` ユーザー1人のみです。
実際のサーバーでは `/home/alice/`・`/home/bob/` のように複数のユーザーが並びます。

#### /root — root ユーザーの専用ホーム

root ユーザーのホームは `/home/root/` ではなく **`/root/`** です。
セキュリティ上の理由から、一般ユーザーは読み取れません。

```bash
$ ls /root
ls: cannot open directory '/root': Permission denied
```

#### /opt — オプションアプリケーション

`/opt` へはサードパーティのアプリケーションを丸ごと配置する慣例があります。
この環境では空ですが、商用ソフトウェアや独自ビルドのツールチェーンを `/opt/アプリ名/` に配置する慣例があります。

```bash
$ ls /opt
（何も表示されない）
```

RHEL・CentOS 系ディストリビューションでは `/opt` への配置が特によく見られます。

---

### 3-6. 仮想ファイルシステム: /proc, /sys, /dev

#### /proc — カーネルが動的に生成する仮想 FS

`/proc` は**ディスク上に実体のない仮想ファイルシステム**です。

> **「仮想ファイルシステム」とは?**
> ディスクに書かれたデータではなく、カーネルがメモリ上に動的に生成する情報をファイルとして提供する仕組みです。
> 読むたびに最新の情報が返ってきます。

```text
通常のファイル  : アプリ → ディスク（HDD/SSD）に書く → ファイルとして読める
/proc のファイル: カーネル → メモリ上に動的生成 → ファイルとして読めるが実体はない
```

`du` コマンドでサイズを確認すると 0 バイトになることで、仮想 FS であると確認できます:

```bash
$ du -sh /proc 2>/dev/null
0	/proc
```

`2>/dev/null` は第2章で学んだとおり、権限エラーなどの余分な出力を捨てています。

実際に読んでみましょう:

```bash
$ cat /proc/uptime
21847.10 172818.58
```

- 1番目の数値（秒）: システム起動からの経過時間 ← `21847.10 秒 ÷ 3600 ≒ 6.07 時間` 稼働中
- 2番目の数値（秒）: 全 CPU コアのアイドル時間の累計 ← CPU が複数コアある場合は合算されるため 1 番目より大きくなる

```bash
$ cat /proc/meminfo
MemTotal:        8135196 kB
MemFree:          588384 kB
MemAvailable:    4738340 kB
Buffers:          316964 kB
Cached:          3696196 kB
SwapCached:            0 kB
Active:          1442932 kB
Inactive:        5273588 kB
Active(anon):     605120 kB
Inactive(anon):  2172628 kB
Active(file):     837812 kB
Inactive(file):  3100960 kB
Unevictable:       31048 kB
Mlocked:           27976 kB
SwapTotal:             0 kB
```

`MemTotal` で RAM 合計量（約 7.8 GB）、`MemAvailable` で実際に利用可能な量が分かります。

> `SwapTotal: 0 kB` は Codespaces のコンテナ環境ではスワップが設定されていないためです。
> 物理マシンや一般的な VPS では `SwapTotal: 1048576 kB`（1GB など）が表示されます。
> 各値は実行環境・タイミングにより異なります。

```bash
$ cat /proc/cpuinfo | head -8
processor	: 0
vendor_id	: AuthenticAMD
cpu family	: 25
model		: 1
model name	: AMD EPYC 7763 64-Core Processor
stepping	: 1
microcode	: 0xffffffff
cpu MHz		: 3243.995
```

> **x86_64 アーキテクチャ:**
> この Codespaces 環境は x86_64（AMD64）アーキテクチャの Azure VM 上で動作しています。
> `model name: AMD EPYC 7763 64-Core Processor` のように、CPU メーカーとモデルが表示されます。
> ARM64 環境では `BogoMIPS`・`Features`・`CPU implementer` など ARM 固有フィールドが表示されます。

`/proc` 以下には数値ディレクトリ（プロセス ID）も存在します:

```bash
$ ls /proc | grep -E '^[0-9]' | head -5
1
1134
123
16178
184
```

各数値は実行中のプロセスの PID（プロセス ID）です。
`/proc/1/` には、PID 1 のプロセス情報が入っています。PID 1 は OS が起動すると最初に立ち上がる親プロセスで、Debian では **systemd**（**systemd**: サービスの起動・停止を一元管理するプログラム。Windows の「サービス」機能に相当）が担当します。

> **Windows との対比:**
> Windows のタスクマネージャーが表示する CPU 使用率やメモリ使用量は、内部的に類似した情報を参照しています。
> Linux では同じ情報をファイルとして読めるため、シェルスクリプトや監視ツールから直接参照できます。

#### /sys — デバイス・ドライバ情報の仮想 FS

`/sys` もディスク上に実体のない仮想ファイルシステムです。
主にハードウェアとドライバの情報が入っており、デバイスのツリー構造を表現しています。
`/proc` がプロセスやカーネル統計に特化しているのに対し、`/sys` はデバイス管理に特化しています。

#### /dev — デバイスファイル

`/dev` にはハードウェアをファイルとして表現した**デバイスファイル**が置かれています。

```bash
$ ls /dev
autofs  core  cpu_dma_latency  fd  full  fuse  kvm  loop0  loop1  loop2
mapper  mqueue  null  ptmx  pts  random  sda  sda1  sdb  sdb1  shm
stderr  stdin  stdout  tty  ttyS0  ttyS1  urandom  zero  ...
```

> `ls /dev` の出力は非常に長いため上記は一部のみ抜粋しています（実際は数百行出力されます）。

> **「デバイスファイル」とは?**
> Linux では「すべてはファイルである」という設計思想があります。
> ハードディスク・端末・乱数生成器などのハードウェアをファイルとして表現することで、
> 通常のファイル操作コマンド（`cat`, `read` など）でハードウェアを操作できます。

> **Codespaces 環境の `/dev` について:**
> GitHub Codespaces は VM 上の Docker コンテナですが、`/dev/sda`（ディスク）・`/dev/kvm`（仮想化支援）・
> `/dev/ttyS0`（シリアルポート）など、多くのハードウェアデバイスファイルにアクセスできます。
> デバイスの種類や数は環境によって異なります。

よく使うデバイスファイル:

| ファイル | 用途 |
|:---|:---|
| `/dev/null` | 書いたデータを捨てる（ブラックホール）。第2章の `2>/dev/null` で使用済み |
| `/dev/zero` | 読むと 0 が無限に出力される |
| `/dev/random` | 真の乱数を生成する |
| `/dev/urandom` | 高速な疑似乱数を生成する |
| `/dev/stdin` | 標準入力をファイルとして参照する |
| `/dev/stdout` | 標準出力をファイルとして参照する |

---

### コラム: ホスト名を変更する（コンテナ制限あり）

ホスト名はコンピューターの「名前」で、ネットワーク上の識別に使われます。

```bash
$ hostname
codespaces-bc9305

$ cat /etc/hostname
codespaces-bc9305
```

`hostname` コマンドで現在のホスト名を確認できます。
`/etc/hostname` ファイルに永続的なホスト名が保存されており、変更には `hostnamectl` コマンドを使います:

```bash
# hostnamectl set-hostname 新しいホスト名
```

> **[コンテナ制限] Codespaces 環境での注意**
> この操作は GitHub Codespaces（Docker コンテナ）上では動作が制限される場合があります。
> 実際の Linux サーバー環境との違いを理解したうえで学習を進めてください。

> **ホスト名はなぜ `codespaces-bc9305` のような名前?**
> GitHub Codespaces が起動時に自動で割り当てる名前です。
> 起動のたびに異なるホスト名が付与されるため、あなたの環境では別の文字列が表示されます。

---

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| `/usr` をユーザーのホームと誤解する | — | ユーザーホームは `/home/username`。`/usr` は Unix System Resources |
| `/tmp` を長期保存に使う | 再起動後にファイルが消える | 恒久データは `/var/` や `/home/` に保存する |
| `/bin` と `/usr/bin` が別物と思い込む | — | `readlink /bin` で `/usr/bin` へのリンクと確認。現代 Debian では統合済み |
| `/proc` のファイルをディスクファイルと思う | — | 仮想 FS なので `du -sh /proc 2>/dev/null` がほぼ 0 バイト |
| `/etc` の語源（etcetera）で役割を覚えようとして混乱する | — | 「設定ファイル置き場」という役割で覚える |

---

## 類似比較

| 項目A | 項目B | 違い |
|:---|:---|:---|
| `/usr/local` | `/opt` | `/usr/local` は手動ビルド用、`/opt` はサードパーティパッケージ（RPM 系でよく使う） |
| `/tmp` | `/var/tmp` | `/tmp` は再起動で消える、`/var/tmp` は再起動後も残る |
| `/proc` | `/sys` | `/proc` はプロセス・カーネル統計、`/sys` はデバイス・ドライバ情報 |
| `/dev/null` | `/dev/zero` | `/dev/null` はデータを捨てる、`/dev/zero` は 0 を無限に出力する |
| Debian `/etc/apt/` | RHEL `/etc/yum.repos.d/` | ディストリビューションによってパッケージ管理設定の場所が異なる |
| `/bin`, `/sbin` | `/usr/bin`, `/usr/sbin` | 現代 Debian ではシンボリックリンクとして統合（usrmerge） |

---

## 他OSとの比較

| 役割 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| システムコマンド群 | `/usr/bin`, `/bin` | `C:\Windows\System32` | `/usr/bin`, `/bin` |
| ユーザーインストールアプリ | `/usr/local`, `/opt` | `C:\Program Files` | `/usr/local`, `/Applications` |
| ユーザーホーム | `/home/username` | `C:\Users\username` | `/Users/username` |
| システム設定 | `/etc` | レジストリ / `C:\Windows\System32\config` | `/etc`, `/Library` |
| ログファイル | `/var/log` | `C:\Windows\Logs` / イベントビューアー | `/var/log`, `/Library/Logs` |
| 一時ファイル | `/tmp` | `C:\Windows\Temp` / `%TEMP%` | `/tmp`, `/var/folders` |
| 変化するデータ | `/var` | `C:\ProgramData` | `/var` |
| デバイスファイル | `/dev` | デバイスマネージャー（直接アクセス不可） | `/dev` |

---

## 理解度チェック

1. Nginx の設定ファイルは通常どのディレクトリ配下に置かれるか?

<details><summary>答え</summary>

`/etc/nginx/` 配下です。
Linux では設定ファイルを `/etc/` 以下へ集中させるのが FHS の慣例です。
nginx であれば `/etc/nginx/nginx.conf` がメインの設定ファイルになります。

</details>

2. `cat /proc/meminfo` で確認できる情報は何か?

<details><summary>答え</summary>

メモリの合計量（`MemTotal`）・空き容量（`MemFree`）・実際に利用可能な量（`MemAvailable`）などが確認できます。
`/proc/meminfo` はカーネルがリアルタイムで更新する仮想ファイルのため、実行するたびに最新の値が返ってきます。

</details>

3. `/bin` と `/usr/bin` の現代 Debian における関係を説明せよ。

<details><summary>答え</summary>

現代の Debian では `/bin` は `/usr/bin` へのシンボリックリンクです（usrmerge によるディレクトリ統合）。
`readlink /bin` を実行すると `usr/bin` と表示されます。
歴史的には別々のディレクトリでしたが、管理の複雑さを解消するために統合されました。

</details>

4. 再起動後も内容が保持されるのはどれか? a) `/proc/cpuinfo`  b) `/tmp/test.txt`  c) `/etc/hostname`

<details><summary>答え</summary>

**c) `/etc/hostname`** です。

- `/proc/cpuinfo` は仮想 FS のためディスクに実体がありません（再起動後にカーネルが再生成）
- `/tmp/test.txt` は `/tmp` が揮発性のため再起動で削除されます
- `/etc/hostname` はディスク上の実ファイルのため再起動後も保持されます

</details>

5. 手動でソースからビルドしてインストールするソフトウェアはどこに置くのが慣例か?

<details><summary>答え</summary>

`/usr/local/` 配下が慣例です（`/usr/local/bin/`, `/usr/local/lib/` など）。
`/usr/local/` はパッケージマネージャーが管理しない手動インストール用の領域として予約されています。
第20章では nginx をソースからビルドして `/usr/local/nginx/` にインストールします。

</details>

---

次章では、Linux にソフトウェアをインストール・管理する仕組み「パッケージ管理」を学び、`apt` コマンドで Nginx を導入します。

| [← 第2章: 基本コマンドを使いこなす](../chapter-02/README.md) | [全章目次](../README.md) | [第4章: パッケージ管理 →](../chapter-04/README.md) |
|:---|:---:|---:|
