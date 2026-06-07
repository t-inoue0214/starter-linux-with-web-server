# 第11章: パーミッションを理解する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第9章: ユーザーを管理する
- 第10章: グループを管理する

---

## 概要

第9章・第10章で「誰が（ユーザー・グループ）」を学びました。この章ではいよいよ「何ができるか（パーミッション）」を学びます。

パーミッションは Linux のセキュリティの核心です。シェルスクリプトを書いたのに `./run.sh` が実行できない、nginx のエラーログに `Permission denied` が出る——こういったトラブルはすべてパーミッションの理解で解決できます。

第10章のコラムで予告した「www-data グループが nginx のファイルを読める理由」の完全な答えも、この章で得られます。

---

## 手順

### 11-1. パーミッションとは何か

複数のユーザーが同じ Linux システムを使う環境では、「誰が何にアクセスできるか」を制御する仕組みが必要です。それがパーミッション（権限）です。

Linux のパーミッションは **3層 × 3権限** の組み合わせで表現されます。

| 層 | 記号 | 意味 |
|:---|:---|:---|
| 所有者 | `u`（user） | ファイルの所有者 |
| グループ | `g`（group） | ファイルが属するグループのメンバー |
| その他 | `o`（others） | 上記以外の全ユーザー |

| 権限 | 記号 | 意味 |
|:---|:---|:---|
| 読み取り | `r`（read） | ファイルを読める / ディレクトリの中身を `ls` で見られる |
| 書き込み | `w`（write） | ファイルを書き換えられる / ディレクトリにファイルを作れる |
| 実行 | `x`（execute） | ファイルをプログラムとして実行できる / ディレクトリに `cd` で入れる |

---

### 11-2. ls -l の出力を読む

#### 10文字の構造

`ls -l` を実行すると先頭に10文字のパーミッション表記が表示されます。

```bash
$ ls -l /usr/bin/sudo
-rwxr-xr-x 1 root root 306456 Jun 30 2025 /usr/bin/sudo
```

```text
- rwx r-x r-x
^ ^^^ ^^^ ^^^
|  |   |   └── その他（o）: r-x = 読み取り・実行のみ
|  |   └────── グループ（g）: r-x = 読み取り・実行のみ
|  └────────── 所有者（u）: rwx = 読み取り・書き込み・実行すべて
└──────────── ファイル種別: - = 通常ファイル
```

| 種別記号 | 意味 | 例 |
|:---|:---|:---|
| `-` | 通常ファイル | テキスト・バイナリ・スクリプト |
| `d` | ディレクトリ | `drwxr-xr-x` |
| `l` | シンボリックリンク | `lrwxrwxrwx` |

> **シンボリックリンクとは?**
> Windows のショートカット（`.lnk` ファイル）に相当するもので、別のファイルやディレクトリを指す「参照」です。詳しくは第13章で学びます。

#### stat コマンドで数値パーミッションを確認する

`ls -l` の記号表記と数値表記を同時に確認できます（数値表記については次の節で学びます）。

```bash
$ stat /usr/bin/sudo
  File: /usr/bin/sudo
  Size: 306456    Blocks: 600    IO Block: 4096   regular file
Device: 0,45    Inode: 524986  Links: 1
Access: (4755/-rwsr-xr-x)  Uid: (0/root)  Gid: (0/root)
```

`Access: (4755/-rwsr-xr-x)` の部分に数値と記号の両方が表示されます。

#### ディレクトリの「実行権限」とは何か

ファイルの `x` は「プログラムとして実行できる」という意味ですが、ディレクトリの `x` は意味が異なります。

**ディレクトリの `x` = そのディレクトリに `cd` で入れる / パスを経由できる**

```bash
$ ls -ld /home/vscode/
drwx------ 1 vscode vscode 4096 May 28 15:33 /home/vscode/
```

| 権限 | ディレクトリに対する意味 |
|:---|:---|
| `r`（読み取り） | `ls` でディレクトリの中のファイル一覧を表示できる |
| `w`（書き込み） | ディレクトリの中にファイルを作成・削除できる |
| `x`（実行） | `cd` でディレクトリに入れる。パスの途中に使える |

- `r` だけ（`x` なし）: ファイル名の一覧は見えるが `cd` できない
- `x` だけ（`r` なし）: ファイル名は見えないが、名前を知っていれば直接アクセスできる

#### 他のユーザーのホームディレクトリは見られるのか?

Codespaces 環境のホームディレクトリは `drwx------`（700）に設定されています。

```bash
$ ls -ld /home/vscode/
drwx------ 1 vscode vscode 4096 May 28 15:33 /home/vscode/
#   ^^^^^^ グループ・その他には権限が一切ない
```

700 の場合、別のユーザーは vscode のホームディレクトリを `ls` で閲覧できず、`cd` で入ることもできません。

> **なぜ700がデフォルトなのか**
> `/etc/adduser.conf` の `DIR_MODE=0700` という設定により、ユーザー作成時のホームディレクトリが 700 になります。
> これを誤って `chmod 755 /home/tanaka/` のように変更すると、全ユーザーが tanaka のファイルを閲覧できるようになってしまいます。
> これが「必要最小限のパーミッション」の原則が重要な理由です。

---

### 11-3. 数値（8進数）でパーミッションを計算する

パーミッションは `rwx` の3桁で、各権限に数値を割り当てて合計します。

> **なぜ 4・2・1 という数値なのか**
> `r=4`（`100` ₂）、`w=2`（`010` ₂）、`x=1`（`001` ₂）はコンピューターの2進数のビットフラグです。
> 3ビットの組み合わせが 0〜7 の8通りになるため「8進数」と呼ばれます。
> この割り当てにより、どの組み合わせでも値が重複せず、足し算だけで権限を表現できます。

| 権限 | 記号 | 数値 |
|:---|:---|:---|
| 読み取り | `r` | 4 |
| 書き込み | `w` | 2 |
| 実行 | `x` | 1 |
| なし | `-` | 0 |

3桁の合計を、所有者・グループ・その他の順に並べたものがパーミッション数値です。

| 数値 | 記号 | 計算 | よく使う場面 |
|:---|:---|:---|:---|
| `755` | `rwxr-xr-x` | 7=rwx, 5=r-x, 5=r-x | 実行ファイル・ディレクトリ |
| `644` | `rw-r--r--` | 6=rw-, 4=r--, 4=r-- | 設定ファイル・HTML ファイル |
| `600` | `rw-------` | 6=rw-, 0=---, 0=--- | 秘密鍵・パスワードファイル |
| `700` | `rwx------` | 7=rwx, 0=---, 0=--- | ホームディレクトリ |
| `640` | `rw-r-----` | 6=rw-, 4=r--, 0=--- | グループのみ読める設定ファイル |

> **注意: `777` は使わない**
> `777`（全員に全権限）は「セキュリティ的に問題があるのに動かない」とき、困った末に試しがちな設定です。
> 誰でも読み書き実行でき、誰でもファイルを削除できる状態になります。
> 根本的な原因（所有者やグループの設定ミスなど）を解決せず `777` を使うのは危険です。本章では使用しません。

実際にファイルのパーミッションを `stat` で確認してみましょう。

```bash
$ stat /usr/bin/passwd
  File: /usr/bin/passwd
Access: (4755/-rwsr-xr-x)  Uid: (0/root)  Gid: (0/root)
```

`4755` の最初の `4` は後述の特殊パーミッション（SUID）を表します。通常のパーミッションは末尾3桁（`755`）です。

---

### 11-4. chmod で権限を変更する

#### まず体験: ./run.sh が実行できない問題

初めてシェルスクリプトを書いた人がよく遭遇するエラーです。

```bash
$ cat > run.sh << 'EOF'
#!/bin/bash
echo "Hello, Linux!"
EOF
$ ./run.sh
-bash: ./run.sh: Permission denied
```

なぜ実行できないのか確認します。

```bash
$ ls -l run.sh
-rw-r--r-- 1 vscode vscode 26 ... run.sh
#    ^ x（実行権）がない!
```

ファイルを作っただけでは実行権が付きません。`chmod` で実行権を付与します。

```bash
$ chmod u+x run.sh
$ ls -l run.sh
-rwxr--r-- 1 vscode vscode 26 ... run.sh
#    ^ x が付いた
$ ./run.sh
Hello, Linux!
```

これがパーミッションの基本です。「ファイルが存在する」ことと「実行できる」は別物です。

#### 記号形式

記号形式は対象（誰の権限を変えるか）と演算子（どう変えるか）と権限を組み合わせます。

| 対象 | 意味 |
|:---|:---|
| `u` | 所有者（user） |
| `g` | グループ（group） |
| `o` | その他（others） |
| `a` | 全員（all = u+g+o） |

| 演算子 | 意味 |
|:---|:---|
| `+` | 指定した権限を追加 |
| `-` | 指定した権限を削除 |
| `=` | 指定した権限のみにする（他は削除） |

```bash
$ chmod u+x run.sh          # 所有者に実行権を追加
$ chmod go-w config.txt     # グループ・その他から書き込み権を削除
$ chmod a=r readonly.txt    # 全員を読み取りのみに設定
$ chmod ug+x,o-x script.sh  # 所有者・グループに実行権を追加、その他は削除
```

#### 数値形式

```bash
$ chmod 755 script.sh   # rwxr-xr-x（実行ファイル・ディレクトリの標準）
$ chmod 644 config.txt  # rw-r--r--（設定ファイルの標準）
$ chmod 600 secret.key  # rw-------（秘密鍵など）
```

#### ディレクトリを再帰的に変更する

```bash
$ chmod -R 755 /opt/project/  # /opt/project/ 配下をすべて 755 に変更
```

> **-R を付けるときの注意**
> `-R` を付けるとディレクトリ配下のファイル・ディレクトリが一括で変更されます。
> ファイルとディレクトリで適切なパーミッションは異なる（ファイルは実行権不要なことが多い）ため、
> 大規模な変更は慎重に行いましょう。

---

### 11-5. chown と chgrp で所有者を変更する

#### chown — 所有者（とグループ）を変更する

```bash
$ sudo chown tanaka file.txt              # 所有者のみ変更
$ sudo chown tanaka:developers file.txt   # 所有者とグループを同時変更
$ sudo chown :developers file.txt         # グループのみ変更（chgrp と同じ）
$ sudo chown -R tanaka:developers /opt/project/  # 再帰的に変更
```

> **tanaka ユーザーが存在しない場合**
> 第9章・第10章で作成した tanaka ユーザーが必要です。
> 存在しない場合は `sudo useradd -m -s /bin/bash tanaka` で作成してください。

#### chgrp — グループのみを変更する

```bash
$ sudo chgrp developers file.txt   # グループを developers に変更
```

`chown :developers file.txt` と同じ効果ですが、グループのみ変えることを明示したいときに使います。

#### 実用例: 開発チーム共有ディレクトリを作る

```bash
$ sudo mkdir /opt/project
$ sudo chown root:developers /opt/project   # グループを developers に
$ sudo chmod 775 /opt/project              # グループに書き込み権を付与
$ ls -ld /opt/project
drwxrwxr-x 2 root developers 4096 ... /opt/project
```

これで `developers` グループのメンバーは `/opt/project` に自由にファイルを作れます。

```bash
# 後片付け
$ sudo rm -rf /opt/project
```

---

### 11-6. 特殊パーミッション（SUID・SGID・Sticky Bit）

通常の `rwx` に加えて、特殊なパーミッションが3種類あります。

#### SUID（Set User ID）

実行時に「所有者の権限」で動作するフラグです。`ls -l` では所有者の `x` が `s` に変わります。

```bash
$ ls -l /usr/bin/passwd
-rwsr-xr-x 1 root root 118168 Apr 19 2025 /usr/bin/passwd
#    ^ s = SUID
```

`/usr/bin/passwd` は一般ユーザーが自分のパスワードを変更するコマンドです。パスワードファイル（`/etc/shadow`）は root しか書き込めませんが、SUID によって実行中は root 権限で動作するため、一般ユーザーでも自分のパスワードを変更できます。

```bash
$ chmod u+s ファイル   # SUID を設定
$ chmod 4755 ファイル  # 数値形式（先頭の 4 が SUID）
```

#### SGID（Set Group ID）

**ファイルに設定した場合**: 実行するとグループの権限で動作します。`ls -l` の出力ではグループの `x` が `s` に変わります。

```bash
$ ls -l /usr/bin/crontab
-rwxr-sr-x 1 root crontab 51936 Jun 13 2025 /usr/bin/crontab
#       ^ s = SGID
```

`crontab` コマンドは実行時に `crontab` グループ権限で動作し、スケジュール設定ファイルを管理できます。

**ディレクトリに設定した場合**: そのディレクトリ内で作成されたファイルがディレクトリのグループを自動的に継承します。

```bash
$ sudo mkdir /opt/team
$ sudo chown root:developers /opt/team
$ sudo chmod g+s /opt/team   # SGID を設定

$ ls -ld /opt/team
drwxr-sr-x 2 root developers 4096 ... /opt/team
#       ^ s = SGID

# developers グループのメンバーがファイルを作ると...
$ sudo su -s /bin/bash tanaka -c 'touch /opt/team/work.txt'
$ ls -l /opt/team/work.txt
-rw-r--r-- 1 tanaka developers 0 ... /opt/team/work.txt
#                   ^^^^^^^^^^ グループが自動的に developers になる

# 後片付け
$ sudo rm -rf /opt/team
```

SGID ディレクトリはチーム開発でファイルのグループ所有を統一したいときに便利です。

```bash
$ chmod g+s ディレクトリ  # SGID を設定
$ chmod 2755 ディレクトリ # 数値形式（先頭の 2 が SGID）
```

#### Sticky Bit

ディレクトリに設定すると、**自分が作ったファイルしか削除できない**ようになります。`ls -l` ではその他の `x` が `t` に変わります。

```bash
$ ls -ld /tmp
drwxr-xrwt+ 5 root root 4096 May 28 15:35 /tmp
#          ^ t = Sticky Bit（末尾の + は ACL が設定されていることを示す）
```

`/tmp` は全員が読み書きできますが、Sticky Bit のおかげで他のユーザーのファイルを削除できません。

```bash
$ chmod +t ディレクトリ   # Sticky Bit を設定
$ chmod 1755 ディレクトリ # 数値形式（先頭の 1 が Sticky Bit）
```

#### 特殊パーミッションの数値

特殊パーミッションは通常の3桁の前に1桁を追加します。

| 数値 | 名前 | ls -l での表示 |
|:---|:---|:---|
| `4xxx` | SUID | 所有者の `x` が `s` |
| `2xxx` | SGID | グループの `x` が `s` |
| `1xxx` | Sticky Bit | その他の `x` が `t` |

---

### 11-7. umask — ファイル作成時のデフォルトパーミッション

新しいファイルやディレクトリを作成するとき、パーミッションは自動的に設定されます。その初期値を決めるのが `umask` です。

```bash
$ umask
0022
```

`umask` はパーミッションの「引き算の値」です。

| 種別 | 最大値 | umask | 作成時のパーミッション |
|:---|:---|:---|:---|
| ファイル | `0666`（rw-rw-rw-） | `0022` | `0644`（rw-r--r--） |
| ディレクトリ | `0777`（rwxrwxrwx） | `0022` | `0755`（rwxr-xr-x） |

確認してみましょう。

```bash
$ cd ~   # ホームディレクトリで実行（/tmp は ACL の影響でパーミッションが変わる場合があります）
$ touch test_file.txt && mkdir test_dir/
$ ls -l test_file.txt
-rw-r--r-- 1 vscode vscode 0 ... test_file.txt  # 644
$ ls -ld test_dir/
drwxr-xr-x 2 vscode vscode 4096 ... test_dir/   # 755

# 後片付け
$ rm test_file.txt && rmdir test_dir/
```

> **umask が `0002` のユーザーの場合**
> ユーザーによっては umask が `0002` に設定されている場合があります。
>
> | 種別 | 最大値 | umask | 作成時のパーミッション |
> |:---|:---|:---|:---|
> | ファイル | `0666` | `0002` | `0664`（rw-rw-r--） |
> | ディレクトリ | `0777` | `0002` | `0775`（rwxrwxr-x） |
>
> この場合、グループにも書き込み権が付くため、同じグループのメンバーがファイルを編集できます。
> `umask` を実行して現在の値を確認してください。

umask は `.bashrc` や `.profile` に設定して変更できます（第6章の内容）。

---

### コラム: nginx コンテンツとパーミッション

第10章のコラムで「www-data グループとファイルアクセス」を予告しました。
この章で学んだパーミッションを使って、完全に理解できます。

第4章で `apt install nginx` した受講者は実際のファイルで確認できます。

```bash
$ ls -l /etc/nginx/nginx.conf
-rw-r--r-- 1 root root 1777 ... /etc/nginx/nginx.conf
```

パーミッション `644` の意味を分解します。

| 層 | 権限 | 実際の意味 |
|:---|:---|:---|
| 所有者（root） | `rw-` | root は読み書きできる |
| グループ（root） | `r--` | root グループは読み取りのみ |
| その他 | `r--` | **nginx プロセス（www-data ユーザー）は「その他」に該当 → 読み取り可** |

nginx プロセスは `www-data` ユーザーで動作しています（第9章で確認）。
`www-data` は root グループのメンバーではないため「その他」として扱われます。
`644` の「その他（o）に読み取り権がある」ことで、nginx が設定ファイルを読めます。

```bash
$ ls -la /var/www/html/
total 16
drwxr-xr-x 2 root root  4096 ... .
drwxr-xr-x 3 root root  4096 ... ..
-rw-r--r-- 1 root root 10671 ... index.nginx-debian.html
```

`index.nginx-debian.html` も `644` です。その他（www-data）が読み取れるので、ブラウザからアクセスすると nginx がこのファイルを読んでレスポンスを返せます。

もし誤って `chmod 600 /etc/nginx/nginx.conf` にすると、その他の読み取り権がなくなり、nginx が起動できなくなります。

```bash
# 試しにやってはいけない操作の例（説明のみ）
# sudo chmod 600 /etc/nginx/nginx.conf
# sudo service nginx restart
# → nginx が起動できなくなる
```

より安全な設定として、`www-data` グループを活用する方法もあります。

```bash
$ sudo chown root:www-data /var/www/html/index.nginx-debian.html
$ sudo chmod 640 /var/www/html/index.nginx-debian.html
# 640 = rw-r----- (所有者:rw, グループ:r, その他:---)
# www-data グループがファイルを読める。その他（一般ユーザー）は読めない。
```

`640` にすることで、www-data グループのプロセス（nginx）だけがファイルを読め、その他のユーザーからは見えなくなります。これが第10章で学んだグループとパーミッションを組み合わせた実用的な設定です。

---

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| シェルスクリプトに実行権を付けない | `./run.sh: Permission denied` | `chmod u+x run.sh` で実行権を付与する |
| 数値の計算ミスで 8 以上を使う | `chmod: invalid mode: '855'` | r=4, w=2, x=1 の合計は最大 7（3 ビット） |
| `chmod -R` を忘れてディレクトリ配下が変わらない | 変化なし（エラーは出ない） | `chmod -R 755 dir/` でディレクトリ配下も変更 |
| `777` を使う | 権限的には動作するがセキュリティホール | 所有者やグループの設定を見直し、必要最小限の権限にする |
| ディレクトリの `x` を外す | `cd: permission denied` / `ls: cannot open directory` | `chmod u+x dir/` または `chmod 755 dir/` で戻す |
| ホームディレクトリを `755` に変更する | エラーはないが他ユーザーに筒抜け | `700`（デフォルト）のまま使う |
| `chown` でコロンの前後にスペースを入れる | `chown: invalid user: 'tanaka : developers'` | `chown tanaka:developers`（スペースなし） |

---

## 類似比較

| コマンドA | コマンドB | 違い |
|:---|:---|:---|
| `chmod 755 ファイル` | `chmod u=rwx,go=rx ファイル` | 同じ効果。数値形式と記号形式の違い |
| `chmod u+x ファイル` | `chmod a+x ファイル` | `u+x` は所有者のみ、`a+x` は全員（所有者・グループ・その他）に実行権を追加 |
| `chown tanaka:devteam ファイル` | `chown tanaka ファイル && chgrp devteam ファイル` | 同じ効果。`chown` で所有者とグループを一度に変えられる |
| `chown -R` | `chmod -R` | どちらも再帰的に変更。`chown` は所有者、`chmod` は権限 |
| `ls -l` | `stat ファイル` | `ls -l` は簡潔な一覧表示、`stat` は数値パーミッション・タイムスタンプなど詳細情報 |

---

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| ファイルの権限確認 | `ls -l` / `stat` | エクスプローラー → プロパティ → セキュリティ | `ls -l` / `ls -le`（ACL付き） |
| 権限変更 | `chmod` | `icacls`（コマンド）/ プロパティのGUI | `chmod` |
| 所有者変更 | `chown` | `takeown`（コマンド）/ プロパティのGUI | `chown` |
| アクセス制御モデル | DAC（3層×3権限） + 特殊パーミッション | ACL（細粒度なアクセス制御リスト） | DAC + ACL（`ls -le` で確認） |

> **Windows との設計の違い**
> Windows の NTFS は ACL（アクセス制御リスト）方式で、ユーザーやグループごとに細かく権限を設定できます。
> Linux の DAC（Discretionary Access Control: 任意アクセス制御 — ファイルの所有者が権限を自由に設定できる方式）は「所有者・グループ・その他」という3層の単純な構造ですが、
> グループを適切に設計することで同等のアクセス制御が可能です。
> さらに SELinux・AppArmor（第16章）を追加することで、Linux でも MAC（Mandatory Access Control: 強制アクセス制御 — OS が一元的にアクセスを管理する方式）が使えます。

---

## 理解度チェック

1. `ls -l` の出力 `-rwxr-x--- 1 nginx www-data 1234 ... worker.sh` を読み解け。所有者・グループ・その他それぞれが何を実行できるか答えよ。

<details><summary>答え</summary>

- **所有者（nginx）**: `rwx` = 読み取り・書き込み・実行 すべて可能
- **グループ（www-data）**: `r-x` = 読み取り・実行は可能、書き込みは不可
- **その他**: `---` = 何もできない（読み取りも不可）

`www-data` グループのメンバーは `worker.sh` を読んで実行できますが、書き換えることはできません。
それ以外のユーザー（www-data グループ外）は一切アクセスできません。

</details>

2. シェルスクリプトを書いて `./deploy.sh` を実行したら `Permission denied` と表示された。原因と対処法を説明せよ。

<details><summary>答え</summary>

原因: 新しく作成したファイルには実行権（`x`）が付いていないため。

```bash
$ ls -l deploy.sh
-rw-r--r-- 1 vscode vscode 100 ... deploy.sh
#    ^ x がない
```

対処: `chmod` で実行権を付与する。

```bash
$ chmod u+x deploy.sh   # 所有者のみ実行可にする（推奨）
# または
$ chmod 755 deploy.sh   # 所有者は全権限、グループ・その他は読み取り・実行
```

</details>

3. umask が `0022` のとき、`touch newfile.txt` で作成されるファイルのパーミッションを計算し、記号形式で答えよ。

<details><summary>答え</summary>

ファイルの最大値 `0666`（rw-rw-rw-）から umask `0022` を引きます。

```text
  0666
- 0022
------
  0644
```

`0644` = `-rw-r--r--`

所有者は読み書き可、グループとその他は読み取りのみ。

</details>

4. `/usr/bin/passwd` に `-rwsr-xr-x` と表示されている。末尾の `s` は何を意味するか。なぜこのパーミッションが必要なのか説明せよ。

<details><summary>答え</summary>

`s` は SUID（Set User ID）ビットを表します。所有者（root）の `x` が `s` に変わっています。

SUID が設定されたファイルを実行すると、実行中は**ファイルの所有者（root）の権限**で動作します。

`passwd` コマンドは、一般ユーザーが自分のパスワードを変更するためのコマンドです。パスワードは `/etc/shadow`（root のみ書き込み可）に保存されています。

SUID があるため、一般ユーザーが `passwd` を実行すると root 権限で動作し、`/etc/shadow` を書き換えられます。SUID がなければ一般ユーザーは自分のパスワードを変更できません。

</details>

5. `/var/www/html/index.html` のパーミッションが `-rw-r--r--`（644）の場合、nginx（www-data ユーザー）はこのファイルを読み取れるか。理由とともに説明せよ。

<details><summary>答え</summary>

**読み取れる**。

`www-data` ユーザーはこのファイルの所有者でも、グループ（root）のメンバーでもないため「その他」として扱われます。

`644` のその他（`r--`）には読み取り権（`r`）があるため、nginx プロセス（www-data ユーザー）はファイルを読み取ってブラウザにレスポンスを返せます。

もしパーミッションが `600`（`rw-------`）だった場合、その他には権限がなく nginx は読み取れず、ブラウザには 403 Forbidden エラーが返ります。

</details>

---

次章では、これまでローカルで学んだ Linux の知識を、ネットワーク越しのサーバー操作に応用するための基礎（IP アドレス・サブネット・DNS）を学びます。

| [← 第10章: グループを管理する](../chapter-10/README.md) | [全章目次](../README.md) | [第12章: ネットワーク基礎（IP・サブネット・DNS） →](../chapter-12/README.md) |
|:---|:---:|---:|
