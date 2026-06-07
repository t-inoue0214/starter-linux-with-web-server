# 第9章: ユーザーを管理する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第8章: Locale・Timezone を設定する

---

## 概要

Linux ではファイルやプロセスに「誰が所有しているか」が必ず紐づきます。
ユーザー管理を理解すると、nginx が `www-data` で動く理由（chapter-04 の謎）が解け、セキュリティ設計の意図（最小権限の原則）が理解できるようになります。
また、システムの安定性と安全性を高めるために、サービスごとに専用ユーザーを作る理由も見えてきます。
この章では、ユーザーの作成・変更・削除から、`sudo` の仕組みまでを体系的に学びます。

---

## 手順

### 9-1. ユーザーとは何か

Linux はマルチユーザー OS です。すべてのファイル・プロセス・ネットワーク接続には「所有者（ユーザー）」が紐づいています。

#### `/etc/passwd` の構造

ユーザー情報は `/etc/passwd` に記録されています。1行1ユーザーで、7フィールドがコロン（`:`）で区切られています。

```bash
$ cat /etc/passwd | head -5
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
```

| フィールド | 内容 | 例 |
|:---|:---|:---|
| 1. ユーザー名 | ログイン時に使う名前 | `root` |
| 2. パスワード | `x` は `/etc/shadow` に移動済みを示す | `x` |
| 3. UID | ユーザー ID（数値）| `0` |
| 4. GID | 主グループ ID（数値）| `0` |
| 5. コメント | ユーザーの説明（**GECOS フィールド**: かつてのシステムからの慣習的な名称。現在は任意の説明文を入れるフィールドとして使われる）| `root` |
| 6. ホームディレクトリ | ログイン後の初期ディレクトリ | `/root` |
| 7. シェル | ログイン時に起動するプログラム | `/bin/bash` |

#### UID の区分

| 範囲 | 区分 | 説明 |
|:---|:---|:---|
| 0 | root | 唯一の特権ユーザー |
| 1〜999 | システムユーザー | デーモン（バックグラウンドで常時動き続けるプログラム。Windows のサービスに相当）・サービス専用。人間がログインしない |
| 1000〜 | 一般ユーザー | 人間が使うアカウント。Codespaces では `vscode` が UID 1000 |

#### `/usr/sbin/nologin` の役割

`/etc/passwd` の7フィールド目（シェル）が `/usr/sbin/nologin` のユーザーは、SSH などでのログインが拒否されます。

```bash
$ grep nologin /etc/passwd | head -3
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
```

サービス専用ユーザーにはシェルを `/usr/sbin/nologin` に設定することで、「そのユーザーでプロセスを起動できるが、人間はログインできない」状態を作れます。

---

### 9-2. ユーザー情報を確認する

#### 自分自身の情報を確認する

```bash
$ id
uid=1000(vscode) gid=1000(vscode) groups=1000(vscode)

$ whoami
vscode
```

`id` はUID・GID・所属グループをすべて表示します。`whoami` はユーザー名のみを返します。環境によっては `groups=` に追加グループが表示される場合もあります。

#### ログイン中のユーザーを確認する

```bash
$ who
（出力なし）

$ w
 13:00:00 up  2:00,  0 users,  load average: 0.00, 0.01, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU  WHAT
```

> カラム幅は環境・バージョンにより異なる場合があります。

> **`who` が 0 users と表示される理由**
> Codespaces はブラウザまたは VS Code の Remote Containers 機能で接続しており、SSH のような TTY（テレタイプ。歴史的に物理端末機器を指した用語で、現在はターミナルセッション全般を指す）セッションを持ちません。
> `who` や `w` は TTY セッションをカウントするため、ユーザーが 0 と表示されます。
> コマンドが壊れているわけではありません。自分のユーザー情報は `whoami` や `id` で確認してください。

---

### 9-3. ユーザーを作成する

#### `useradd` — 低レベルコマンド

```bash
$ sudo useradd -m -s /bin/bash tanaka
```

| オプション | 意味 |
|:---|:---|
| `-m` | ホームディレクトリ `/home/tanaka` を作成する。**省略するとホームが作られない** |
| `-s /bin/bash` | ログインシェルを bash に設定する。省略すると `/bin/sh` になる（Debian では `/bin/sh` は `bash` より軽量な `dash` へのシンボリックリンクであり、bash との挙動差に注意）|

```bash
# 作成されたか確認する
$ id tanaka
uid=1001(tanaka) gid=1001(tanaka) groups=1001(tanaka)
```

#### `adduser` — Debian 推奨の対話式ラッパー

手動でユーザーを作成する場合は `adduser` を使うと、`-m` や `-s` の指定が不要で、パスワード設定まで対話的に行えます。

```bash
$ sudo adduser tanaka
Adding user `tanaka' ...
Adding new group `tanaka' (1001) ...
Adding new user `tanaka' (1001) with group `tanaka' ...
Creating home directory `/home/tanaka' ...
Copying files from `/etc/skel' ...
New password:
Retype new password:
passwd: password updated successfully
...
```

> `useradd` はシェルスクリプトによる自動化向け、`adduser` は人間が手動で操作するときに適しています。

#### `/etc/skel` の役割

新規ユーザーを作成すると、`/etc/skel` の内容がホームディレクトリにコピーされます。

```bash
$ ls -a /etc/skel
.  ..  .bash_logout  .bashrc  .profile
```

> `/etc/skel` 内のファイルはすべて隠しファイル（`.` 始まり）のため、`-a` オプションが必要です。

これらのファイルが `/home/tanaka/` にコピーされることで、新しいユーザーも最初からシェル設定が整った状態で使えます。

---

### 9-4. パスワードを設定する

#### パスワードを設定する

```bash
$ sudo passwd tanaka
New password:
Retype new password:
passwd: password updated successfully
```

#### `/etc/shadow` の構造

パスワードは平文では保存されず、`/etc/shadow` にハッシュ化（元のパスワードに戻せない一方向の変換。同じパスワードからは必ず同じハッシュ値が生成される）して保存されます。このファイルは root のみが読めます。

```bash
$ sudo cat /etc/shadow | grep tanaka
tanaka:$6$randomsalt$hashedpassword...:20027:0:99999:7:::
```

| フィールド | 内容 |
|:---|:---|
| `tanaka` | ユーザー名 |
| `$6$...` | ハッシュ化されたパスワード（`$6$` は SHA-512 を意味する）|
| `20027` | 最終パスワード変更日（1970-01-01 からの日数）|
| `0` | パスワード変更の最小間隔（日数）|
| `99999` | パスワードの有効期限（日数）|
| `7` | 期限切れ前の警告日数 |

> `/etc/passwd` は誰でも読めますが、パスワードハッシュは `/etc/shadow` に分離されることで、一般ユーザーからのアクセスを遮断しています。

---

### 9-5. ユーザーを変更・削除する

#### `usermod` — ユーザー属性を変更する

```bash
# tanaka を sudo グループに追加する
$ sudo usermod -aG sudo tanaka

# 反映を確認する
$ id tanaka
uid=1001(tanaka) gid=1001(tanaka) groups=1001(tanaka),27(sudo)
```

> **`-a`（append）を必ず付ける**
> `-a` を省略して `-G sudo` だけにすると、tanaka の既存グループが**すべて削除**され、`sudo` グループのみになります。
> グループを追加するときは必ず `-aG`（append + group）の形で使ってください。

#### `userdel` — ユーザーを削除する

```bash
$ sudo userdel -r tanaka
userdel: tanaka mail spool (/var/mail/tanaka) not found
```

`-r` オプションでホームディレクトリ（`/home/tanaka`）ごと削除します。
`mail spool not found` の警告は、メールスプールが存在しないだけで**無害**です。

```bash
# 削除されたか確認する（エラーが出れば削除成功）
$ id tanaka
id: 'tanaka': no such user
```

---

### 9-6. ユーザーを切り替える

#### `su` と `su -` の違い

```bash
# ログインシェルとして切り替える（環境変数も tanaka のものにリセット）
$ su - tanaka
Password:
tanaka@codespaces:~$

# 環境変数を引き継いだまま切り替える
$ su tanaka
Password:
tanaka@codespaces:/home/vscode$   # カレントディレクトリが vscode のまま
```

| 項目 | `su tanaka` | `su - tanaka` |
|:---|:---|:---|
| 環境変数（PATH 等）| 現在のユーザーのものを引き継ぐ | tanaka のログイン時の値にリセット |
| カレントディレクトリ | 変わらない | `/home/tanaka` に移動 |
| `.bashrc` / `.profile` の読み込み | 読み込まない | 読み込む |
| 使いどころ | 現在の環境を持ち込みたいとき | 完全に別ユーザーとして操作したいとき |

```bash
# 元のユーザーに戻る
tanaka@codespaces:~$ exit
logout
$
```

---

### 9-7. sudo の仕組みを理解する

#### なぜ root で直接作業しないのか

「root アカウントさえあれば sudo など不要では？」と思うかもしれません。
しかし実際のサーバー運用では、root で直接ログインして作業することは**非推奨**です。

| 観点 | root で直接作業 | sudo を使う |
|:---|:---|:---|
| **操作ログ** | 残らない（誰が何をしたか追跡不能） | `auth.log` に「誰が・いつ・何を」が記録される |
| **チーム運用** | root パスワードを全員に共有する必要がある | 各自のアカウントで操作。退職者はそのアカウントを無効化するだけ |
| **権限の絞り込み** | 常に全権限（制限不可） | 「この操作だけ許可」という細かい制御が可能 |
| **誤操作リスク** | 常時全権限なので一瞬の打ち間違いが致命的 | 通常は一般権限。`sudo` と明示しないと権限が発動しない |

たとえば 3 人でサーバーを管理していて、深夜に重要なファイルが削除された場合——root で作業していれば「誰がやったか」がわかりません。sudo を使っていれば操作ログから原因を特定できます。

> **Codespaces ではログが確認できない**
> コンテナ環境のため `/var/log/auth.log` が存在しませんが、実際の Linux サーバーでは
> `sudo cat /etc/shadow` を実行すると以下のようなログが記録されます:
>
> ```text
> May 28 13:05:01 hostname sudo: vscode : TTY=pts/0 ; PWD=/home/vscode ; USER=root ; COMMAND=/bin/cat /etc/shadow
> ```
>
> 「vscode ユーザーが pts/0 端末から /etc/shadow を root 権限で読んだ」という履歴が残ります。

#### `sudo` の動作フロー

`sudo コマンド` を実行したとき、Linux は以下の順で処理します:

1. **認証**: 現在のユーザーのパスワードを確認する（root のパスワードではない）
2. **sudoers 確認**: `/etc/sudoers`（sudoers: sudo コマンドの権限設定を記述する設定ファイル）または `/etc/sudoers.d/` の設定でそのユーザーに権限があるか確認する
3. **実行**: root 権限でコマンドを実行する
4. **ログ記録**: `/var/log/auth.log` に操作履歴を残す

#### `/etc/sudoers` を確認する

```bash
$ sudo cat /etc/sudoers
# This file MUST be edited with the 'visudo' command as root.
#
# See the man page for details on how to write a sudoers file.
...
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL
...
```

> **`/etc/sudoers` を直接編集してはいけない**
> `/etc/sudoers` の構文エラーは sudo 自体を使えなくする致命的な問題を引き起こします。
> 編集するときは必ず `sudo visudo` を使ってください。`visudo` は保存前に構文チェックを行います。

#### `/etc/sudoers.d/` ディレクトリ

個別の設定は `/etc/sudoers.d/` に分割して配置できます。Codespaces では `vscode` ユーザーの sudo 権限がここで定義されています。

```bash
$ ls /etc/sudoers.d/
README  vscode

$ sudo cat /etc/sudoers.d/vscode
vscode ALL=(root) NOPASSWD:ALL
```

> `README` は sudoers.d の使い方を説明するサンプルファイルです。

`NOPASSWD:ALL` は「パスワードなしですべてのコマンドを実行できる」という設定です。Codespaces が開発者の利便性のために設定しています。

#### 構文を確認する

```bash
$ sudo visudo --check
/etc/sudoers: parsed OK
/etc/sudoers.d/README: parsed OK
/etc/sudoers.d/vscode: parsed OK
```

---

### コラム: Linux に「管理者アカウント」はない

Windows では、ユーザーアカウント自体に「管理者」「標準ユーザー」の属性があります。

Linux は異なる設計思想を持っています。**アカウント自体に属性はなく、`sudo` グループへの所属または `/etc/sudoers` の設定によって「一時的に root 権限を借りる」** 仕組みです。

| 項目 | Windows | Linux |
|:---|:---|:---|
| 特権の持ち方 | アカウント自体が「管理者」属性を持つ | `sudo` グループ所属 or `/etc/sudoers` に記載 |
| 特権の行使 | 管理者アカウントでログインして操作 | `sudo コマンド` で一時的に root 権限を借りる |
| 操作ログ | イベントビューアー | `/var/log/auth.log` |

`root`（UID=0）は唯一の特権ユーザーですが、`root` で直接ログインすることは非推奨です。`sudo` 経由で操作することで、**誰がいつ何を実行したかのログ**が残ります。

---

### コラム: nginx が www-data で動く理由（chapter-04 の謎リスト回答）

chapter-04 で nginx をインストールしたとき、「なぜ `www-data` というユーザーが動いているのか？」と感じた方もいるでしょう。この章の知識で答えが出せます。

#### `www-data` ユーザーを確認する

```bash
$ id www-data
uid=33(www-data) gid=33(www-data) groups=33(www-data)

$ grep www-data /etc/passwd
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
```

シェルが `/usr/sbin/nologin` になっており、人間がこのユーザーでログインできません。

#### nginx のプロセスを確認する（chapter-04 で nginx をインストール済みの場合）

```bash
$ ps aux | grep nginx
root        1234  0.0  0.0  nginx: master process ...
www-data    1235  0.0  0.0  nginx: worker process
www-data    1236  0.0  0.0  nginx: worker process
```

master プロセスは root で、worker プロセスは `www-data` で動いています。

#### なぜ root で動かさないのか

**最小権限の原則**（Principle of Least Privilege）に基づく設計です。

- root で動くプロセスが攻撃者に乗っ取られると、システム全体の権限を奪われます
- `www-data` で動くプロセスが乗っ取られても、`www-data` の権限範囲（Web コンテンツへのアクセス等）に被害を限定できます

専用ユーザーを作ることで、**仮にサービスが攻撃されても被害の範囲を最小限に抑える**のがサービス専用ユーザーを作る理由です。

---

## よくあるミス

| ミス | エラー/症状 | 対処 |
|:---|:---|:---|
| `useradd` で `-m` を忘れる | ホームディレクトリが作成されない（ログイン後 `$HOME` が存在しない）| `useradd -m` または `adduser` を使う |
| `userdel` で `-r` を忘れる | `/home/tanaka` が残る（`ls /home` で確認）| `userdel -r` を使う |
| `usermod` で `-a` を忘れる | 既存グループが消えて指定グループのみになる | `-aG`（append + group）の形で使う |
| `su` と `su -` の混同 | 環境変数が意図しない状態になる | ログインシェルが必要なら `su -` |
| `who` で 0 users と表示 | 「コマンドが壊れている？」と混乱 | Codespaces は TTY なし。正常動作。`whoami` や `id` で自分を確認する |

---

## 類似比較

| コマンド | 特徴 | 使い分け |
|:---|:---|:---|
| `useradd` | 低レベル。オプション指定が必要（`-m`, `-s` 等）| スクリプトでの自動化向け |
| `adduser` | Debian の対話式ラッパー。ホームと基本設定を自動で行う | 手動でユーザーを作るとき |
| `su` | 環境変数を引き継いだまま切替 | 現在の環境を持ち込みたいとき |
| `su -` | ログインシェルとして切替（環境変数もリセット）| 完全に別ユーザーとして動くとき |

---

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| ユーザー作成 | `adduser` / `useradd` | コントロールパネル → ユーザーアカウント | システム設定 → ユーザーとグループ |
| 管理者権限の付与 | `sudo` グループへの追加 | Administrators グループへの追加 | admin グループへの追加 |
| 一時的な管理者実行 | `sudo コマンド` | 右クリック → 管理者として実行 | `sudo コマンド` |
| ユーザーを切り替える | `su - ユーザー名` | ユーザーのログオフ → 別ユーザーでログイン | `su - ユーザー名` |

---

## 理解度チェック

1. `/etc/passwd` の各フィールドのうち、ユーザーがログイン時に起動するシェルはどこに記載されているか？

<details><summary>答え</summary>

7番目のフィールド（最後のフィールド）に記載されています。

例: `tanaka:x:1001:1001::/home/tanaka:/bin/bash` の `/bin/bash` がログインシェルです。

シェルが `/usr/sbin/nologin` のユーザーは、SSH などでのログインが拒否されます。サービス専用ユーザー（`www-data` など）にはこの設定が使われます。

</details>

2. `useradd -m -s /bin/bash tanaka` の `-m` を省略するとどうなるか？

<details><summary>答え</summary>

`-m` を省略すると、ホームディレクトリ `/home/tanaka` が作成されません。

ユーザー自体は作成されますが、ログイン後に `$HOME` は存在しません。シェルの動作に支障をきたす場合があります。
手動でのユーザー作成では、`adduser` コマンドを使うと `-m` を省略しても自動でホームが作成されます。

</details>

3. `su tanaka` と `su - tanaka` の違いを説明せよ。

<details><summary>答え</summary>

| 項目 | `su tanaka` | `su - tanaka` |
|:---|:---|:---|
| 環境変数（PATH 等）| 現在のユーザーのものを引き継ぐ | tanaka のログイン時の値にリセット |
| カレントディレクトリ | 変わらない | `/home/tanaka` に移動 |
| `.bashrc` / `.profile` の読み込み | 読み込まない | 読み込む |

`su -` は「ログインシェル」として起動するため、tanaka として完全に別のセッションを開始します。
完全に別ユーザーとして操作したい場合は `su -` を使います。

</details>

4. `usermod -G sudo tanaka` と `usermod -aG sudo tanaka` の違いは何か？ `-a` を省略するとどうなるか？

<details><summary>答え</summary>

`-G` オプションは、指定したグループのみをユーザーのグループとして設定します。

`-a` を省略して `usermod -G sudo tanaka` を実行すると、tanaka の**既存グループがすべて削除**され、`sudo` グループのみになります。

`-aG`（append + group）を使うと、既存のグループを保持したまま `sudo` グループを**追加**します。

グループを追加するときは必ず `-aG` の形で使ってください。

</details>

5. nginx が root ではなく www-data ユーザーで動いている理由を説明せよ。

<details><summary>答え</summary>

**最小権限の原則**（Principle of Least Privilege）に基づく設計です。

- root で動くプロセスが攻撃者に乗っ取られると、システム全体の権限を奪われます
- `www-data` で動くプロセスが乗っ取られても、`www-data` の権限範囲（Web コンテンツへのアクセス等）に被害を限定できます

`www-data` は UID=33 のシステムユーザーで、シェルが `/usr/sbin/nologin` に設定されているため、人間がこのユーザーでログインできません。
サービスが攻撃されても被害の範囲を最小限に抑えるため、専用ユーザーを作ってプロセスを動かすのが Linux セキュリティの基本設計です。

</details>

---

次章では、ユーザー管理で登場した「ファイルの所有者」という概念をさらに深め、パーミッション（読み取り・書き込み・実行の権限）の設定と変更方法を学びます。

| [← 第8章: Locale・Timezone を設定する](../chapter-08/README.md) | [全章目次](../README.md) | [第10章 →](../chapter-10/README.md) |
|:---|:---:|---:|
