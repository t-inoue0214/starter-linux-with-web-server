# 第10章: グループを管理する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第9章: ユーザーを管理する

---

## 概要

Linux では複数のユーザーをまとめる「グループ」という仕組みがあります。
グループを使うと「このグループに所属するユーザー全員がこのファイルにアクセスできる」という管理ができます。
第9章で `usermod -aG sudo tanaka` を実行しましたが、あの `-aG` の意味をこの章で体系的に理解します。
グループは第11章（パーミッション）の前提知識として重要です。

---

## 手順

### 10-1. グループとは何か

#### /etc/group の構造

グループの情報は `/etc/group` ファイルで管理されています。
コロン（`:`）区切りの4フィールドで構成されています。

```bash
$ cat /etc/group | head -5
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
```

| フィールド | 意味 | 例 |
|:---|:---|:---|
| グループ名 | グループの識別名 | `sudo` |
| パスワード | `x`（実体は `/etc/gshadow` に格納） | `x` |
| GID | グループ ID（数値） | `27` |
| メンバー | このグループに所属するユーザー（カンマ区切り） | `vscode,tanaka` |

実際のエントリを確認してみましょう。

```bash
$ cat /etc/group | grep -E "^(sudo|www-data|vscode):"
sudo:x:27:
www-data:x:33:
vscode:x:1000:
```

#### GID の分類

GID もユーザーの UID と同様に数値で管理されており、用途によって範囲が分かれています。

| 範囲 | 用途 | 例 |
|:---|:---|:---|
| `0` | root グループ（特権グループ） | `root` |
| `1〜999` | システムグループ（デーモン・サービス用） | `www-data (33)`, `sudo (27)` |
| `1000〜` | 一般グループ（ユーザーが作成） | `vscode (1000)` |

#### /etc/gshadow

`/etc/group` のパスワードフィールドが `x` になっているのは、実際のパスワード情報が `/etc/gshadow` に分離されているためです。

```bash
$ sudo cat /etc/gshadow | grep -E "^(sudo|www-data|vscode):"
sudo:*::
www-data:*::
vscode:!::
```

| フィールド | 意味 |
|:---|:---|
| グループ名 | グループの識別名 |
| パスワード | `*` = ロック（パスワードなし）、`!` = 無効 |
| グループ管理者 | グループメンバーを管理できるユーザー（省略可） |
| メンバー | グループのメンバー（カンマ区切り） |

> **グループパスワードとは?**
> グループパスワードを設定すると、そのグループに所属していないユーザーでも `newgrp` コマンドでパスワードを入力してグループに参加できます。
> 現代では使われることはほとんどなく、`*` でロックされているのが通常です。

---

### 10-2. グループ情報を確認する

#### groups — 自分が属するグループを確認する

```bash
$ groups
vscode
```

`groups` はグループ名のみを表示するシンプルなコマンドです。

#### id — UID・GID・グループ詳細を確認する

第9章でも使いましたが、グループ情報もあわせて表示されます。

```bash
$ id
uid=1000(vscode) gid=1000(vscode) groups=1000(vscode)
```

| 項目 | 意味 |
|:---|:---|
| `uid=` | ユーザー ID（数値と名前） |
| `gid=` | プライマリグループ ID |
| `groups=` | 所属グループ一覧（プライマリ + サブグループ） |

#### getent group — 特定グループの情報を確認する

```bash
$ getent group sudo
sudo:x:27:

$ getent group www-data
www-data:x:33:
```

> **`getent` とは?**
> `getent`（get entries）は `/etc/group` などのデータベースからエントリを取得するコマンドです。
> `cat /etc/group | grep` と同じ結果になりますが、LDAP などの外部ディレクトリにも対応しています。

---

### 10-3. グループを作成・変更・削除する

実習用ユーザーを先に作成しておきます（第9章の復習）。

```bash
$ sudo useradd -m -s /bin/bash tanaka
```

#### groupadd — グループを作成する

```bash
$ sudo groupadd developers
$ getent group developers
developers:x:1002:
```

GID は既存の最大値+1 で自動的に割り当てられます。
`-g` オプションで GID を指定できます。

```bash
$ sudo groupadd -g 2000 ops
$ getent group ops
ops:x:2000:
$ sudo groupdel ops    # 実習後に削除
```

#### groupmod — グループを変更する

グループ名を変更しても GID は変わりません。
GID でファイルのグループ所有が管理されているため、リネームしてもアクセス権への影響はありません。

```bash
$ sudo groupmod -n devteam developers
$ getent group devteam
devteam:x:1002:
```

| オプション | 意味 |
|:---|:---|
| `-n 新名前` | グループ名を変更する |
| `-g 新GID` | GID を変更する |

#### groupdel — グループを削除する

```bash
$ sudo groupdel devteam
```

ただし、プライマリグループに設定されているユーザーがいる場合は削除できません。

```bash
$ sudo groupadd testgroup
$ sudo usermod -g testgroup tanaka    # tanaka のプライマリグループを testgroup に変更
$ sudo groupdel testgroup
groupdel: cannot remove the primary group of user 'tanaka'
```

この場合は、先に対象ユーザーのプライマリグループを別のグループに戻してから削除します。

```bash
$ sudo usermod -g tanaka tanaka       # プライマリグループを元に戻す
$ sudo groupdel testgroup             # 削除できる
```

---

### 10-4. ユーザーをグループに追加・削除する

#### usermod -aG — サブグループに追加する

第9章で tanaka ユーザーを `sudo` グループに追加したときと同じ操作です。

```bash
$ sudo groupadd developers    # グループが存在しない場合は作成
$ sudo usermod -aG developers tanaka
$ id tanaka
uid=1001(tanaka) gid=1001(tanaka) groups=1001(tanaka),1002(developers)
```

> **`-a` を絶対に忘れてはいけない**
> `-a`（append）なしで `-G` だけ指定すると、既存のグループがすべて消えて指定したグループのみになります。
> `sudo` グループから外れてしまうと管理者権限が失われる危険があります。
> 必ず `-aG`（append + Group）をセットで使いましょう。

```bash
# 危険な操作の例（実行しないこと）
# sudo usermod -G developers tanaka
# → tanaka が持っていた sudo グループなどが消える
```

#### gpasswd — グループのメンバーを管理する

`gpasswd` は `usermod -aG` と同じ操作をできますが、**引数の順序が逆**です。

```bash
# 追加: gpasswd -a ユーザー名 グループ名（usermod は -aG グループ名 ユーザー名）
$ sudo gpasswd -a tanaka sudo
Adding user tanaka to group sudo

$ id tanaka
uid=1001(tanaka) gid=1001(tanaka) groups=1001(tanaka),27(sudo),1002(developers)

# 削除: gpasswd -d ユーザー名 グループ名
$ sudo gpasswd -d tanaka sudo
Removing user tanaka from group sudo

$ id tanaka
uid=1001(tanaka) gid=1001(tanaka) groups=1001(tanaka),1002(developers)
```

| コマンド | 操作 | 引数順 |
|:---|:---|:---|
| `usermod -aG グループ ユーザー` | グループに追加 | グループ → ユーザー |
| `gpasswd -a ユーザー グループ` | グループに追加（同じ効果） | ユーザー → グループ |
| `gpasswd -d ユーザー グループ` | グループから削除 | ユーザー → グループ |

---

### 10-5. プライマリグループとサブグループの違い

#### プライマリグループ

ユーザーが**ファイルを作成したときのデフォルトグループ**です。
`id` の `gid=` に表示されるグループがプライマリグループです。

> **`sudo su -s /bin/bash tanaka -c '...'` の読み方**
> `sudo su` は「別のユーザーとしてコマンドを実行する」仕組みです。
> `-s /bin/bash` はシェルを bash に指定、`-c 'コマンド'` は「そのシェルでこの1コマンドだけ実行して終了する」という意味です。
> ここでは「tanaka ユーザーとしてファイルを作成し、所有者を確認する」ために使っています。

```bash
# tanaka でファイルを作成するとプライマリグループが設定される
$ sudo su -s /bin/bash tanaka -c 'touch ~/test.txt && ls -l ~/test.txt'
-rw-rw-r-- 1 tanaka tanaka 0 May 28 14:00 /home/tanaka/test.txt
#                   ^^^^^^ ← プライマリグループ（tanaka）
```

> **umask によってパーミッションが変わる場合**
> 上記の `-rw-rw-r--` はデフォルトの umask が `0002` の場合の出力です。
> umask はファイル作成時に適用されるパーミッションの「引き算の値」で、第6章で詳しく学びます。
> 環境によって `-rw-r--r--` になる場合があります。

#### サブグループ

プライマリグループに加えて、追加的に所属できるグループです。
`id` の `groups=` に列挙されます。
サブグループに所属していると、そのグループが所有するファイルへのアクセス権を得られます（第11章で詳しく学びます）。

#### プライマリグループを変更する

`usermod -g`（小文字の `-g`）でプライマリグループを変更できます。

```bash
# プライマリグループを developers に変更
$ sudo usermod -g developers tanaka
$ id tanaka
uid=1001(tanaka) gid=1002(developers) groups=1002(developers)
#               ^^^^^^^^^^^^^^^^^^^^^^ ← GID が変わった

# ファイルを作成するとグループが developers になる
$ sudo su -s /bin/bash tanaka -c 'touch ~/test2.txt && ls -l ~/test2.txt'
-rw-rw-r-- 1 tanaka developers 0 May 28 14:00 /home/tanaka/test2.txt
#                   ^^^^^^^^^^ ← プライマリグループが変わった

# 元に戻す
$ sudo usermod -g tanaka tanaka
```

#### -g と -G の違いまとめ

| オプション | 読み方 | 操作 |
|:---|:---|:---|
| `usermod -g グループ ユーザー` | 小文字 `-g` | プライマリグループを**変更** |
| `usermod -G グループ ユーザー` | 大文字 `-G` | サブグループを**置き換え**（危険: `-a` なしは既存グループが消える） |
| `usermod -aG グループ ユーザー` | `-a` + 大文字 `-G` | サブグループに**追加**（推奨） |

---

### 10-6. グループを即時切り替える（newgrp）

`usermod -aG` でグループを追加しても、既存のシェルセッションには即座に反映されません。
反映させるには再ログインが必要ですが、`newgrp` を使うとログアウト不要で切り替えられます。

```bash
# グループ追加直後は id に反映されていないことがある
$ sudo usermod -aG developers vscode
$ id
uid=1000(vscode) gid=1000(vscode) groups=1000(vscode)    # まだ developers が出ない

# newgrp で即時切り替え（サブシェルが起動する）
$ newgrp developers
$ id
uid=1000(vscode) gid=1002(developers) groups=1002(developers),1000(vscode)
# プライマリGIDが developers に切り替わり、作成ファイルのグループが変わる

# exit でサブシェルを抜けて元に戻る
$ exit
$ id
uid=1000(vscode) gid=1000(vscode) groups=1000(vscode)
```

> **newgrp はサブシェルを起動する**
> `newgrp` を実行すると、現在のシェルの中に新しいシェル（**サブシェル**: 現在のシェルの内側に入れ子で起動する新しいシェル）が起動します。
> `exit` で抜けると元のシェルに戻ります。
> シェルスクリプトの中では使えないため、スクリプトでグループを切り替えたい場合は `sg グループ名 コマンド` を使います。

```bash
# 実習後にグループ追加を元に戻す
$ sudo gpasswd -d vscode developers
```

---

### コラム: www-data グループと nginx の関係

第4章の謎リスト「nginx はどのユーザーで動いている?」は第9章で回答しました。
この章ではもう一歩踏み込んで、nginx が **www-data グループ**を使う理由を確認します。

```bash
$ getent group www-data
www-data:x:33:
```

`/etc/group` の www-data エントリのメンバー欄が空なことに気付きましたか?
これは「www-data グループに所属するユーザーを /etc/group で管理していない」という意味です。

nginx の各プロセスは www-data **ユーザー**として動作します（第9章で確認）。
www-data **グループ**が役立つのは、Web コンテンツのファイルのグループ所有権を www-data に設定することで、nginx プロセスがそのファイルを読み取れるようにする場面です。

```bash
# nginx がインストール済みの場合: Web コンテンツのグループ所有権を確認
$ ls -la /var/www/html/
total 20
drwxr-xr-x 2 root root  4096 May 28 12:00 .
drwxr-xr-x 3 root root  4096 May 28 12:00 ..
-rw-r--r-- 1 root root 10671 May 28 12:00 index.nginx-debian.html
```

このファイルのグループ・パーミッションの意味は、第11章（パーミッション）で詳しく学びます。

---

## よくあるミス

| ミス | エラー/症状 | 正しい対処 |
|:---|:---|:---|
| `usermod -G` で `-a` を忘れる | 指定したグループのみになり、`sudo` など既存グループから外れる | 必ず `-aG`（append + Group）の形で使う |
| グループ追加後にセッションが反映されない | `id` には出るのにコマンドが権限エラーになる | `newgrp グループ名` で即時反映するか、ログアウト→ログインする |
| `groupdel` でプライマリグループのユーザーがいる | `groupdel: cannot remove the primary group of user 'X'` | 対象ユーザーのプライマリグループを先に変更してから削除する |
| `usermod -g` と `usermod -G` を混同する | 意図しないグループ変更が起きる | `-g`（小文字）= プライマリ変更、`-aG`（大文字）= サブグループ追加 |
| `gpasswd` と `usermod` の引数順を混同する | 意図と逆のユーザー・グループを操作してしまう | `gpasswd -a ユーザー グループ`（usermod と引数順が逆） |

---

## 類似比較

| コマンドA | コマンドB | 違い |
|:---|:---|:---|
| `usermod -aG グループ ユーザー` | `gpasswd -a ユーザー グループ` | どちらもサブグループ追加。引数の順序が逆（グループ→ユーザー vs ユーザー→グループ） |
| `usermod -g グループ ユーザー` | `usermod -aG グループ ユーザー` | `-g`（小文字）はプライマリグループを変更、`-aG`（大文字）はサブグループに追加 |
| `groupadd グループ` | `useradd -m ユーザー` | `groupadd` はグループのみ作成、`useradd` はユーザーとプライマリグループを同時に作成 |
| `groupdel グループ` | `userdel -r ユーザー` | `groupdel` はグループを削除（プライマリグループは削除不可）、`userdel -r` はユーザーとホームを削除 |
| `groups` | `id` | `groups` はグループ名のみ表示（シンプル）、`id` は UID・GID・グループ詳細を表示 |

---

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| グループ作成 | `sudo groupadd グループ名` | コンピューターの管理 → ローカルユーザーとグループ | `sudo dscl . create /Groups/グループ名` |
| グループにユーザー追加 | `sudo usermod -aG グループ ユーザー` | GUIで「グループのプロパティ」→「メンバーの追加」 | `sudo dseditgroup -o edit -a ユーザー -t user グループ` |
| グループ削除 | `sudo groupdel グループ名` | GUIで「グループの削除」 | `sudo dscl . delete /Groups/グループ名` |
| グループ一覧確認 | `cat /etc/group` | `net localgroup` | `dscl . list /Groups` |
| 自分のグループ確認 | `groups` または `id` | `whoami /groups` | `groups` または `id` |

> **Windows との設計の違い**
> Windows では「管理者グループ（Administrators）」への所属がそのままGUI上の管理者権限に直結します。
> Linux では `sudo` グループへの所属だけでは権限は付与されず、`/etc/sudoers` の設定と組み合わせて初めて `sudo` が使えます（第9章で学んだ通りです）。

---

## 理解度チェック

1. `/etc/group` のエントリ `developers:x:1001:tanaka,suzuki` の各フィールドが意味するものを説明せよ。

<details><summary>答え</summary>

- `developers`: グループ名
- `x`: グループパスワード（実体は `/etc/gshadow` に格納）
- `1001`: GID（グループ ID）
- `tanaka,suzuki`: このグループのメンバー（カンマ区切り）

</details>

2. `sudo usermod -G developers tanaka` を実行すると、tanaka が `sudo` グループから外れてしまう。なぜか? また、正しいコマンドは何か?

<details><summary>答え</summary>

`-G`（大文字、`-a` なし）は指定したグループ**のみ**にサブグループを置き換えるため、既存の `sudo` グループへの所属が消えます。

正しくは `-aG`（append + Group）を使います:

```bash
sudo usermod -aG developers tanaka
```

`-a` はサブグループに「追加」する指示です。`-G` だけでは「置き換え」になります。

</details>

3. `usermod -aG developers tanaka` を実行した直後に tanaka でログインして `id` を確認したが、`developers` グループが表示されなかった。なぜか? どうすれば反映されるか?

<details><summary>答え</summary>

グループ情報はログイン時に読み込まれます。既存のシェルセッションには変更が自動では反映されません。

反映させる方法は2つあります:

1. ログアウト → 再ログイン
2. `newgrp developers` で即時切り替え（サブシェルが起動する）

</details>

4. `groupdel tanaka` を実行したら `groupdel: cannot remove the primary group of user 'tanaka'` というエラーが出た。どう対処するか?

<details><summary>答え</summary>

tanaka グループが tanaka ユーザーのプライマリグループに設定されているため、削除できません。
先に tanaka ユーザーのプライマリグループを別のグループに変更してから削除します。

```bash
# 別のグループ（例: users）をプライマリに変更してから削除
sudo usermod -g users tanaka
sudo groupdel tanaka
```

</details>

5. プライマリグループとサブグループの実用的な違いを説明せよ。

<details><summary>答え</summary>

- **プライマリグループ**: ファイルを作成したときのデフォルトグループ。`touch test.txt` で作成したファイルのグループ所有者がプライマリグループになる。`usermod -g` で変更する。
- **サブグループ**: 追加的なアクセス権。そのグループが所有するファイルへのアクセス（読み取り・書き込みなど）が可能になる。`usermod -aG` で追加する。

例えば `tanaka` ユーザーが `developers` グループのファイルを読み書きできるようにするには、`usermod -aG developers tanaka` でサブグループに追加します。ファイルを作成するときのデフォルトグループは変わりません。

</details>

---

次章では、グループの仕組みを前提に、ファイルやディレクトリの「読み取り・書き込み・実行」権限（パーミッション）の仕組みと、`chmod`・`chown` による権限変更を学びます。

| [← 第9章: ユーザーを管理する](../chapter-09/README.md) | [全章目次](../README.md) | [第11章: パーミッションを理解する →](../chapter-11/README.md) |
|:---|:---:|---:|
