# 第2章: 基本コマンドを使いこなす

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第1章: シェルの種類と選び方

---

## 概要

Linux を操作する上で「毎日使う」基本コマンドを約30個まとめて学びます。
コマンドをバラバラに覚えるのではなく、**「Web サーバーのアクセスログを模したファイルを作成し、基本コマンドで分析する」** という一貫したシナリオを通して手を動かします。
この章を終えると、テキストファイルの作成・検索・加工・プロセス管理など、現場で日常的に行う操作が一通りできるようになります。

---

## 手順

まず練習ディレクトリを作成します。ホームディレクトリ（`~`）を直接散らかさないよう、専用フォルダを用意します。

> **「ディレクトリ」とは?**
> Windows のエクスプローラーで見える「フォルダ」と同じものです。Linux では「ディレクトリ」と呼びます。
> `~`（チルダ）は第1章で学んだとおり、ホームディレクトリ（`/home/vscode`）の略記号です。

```bash
$ mkdir -p ~/practice/chapter-02
$ cd ~/practice/chapter-02
$ pwd
/home/vscode/practice/chapter-02
```

### 2-1. ディレクトリとファイルの基本操作

#### ls — ファイル一覧を表示する

```bash
$ ls
（何も表示されない：ディレクトリが空のため）

$ ls -la
total 8
drwxr-xr-x 2 vscode vscode 4096 May 19 11:44 .
drwxr-xr-x 3 vscode vscode 4096 May 19 11:44 ..
```

`-la` オプションで**隠しファイルを含む詳細情報**が表示されます。各列の意味:

| 列 | 例 | 意味 |
|:---|:---|:---|
| 1列目 | `drwxr-xr-x` | ファイル種別とパーミッション。`d` = ディレクトリ、`-` = 通常ファイル |
| 2列目 | `3` | ハードリンク数 |
| 3列目 | `vscode` | 所有者名 |
| 4列目 | `vscode` | グループ名 |
| 5列目 | `4096` | サイズ（バイト）。`-lh` オプションで KB/MB 表示になる |
| 6〜8列目 | `May 19 11:44` | 最終更新日時 |
| 9列目 | `work` | ファイル名・ディレクトリ名 |

> **「ハードリンク数」とは?**
> 「同じファイルの実体を指している名前が何個あるか」を表す数値です。
> 作りたてのファイルは `1`（自分の名前1つ）、`ln` でハードリンクを追加するたびに増えます。
> ディレクトリは `.`（自分自身）と各サブディレクトリの `..` 分が加算されるため、最低 `2` から始まります。
> 上の例で `work` が `2` なのは「`work/` という名前」と「`work/` 内の `.`」の2つが同じ実体を指しているためです。

`.`（ドット）はカレントディレクトリ自身、`..` は1つ上の親ディレクトリを表します。

```bash
ls -lh          # サイズを KB/MB で表示
ls -R           # サブディレクトリを再帰的に表示
```

#### cd / pwd — ディレクトリを移動する

```bash
$ pwd              # 現在いる場所を表示（Print Working Directory）
/home/vscode/practice/chapter-02

$ cd work          # work ディレクトリへ移動
$ pwd
/home/vscode/practice/chapter-02/work

$ cd ..            # 1つ上に戻る
$ pwd
/home/vscode/practice/chapter-02

$ cd ~             # ホームディレクトリへ戻る
$ pwd
/home/vscode

$ cd -             # 直前にいたディレクトリへ戻る（cd - は前の場所へ「往復」する）
/home/vscode/practice/chapter-02
```

#### mkdir / rmdir — ディレクトリを作成・削除する

```bash
mkdir work                  # work ディレクトリを作成
mkdir -p logs/2024/01       # -p: 中間ディレクトリも含めて一括作成
rmdir logs/2024/01          # 空のディレクトリを削除（中身があると失敗する）
```

#### touch — 空のファイルを作成する

```bash
$ touch memo.txt              # 空のファイルを作成（既存ファイルに使うと更新日時を更新）
$ ls -la memo.txt
-rw-r--r-- 1 vscode vscode 0 May 19 11:46 memo.txt
```

#### cp — ファイルをコピーする

```bash
cp memo.txt memo_backup.txt        # ファイルをコピー
cp -r work work_backup             # -r: ディレクトリごとコピー（recursive）
cp -p memo.txt memo_copy.txt       # -p: 更新日時・パーミッションを保持してコピー
```

#### mv — ファイルを移動・リネームする

```bash
mv memo.txt notes.txt              # ファイル名を変更（move = 移動と同じコマンド）
mv notes.txt work/notes.txt        # work ディレクトリへ移動
```

#### rm — ファイルを削除する

> **危険: `rm` はごみ箱に入らない**
>
> Windows の「削除」はごみ箱に入るため元に戻せますが、Linux の `rm` は**即時削除**です。
> 特に `rm -rf` は指定したディレクトリを再帰的に（中身ごと）削除するため、
> **パスを必ず `ls` で確認してから実行する**習慣をつけてください。

```bash
$ rm memo_backup.txt                 # ファイルを削除
$ rm -i memo_copy.txt                # -i: 削除前に確認プロンプトを表示
rm: remove regular empty file 'memo_copy.txt'? y

$ rm -rf work_backup                 # -r: ディレクトリごと削除、-f: 確認なし強制削除
```

---

### 2-2. ファイルの中身を見る

これ以降の実習で使うモックログファイルを作成します。

> **`<< 'EOF'` とは?**
> これは「ヒアドキュメント」という複数行テキストの入力方法です。
> `EOF` と書いた行まで入力した内容がコマンドに渡されます。
> `cat > ファイル名` と組み合わせることでファイルを作成できます。

```bash
$ cat > ~/practice/chapter-02/access.log << 'EOF'
2024-01-15 10:23:45 192.168.1.10 GET /index.html 200 1234
2024-01-15 10:24:01 192.168.1.11 GET /about.html 200 567
2024-01-15 10:24:15 192.168.1.10 POST /login 302 89
2024-01-15 10:24:30 192.168.1.12 GET /admin 403 234
2024-01-15 10:25:00 192.168.1.11 GET /images/logo.png 200 8901
2024-01-15 10:25:12 192.168.1.13 GET /XXXXXX 404 134
2024-01-15 10:25:45 192.168.1.10 GET /dashboard 200 3456
2024-01-15 10:26:01 192.168.1.14 GET /api/users 200 9012
2024-01-15 10:26:30 192.168.1.12 POST /api/login 200 456
2024-01-15 10:27:00 192.168.1.13 GET /contact.html 200 678
2024-01-15 10:27:15 192.168.1.11 GET /YYYYYYY 404 134
2024-01-15 10:27:45 192.168.1.10 GET /logout 302 45
2024-01-15 10:28:00 192.168.1.15 GET /index.html 200 1234
2024-01-15 10:28:30 192.168.1.14 POST /api/data 500 345
2024-01-15 10:29:00 192.168.1.12 GET /error 500 234
EOF
```

各列の意味: `日付 時刻 IPアドレス メソッド URL ステータスコード バイト数`

#### cat / tac — ファイルの中身をすべて表示する

```bash
$ cat access.log          # 先頭から末尾へ表示
2024-01-15 10:23:45 192.168.1.10 GET /index.html 200 1234
...

$ tac access.log          # 末尾から先頭へ（逆順）表示
2024-01-15 10:29:00 192.168.1.12 GET /error 500 234
2024-01-15 10:28:30 192.168.1.14 POST /api/data 500 345
2024-01-15 10:28:00 192.168.1.15 GET /index.html 200 1234
```

`cat` は小さなファイルの確認に使います。大きなファイル（数万行以上）を `cat` すると画面が一瞬で流れるため、後述の `less` を使います。

#### head / tail — 先頭・末尾だけ表示する

```bash
$ head -n 3 access.log    # 先頭3行を表示
2024-01-15 10:23:45 192.168.1.10 GET /index.html 200 1234
2024-01-15 10:24:01 192.168.1.11 GET /about.html 200 567
2024-01-15 10:24:15 192.168.1.10 POST /login 302 89

$ tail -n 3 access.log    # 末尾3行を表示
2024-01-15 10:28:00 192.168.1.15 GET /index.html 200 1234
2024-01-15 10:28:30 192.168.1.14 POST /api/data 500 345
2024-01-15 10:29:00 192.168.1.12 GET /error 500 234

$ tail -f access.log      # ファイルへの追記をリアルタイムで表示し続ける（Ctrl+C で終了）
```

`tail -f` はログを監視するときによく使います。実行中のサーバーログをリアルタイムで見たいときに使います。

#### less / more — スクロールして読む

```bash
less access.log         # スクロール表示（↑↓キーで移動、q で終了、/で検索）
more access.log         # 1画面ずつ表示（スペースで次のページ）
```

`less` は画面に収まらない大きなファイルを読むときに使います。`more` は古いコマンドで基本的に `less` の方が高機能です。

#### wc — 行数・単語数・バイト数を数える

```bash
$ wc -l access.log        # 行数を表示
15 access.log

$ wc -w access.log        # 単語数を表示
105 access.log

$ wc -c access.log        # バイト数を表示
837 access.log
```

---

### 2-3. テキストを検索・絞り込む

#### grep — 特定のパターンを含む行を検索する

```bash
$ grep '404' access.log
2024-01-15 10:25:12 192.168.1.13 GET /XXXXXX 404 134
2024-01-15 10:27:15 192.168.1.11 GET /YYYYYYY 404 134

$ grep -c '200' access.log      # -c: マッチした行数を表示
8

$ grep -E '500|404' access.log  # -E: 正規表現（500 または 404 を含む行）
2024-01-15 10:25:12 192.168.1.13 GET /XXXXXX 404 134
2024-01-15 10:27:15 192.168.1.11 GET /YYYYYYY 404 134
2024-01-15 10:28:30 192.168.1.14 POST /api/data 500 345
2024-01-15 10:29:00 192.168.1.12 GET /error 500 234

$ grep -r 'error' ~/practice/chapter-02/    # -r: ディレクトリを再帰的に検索
```

> **パターンはシングルクォートで囲む習慣をつける**
> `grep 404 access.log` でも動きますが、パターンに特殊文字（`*`, `?`, `[` 等）が入ると
> シェルが展開してしまい予期せぬ動作になります。`'パターン'` で囲むのが安全です。

#### sort / uniq — 並び替え・重複除去

HTTP ステータスコードの出現回数を集計してみましょう。

```bash
$ cut -d' ' -f6 access.log | sort
200
200
200
200
200
200
200
200
302
302
403
404
404
500
500

$ cut -d' ' -f6 access.log | sort | uniq -c | sort -rn
      8 200
      2 500
      2 404
      2 302
      1 403
```

- `sort` : 昇順に並び替え（`-r` で逆順、`-n` で数値として比較）
- `uniq -c` : 連続する重複行を1行にまとめ、出現回数を先頭に付与する（`sort` 後に使う）

#### cut — 特定の列だけ切り出す

```bash
$ cut -d' ' -f4 access.log    # スペース区切りで4列目（メソッド）を取得
GET
GET
POST
GET
...

$ cut -d: -f1 /etc/passwd | head -5    # `:` 区切りで1列目（ユーザー名）を取得
root
daemon
bin
sys
sync
```

`-d` で区切り文字を、`-f` で取得する列番号を指定します。

---

### 2-4. ファイルを探す

#### find — ファイルを検索する

```bash
$ find ~/practice/chapter-02 -name '*.log'
/home/vscode/practice/chapter-02/access.log

$ find ~/practice/chapter-02 -name '*.log' -type f    # -type f: 通常ファイルのみ
$ find ~/practice/chapter-02 -type f -mtime -1        # 1日以内に変更されたファイル
$ find ~/practice/chapter-02 -name '*.log' 2>/dev/null  # エラーを非表示（後述）
```

`find` はシステム全体を探すと `Permission denied` が大量に出ることがあります。`2>/dev/null` で抑制できます（2-5 で学びます）。

#### which / whereis — コマンドの場所を探す

```bash
$ which grep                  # grep コマンドの実行ファイルのパスを表示
/usr/bin/grep

$ whereis grep                # grep のバイナリ・マニュアルの場所をまとめて表示
grep: /usr/bin/grep /usr/share/man/man1/grep.1.gz /usr/share/info/grep.info.gz
```

「このコマンドはどこにある?」「インストールされているか?」を確認するときに使います。

---

### 2-5. 出力をつなぐ・保存する

Linux コマンドの出口は**2本のチャンネル**があります。この概念がリダイレクトを理解する鍵です。

#### 標準出力と標準エラー出力

```text
コマンド ─── 標準出力（stdout, 1番） ─→ 画面（普通の結果）
         └── 標準エラー出力（stderr, 2番） ─→ 画面（エラーメッセージ）
```

普段はどちらも「画面」へ出力されるため1本に見えますが、実は**別々のチャンネル**です。
実際に両者を区別してみましょう:

```bash
$ cat /etc/hostname XXXX_NOT_EXIST
codespaces-bc9305                                        ← 標準出力（stdout）
cat: XXXX_NOT_EXIST: No such file or directory           ← 標準エラー出力（stderr）
```

> `/etc/hostname` に表示されるホスト名（`codespaces-bc9305` の部分）は、Codespaces の起動ごとに異なる値が表示されます。

`>` で出力をファイルに保存すると、**stdout だけがファイルに入り、stderr は画面に残る**ことが分かります:

```bash
$ cat /etc/hostname XXXX_NOT_EXIST > output.txt
cat: XXXX_NOT_EXIST: No such file or directory    ← stderr は画面のまま

$ cat output.txt
codespaces-bc9305                                 ← stdout だけファイルに入っている
```

#### リダイレクト — 出力先を変える

```bash
ls -la > result.txt          # stdout をファイルに上書き保存（ファイルがなければ作成）
ls -la >> result.txt         # stdout をファイルに追記（既存内容を消さない）
grep '404' access.log 2> error.log     # stderr だけをファイルに保存
grep '404' access.log > out.txt 2>&1  # stdout と stderr を両方まとめてファイルに保存
```

**`2>&1` の読み方:** 「stderr（2番）を stdout（1番）と同じ行き先に向ける」
`2>&1` は `>` の**後ろ**に書く必要があります（`2>&1 > out.txt` の順序は誤り）。

```text
$ command > out.txt 2>&1
                 │     └ stderr を stdout と同じ場所へ
                 └ stdout をファイルへ
```

#### /dev/null — 捨て場所

`/dev/null` は出力を完全に捨てる特殊なファイルです。「Linux のブラックホール」と覚えてください。

```bash
grep '404' access.log > /dev/null          # stdout を捨てる（エラーだけ見たいとき）
find / -name '*.log' 2>/dev/null           # Permission denied を全部捨てる
command > /dev/null 2>&1                   # 出力を全て捨てる（バッチ処理などで使う）
```

#### パイプ — コマンドをつなぐ

`|`（パイプ）はコマンドの標準出力を次のコマンドの標準入力に繋ぎます。複数のコマンドを組み合わせることで強力な処理ができます。

```bash
$ cat access.log | grep '200' | wc -l
8

$ cat access.log | grep -E '500|404' | cut -d' ' -f4,6 | sort
GET 404
GET 404
GET 500
POST 500
```

コマンドを `|` で繋ぐ連鎖を**パイプライン**と呼びます。

> **パイプは stdout だけを渡す**
> `|` は stdout だけを次のコマンドに渡します。stderr は素通りして画面に出ます。
> stderr もパイプに流したい場合は `command 2>&1 | next` と書きます。

#### tee — 画面に表示しながらファイルにも保存する

```bash
$ cat access.log | grep '404' | tee found_404.txt
2024-01-15 10:25:12 192.168.1.13 GET /XXXXXX 404 134
2024-01-15 10:27:15 192.168.1.11 GET /YYYYYYY 404 134

$ cat found_404.txt          # 同じ内容がファイルにも保存されている
2024-01-15 10:25:12 192.168.1.13 GET /XXXXXX 404 134
2024-01-15 10:27:15 192.168.1.11 GET /YYYYYYY 404 134
```

`tee` は画面確認と記録を同時に行いたいときに使います。

---

### 2-6. テキストを加工する

#### sed — テキストを置換・削除する

`sed`（Stream EDitor）は行単位でテキストを加工します。

```bash
$ sed 's/GET/HTTP-GET/' access.log | head -3
2024-01-15 10:23:45 192.168.1.10 HTTP-GET /index.html 200 1234
2024-01-15 10:24:01 192.168.1.11 HTTP-GET /about.html 200 567
2024-01-15 10:24:15 192.168.1.10 POST /login 302 89

$ sed 's/192\.168\.1\.[0-9]*/CLIENT/g' access.log | head -3  # IP アドレスをマスク
2024-01-15 10:23:45 CLIENT GET /index.html 200 1234
2024-01-15 10:24:01 CLIENT GET /about.html 200 567
2024-01-15 10:24:15 CLIENT POST /login 302 89
```

`s/置換前/置換後/` が基本構文。末尾の `g` で行内のすべてにマッチを置換します（なければ最初の1つだけ）。

#### awk — 列単位でデータを処理する

`awk` は列（フィールド）単位でデータを処理します。`$1`, `$2` … で列番号を指定します。

```bash
$ awk '{print $4, $6}' access.log | head -5    # 4列目（メソッド）と6列目（ステータス）
GET 200
GET 200
POST 302
GET 403
GET 200

$ awk '$6 == "500" {print $0}' access.log      # 6列目が 500 の行を表示
2024-01-15 10:28:30 192.168.1.14 POST /api/data 500 345
2024-01-15 10:29:00 192.168.1.12 GET /error 500 234
```

#### xargs — 標準入力をコマンドの引数に変換する

パイプ（`|`）はコマンドの「標準入力」に渡しますが、`wc -l` や `rm` のようにファイル名を引数として受け取るコマンドにはパイプだけでは繋げません。`xargs` はパイプの出力を「引数」に変換する橋渡し役です。

```bash
$ ls ~/practice/chapter-02/*.log | xargs wc -l    # 各ログファイルの行数を一括確認
  15 /home/vscode/practice/chapter-02/access.log
  15 total
```

> **2-8 節でリンクファイルを作成した後は** `access_hard.log`・`access_link.log` も含めた複数ファイルを一括確認できます。

```bash
$ find ~/practice/chapter-02 -name '*.txt' | xargs grep 'cherry'
/home/vscode/practice/chapter-02/file_b.txt:cherry
/home/vscode/practice/chapter-02/file_a.txt:cherry
```

> **上記の例は 2-8 節でテキストファイル（`file_a.txt`・`file_b.txt`）を作成した後に試せます。**

`find` や `ls` の出力を次のコマンドの引数として渡すときに使います。

---

### 2-7. プロセスとリソースを確認する

> **「プロセス」とは?**
> プログラムの実行単位です。Windows のタスクマネージャー（Ctrl+Shift+Esc）を開いたときに
> 一覧表示される各アプリケーション・プログラムが、それぞれ1つのプロセスです。
> Linux では `ps` コマンドで確認できます。
>
> **「PID」とは?**
> プロセス ID（Process ID）の略で、OS が各プロセスに割り当てる番号です。
> Windows タスクマネージャーの「PID」列と同じ概念です。

#### ps — プロセス一覧を表示する

```bash
$ ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   2672  1696 ?        Ss   09:41   0:02 /bin/sh -c ...
vscode        91  0.0  0.0   2672  1844 ?        Ss   09:41   0:00 /bin/sh
...

$ ps -ef
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 09:41 ?        00:00:02 /bin/sh -c ...
vscode        91       0  0 09:41 ?        00:00:00 /bin/sh
...
```

> **出力は環境により異なります**
> PID の番号・COMMAND の内容・時刻はすべて実行環境によって変わります。
> Codespaces では PID 1 のコマンドがコンテナ起動スクリプトになるため、長い文字列が表示されます（`...` で省略）。

| 列 | 意味 |
|:---|:---|
| `USER` / `UID` | プロセスの所有者 |
| `PID` | プロセス ID |
| `%CPU` | CPU 使用率 |
| `%MEM` | メモリ使用率 |
| `STAT` | 状態（`S`=スリープ中, `R`=実行中, `Z`=ゾンビ） |
| `COMMAND` / `CMD` | 実行されているコマンド |

#### top — リソース使用状況をリアルタイムで確認する

```bash
top    # リアルタイムで更新。q で終了、k で kill、1 で CPU コア別表示
```

`top` は CPU・メモリ使用率の高いプロセスを探すときに使います。終了は `q` キー。

#### kill / killall — プロセスを終了させる

バックグラウンドプロセスを起動して、kill で終了させてみます:

> **「シグナル」とは?**
> OS がプロセスに送る「通知・命令」のことです。プロセスはシグナルを受け取ると、それに応じた処理を行います。
> `SIGTERM`（シグナル番号 15）は「終了してください」というリクエストで、プロセスが後処理をしてから終了できます。
> `SIGKILL`（シグナル番号 9）は「即時強制終了」で、プロセスは後処理なしに強制停止されます。
> Windows の「タスクの終了」と「タスクの強制終了」に相当するイメージです。

```bash
$ sleep 30 &            # sleep 30 をバックグラウンド（&）で実行
[1] 53182               # PID が表示される

$ ps aux | grep sleep
vscode   53182  0.0  0.0   2296  1292 ?        S    11:45   0:00 sleep 30

$ kill 53182            # PID を指定してシグナルを送る（デフォルトは SIGTERM）
$ kill -9 53182         # 強制終了（SIGKILL）。通常の kill で終わらないときに使う
$ killall sleep         # プロセス名でまとめて終了させる
```

#### df — ディスク容量を確認する

```bash
$ df -h                 # -h: KB/GB 等の人が読みやすい単位で表示
Filesystem      Size  Used Avail Use% Mounted on
overlay          32G  2.9G   27G  10% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/root        29G   22G  7.4G  75% /vscode
/dev/loop4       32G  2.9G   27G  10% /workspaces
/dev/sdb1        44G  2.5G   40G   6% /tmp
```

> **表示内容は環境により異なります**
> デバイス名（`/dev/root`・`/dev/loop4` 等）やサイズは Codespaces の起動タイミングやプランによって変わります。
> `Use%` が 80% 以上の行が多い場合はディスク容量が不足しています。

#### du — ディレクトリが使っているサイズを確認する

```bash
$ du -sh ~/practice/           # -s: 合計のみ、-h: 人が読みやすい単位
16K /home/vscode/practice/

$ du -sh ~/practice/chapter-02/*    # ディレクトリ内の各ファイル・フォルダのサイズ
```

#### free — メモリ使用量を確認する

```bash
$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7.8Gi       3.2Gi       380Mi        63Mi       4.5Gi       4.6Gi
Swap:             0B          0B          0B
```

> **Swap が 0B について**
> Codespaces のコンテナ環境ではスワップ（RAM 不足時にディスクを一時的に RAM の代わりに使う領域）が設定されていません。
> 物理マシンや VPS では `Swap: 1.0Gi` のように設定されていることが多いです。

#### uptime / uname — システム情報を確認する

```bash
$ uptime              # システムの稼働時間とロードアベレージ（CPU 負荷）
 11:44:58 up  5:36,  0 users,  load average: 0.79, 0.64, 0.67
#                                            ↑1分  ↑5分  ↑15分 の CPU 負荷平均

$ uname -r            # カーネルバージョンのみ
6.8.0-1052-azure

$ uname -a            # 全情報（OS名・ホスト名・カーネル・アーキテクチャ等）
Linux codespaces-XXXXXX 6.8.0-1052-azure #58~22.04.1-Ubuntu SMP Thu Mar 26 05:02:21 UTC 2026 x86_64 GNU/Linux
```

> **「カーネル」とは?**
> OS の核心部分で、ハードウェアとソフトウェアの仲介役です。
> `uname -r` で表示されるのは Linux カーネルのバージョンです。
> `6.8.0-1052-azure` の `-azure` サフィックスは Azure 環境向けに最適化されたカーネルであることを示します。
> `x86_64` は Intel/AMD 系の 64 ビットアーキテクチャです（ホスト名・日付は実行環境により異なります）。

---

### 2-8. ファイルのリンクと差分

#### diff — ファイルの差分を確認する

```bash
$ cat > ~/practice/chapter-02/file_a.txt << 'EOF'
apple
banana
cherry
date
EOF

$ cat > ~/practice/chapter-02/file_b.txt << 'EOF'
apple
blueberry
cherry
elderberry
EOF

$ diff file_a.txt file_b.txt
2c2
< banana
---
> blueberry
4c4
< date
---
> elderberry
```

`<` は file_a.txt のみ、`>` は file_b.txt のみ、`c` は「変更（change）」を意味します。

```bash
$ diff -u file_a.txt file_b.txt    # -u: unified 形式（GitHub の差分表示に似た形式）
--- file_a.txt 2026-05-19 11:45:02.860599001 +0000
+++ file_b.txt 2026-05-19 11:45:02.861599001 +0000
@@ -1,4 +1,4 @@
 apple
-banana
+blueberry
 cherry
-date
+elderberry
```

`-` は削除行、`+` は追加行。`git diff` の出力と同じ形式です。

#### ln — リンクを作成する

> **「シンボリックリンク」とは?**
> Windows のショートカット（`.lnk` ファイル）に相当します。
> 元のファイルへの「参照（ポインタ）」を作ります。
>
> **「ハードリンク」とは?**
> 同じファイルの実体（データ）を別の名前で参照する仕組みです。
> ショートカットとは異なり、元のファイルを削除してもデータは残ります。

```bash
$ ln -s access.log access_link.log     # シンボリックリンクを作成
$ ls -la access_link.log
lrwxrwxrwx 1 vscode vscode 10 May 19 11:45 access_link.log -> access.log

$ readlink access_link.log             # リンクの参照先を表示
access.log

$ ln access.log access_hard.log        # ハードリンクを作成
$ ls -lai access.log access_hard.log   # 同じ inode 番号（左端の数字）に注目
2277121 -rw-r--r-- 2 vscode vscode 837 May 19 11:44 access.log
2277121 -rw-r--r-- 2 vscode vscode 837 May 19 11:44 access_hard.log
```

左端の数字（`2277121`）が**inode 番号**（ファイルの実体を識別する番号）です。ハードリンクは同じ inode を共有しているため、どちらを編集しても内容が同期されます。

---

### 2-9. 日時と作業履歴

#### date — 現在日時を表示する

```bash
$ date
Tue May 19 11:45:10 UTC 2026

$ date "+%Y-%m-%d"
2026-05-19

$ date "+%Y-%m-%d %H:%M:%S"
2026-05-19 11:45:10
```

書式指定文字: `%Y`=年、`%m`=月、`%d`=日、`%H`=時、`%M`=分、`%S`=秒

#### history — コマンド履歴を確認する

`history` はこれまで入力したコマンドの履歴を表示します。
`~/.bash_history` に保存されているため、ターミナルを閉じても残ります。

```bash
$ history | tail -10      # 最近10件の履歴を表示
   45  ls -la
   46  cat access.log
   47  grep '404' access.log
   48  cut -d' ' -f6 access.log | sort | uniq -c | sort -rn
   49  diff file_a.txt file_b.txt
   50  history | tail -10

$ !!                        # 直前のコマンドを再実行
$ !46                       # 履歴番号 46 のコマンドを再実行（cat access.log）
$ !grep                     # 最後に実行した grep から始まるコマンドを再実行
```

> **`cal` コマンドについて**
> カレンダーを表示する `cal` コマンドは、この Codespaces 環境にはデフォルトで入っていません。
> 第4章（パッケージ管理）で `apt install bsdmainutils` を学んだ後にインストールできます。

---

## よくあるミス

| ミス | 内容 | 対処 |
|:---|:---|:---|
| `rm -rf` でパスを間違えた | 確認なく即削除、元に戻せない | 実行前に `ls パス` で存在確認。`rm -i` で確認付き削除 |
| `>` でファイルを上書きしてしまった | 既存内容が消える | 追記は `>>` を使う。`set -o noclobber` で `>` の上書きを禁止できる |
| `grep` パターンにクォートを忘れた | `*` 等の特殊文字がシェルに展開される | パターンは常に `'シングルクォート'` で囲む |
| `find` が `Permission denied` を大量に出す | root 所有ディレクトリへのアクセス制限 | `2>/dev/null` でエラーを捨てる |
| `>` でリダイレクトしたのにエラーがファイルに入らない | `>` は stdout のみ捉える。stderr は画面に残る | `> ファイル 2>&1` で stderr も合わせてリダイレクト |
| `ln` でディレクトリにハードリンクを作ろうとした | ハードリンクはディレクトリに不可 | ディレクトリには `ln -s`（シンボリックリンク）を使う |
| `kill` でプロセスが終わらない | SIGTERM を無視するプロセスがある | `kill -9 PID` で SIGKILL（強制終了）を送る |
| `ps aux` の出力列の意味が分からない | 列が多くて読みにくい | `ps aux \| grep プロセス名` で絞り込む |

---

## 類似比較

| コマンド A | コマンド B | 違い |
|:---|:---|:---|
| `cat` | `less` | `cat` は全行を一気に出力。`less` はスクロール表示。大きなファイルは `less` を使う |
| `>` | `>>` | `>` は上書き（既存内容が消える）。`>>` は追記（既存内容の末尾に追加） |
| `grep -F` | `grep -E` | `-F` は固定文字列（特殊文字をそのまま検索）。`-E` は拡張正規表現 |
| `find` | `which` | `find` はファイルを名前・種類・日時で検索する汎用コマンド。`which` はコマンドの実行ファイルの場所を探す |
| `ln -s` | `ln` | `ln -s` はシンボリックリンク（ショートカット相当）。`ln` はハードリンク（実体への別名） |
| `ps aux` | `ps -ef` | BSD 形式 vs POSIX 形式。表示列名が異なるが内容はほぼ同じ。Linux ではどちらも使える |
| `kill` | `killall` | `kill` は PID で指定。`killall` はプロセス名で一括指定 |
| `df -h` | `du -sh` | `df` はディスク全体の空き容量。`du` は特定ディレクトリが使っているサイズ |
| `sort` | `sort -n` | `sort` は文字列として比較。`sort -n` は数値として比較（`10 > 9` になる） |

---

## 他OSとの比較

| 操作 | Linux（Debian） | Windows（cmd.exe） | macOS |
|:---|:---|:---|:---|
| ファイル一覧 | `ls -la` | `dir` | `ls -la` |
| ディレクトリ作成 | `mkdir -p` | `mkdir` | `mkdir -p` |
| ファイル削除 | `rm` | `del`（ファイル）/ `rd /s`（フォルダ） | `rm` |
| ファイル移動・リネーム | `mv` | `move` / `rename` | `mv` |
| ファイルコピー | `cp -r` | `copy`（ファイル）/ `xcopy /s`（フォルダ） | `cp -r` |
| テキスト表示 | `cat` | `type` | `cat` |
| テキスト検索 | `grep` | `findstr` | `grep` |
| ファイル検索 | `find . -name "*.txt"` | `dir /s *.txt` | `find . -name "*.txt"` |
| テキスト置換 | `sed 's/old/new/'` | PowerShell の `-replace` | `sed` / `gsed` |
| プロセス確認 | `ps aux` | `tasklist` | `ps aux` |
| プロセス終了 | `kill PID` | `taskkill /PID 番号 /F` | `kill PID` |
| ディスク容量 | `df -h` | `wmic logicaldisk get size,freespace` | `df -h` |
| ディレクトリ使用量 | `du -sh` | PowerShell の `Get-ChildItem` | `du -sh` |
| メモリ確認 | `free -h` | `taskmgr`（GUI）/ `systeminfo` | `vm_stat` |
| パイプ | `\|` | `\|`（同じ記号だが機能差あり） | `\|` |
| リダイレクト | `>`, `>>`, `2>` | `>`, `>>` のみ（`2>` は PowerShell のみ） | `>`, `>>`, `2>` |

---

## 理解度チェック

1. `ls -la` の出力で、行頭の `d` と `-` はそれぞれ何を意味するか?

<details><summary>答え</summary>

`d` はディレクトリ（フォルダ）、`-` は通常ファイルを意味します。
`ls -la` の1列目はファイルの種別とパーミッション（読み書き実行の権限）を表しています。
パーミッションの詳細は第11章で学びます。

</details>

2. `cat access.log | grep 'ERROR' | wc -l` というコマンドは何をするか説明せよ。

<details><summary>答え</summary>

3つのコマンドをパイプで繋いでいます:

1. `cat access.log` — ファイルを全行出力する
2. `| grep 'ERROR'` — `ERROR` を含む行だけに絞り込む
3. `| wc -l` — 絞り込まれた行数を数える

つまり「`access.log` の中に `ERROR` を含む行が何行あるか」を数えるコマンドです。

</details>

3. `command > output.txt 2>&1` はどのような動作をするか? `command > output.txt` との違いを説明せよ。

<details><summary>答え</summary>

- `command > output.txt` — 標準出力（stdout）だけをファイルに保存。標準エラー出力（stderr）は画面に表示されたまま。
- `command > output.txt 2>&1` — stdout と stderr の両方をファイルに保存。画面には何も表示されない。

`2>&1` は「stderr（2番）を stdout（1番）と同じ行き先（output.txt）に向ける」という意味です。

</details>

4. コマンドの出力をファイルに保存しながら、同時に画面にも表示させたい。どうするか?

<details><summary>答え</summary>

`tee` コマンドを使います。

```bash
command | tee output.txt
```

`tee` は入力を画面と指定したファイルの両方に出力します。
`tee -a output.txt` を指定すると追記モードになります。

</details>

5. `ps aux` でプロセスを確認し、`sleep 100` というプロセスを終了させる手順を説明せよ。

<details><summary>答え</summary>

```bash
# 1. sleep 100 プロセスを探す
$ ps aux | grep sleep
vscode   12345  0.0  0.0   2296  1292 ?  S  12:00  0:00 sleep 100

# 2. PID（12345）を確認して kill で終了させる
$ kill 12345

# 3. kill で終わらない場合は強制終了
$ kill -9 12345
```

`kill` はデフォルトで SIGTERM（終了リクエスト）を送ります。プロセスが応答しない場合は `kill -9`（SIGKILL：強制終了）を使います。

</details>

次章では、Linux のディレクトリ構成（FHS）を体系的に学び、`/etc`・`/var`・`/usr` など各ディレクトリが何のために存在するかを理解します。

---

| [← 第1章: シェルの種類と選び方](../chapter-01/README.md) | [全章目次](../README.md) | [第3章: ディレクトリ構成を知る →](../chapter-03/README.md) |
|:---|:---:|---:|
