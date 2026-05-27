# 第7章: 環境変数・入力補完・カラー表示

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第6章: シェル環境をカスタマイズする

---

## 概要

シェルが動作するとき、裏側では多くの「環境変数」が設定されています。
`PATH`・`HOME`・`EDITOR` など、コマンドの動作を左右するこれらの変数を正しく理解することは、Linux 操作の基本です。

この章では環境変数の概念（シェル変数との違い・子プロセスへの継承）を体験し、主要な変数を確認・設定します。
また、Tab 補完の仕組みと、章末では第6章で設定したカラー表示の「なぜ」を ANSI エスケープコードを通じて理解します。

---

## 手順

### 7-1. 環境変数とシェル変数の違いを理解する

bash の変数には2種類あります。

| 種類 | 設定方法 | 有効範囲 |
|:---|:---|:---|
| **シェル変数** | `MY_VAR="value"` | 現在のシェルのみ |
| **環境変数** | `export MY_VAR="value"` | 現在のシェル＋子プロセス |

#### 実習: 継承されるかどうかを確かめる

```bash
# シェル変数を設定
$ MY_LOCAL="local_val"
$ echo $MY_LOCAL
local_val

# 子シェルで確認 — 継承されない
$ bash -c 'echo $MY_LOCAL'
（空白）

# 環境変数を設定
$ export MY_EXPORT="export_val"
$ echo $MY_EXPORT
export_val

# 子シェルで確認 — 継承される
$ bash -c 'echo $MY_EXPORT'
export_val
```

`bash -c '...'` は**子プロセス**（現在のシェルから新たに起動される別のシェルプロセス）を作ってコマンドを実行します。Windows のタスクマネージャーで言えば、親アプリが子アプリを起動するイメージです。
`export` した変数だけが子シェルに引き継がれることが確認できます。

#### 子プロセスから親へは伝播しない

```bash
# 子シェルで新しい変数を設定しても親には届かない
$ bash -c 'export CHILD_VAR="from_child"'
$ echo $CHILD_VAR
（空白）
```

環境変数の継承は**親 → 子の一方通行**です。

#### 変数を削除する

```bash
$ unset MY_EXPORT
$ echo $MY_EXPORT
（空白）
```

#### 第6章の操作を振り返る

第6章で `~/.bashrc` に書いた2行の意味がここで明確になります:

```bash
unset PROMPT_DIRTRIM         # PROMPT_DIRTRIM というシェル変数を削除する
export PATH="/usr/local/nginx/sbin:$PATH"  # PATH を環境変数として設定し子プロセスへ継承させる
```

`PATH` に `export` が必要な理由は、シェルから起動するすべてのコマンド（子プロセス）がこの値を参照するためです。

---

### 7-2. 主要な環境変数を確認する

#### env — 全環境変数を表示する

```bash
$ env
SHELL=/bin/bash
HOSTNAME=codespaces-abc123
HOME=/home/vscode
USER=vscode
PATH=/usr/local/nginx/sbin:/vscode/vscode-server/bin/.../remote-cli:/usr/local/sbin:...
TERM=xterm-256color
（以下省略）
```

> **Codespaces 環境では変数が多数表示される**
> `env` を実行すると `VSCODE_ESM_ENTRYPOINT`・`SSH_AUTH_SOCK` など Codespaces やツールの内部変数が大量に表示されます。
> 確認したい変数が埋もれてしまうため、実際の作業では `env | grep` で絞り込むのが実用的です。

```bash
$ env | grep PATH
PATH=/usr/local/nginx/sbin:/vscode/vscode-server/bin/.../remote-cli:/usr/local/sbin:...

# 複数の変数をまとめて確認する
$ env | grep -E '^(PATH|HOME|USER|SHELL|LANG|EDITOR|TERM)='
HOME=/home/vscode
PATH=/usr/local/nginx/sbin:/usr/local/sbin:/usr/local/bin:...
SHELL=/bin/bash
TERM=xterm-256color
USER=vscode
```

#### printenv — 特定の変数を取り出す

```bash
$ printenv PATH
/usr/local/nginx/sbin:/vscode/vscode-server/bin/.../remote-cli:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/vscode/.local/bin

$ printenv HOME
/home/vscode
```

> **Codespaces の PATH には長いパスが含まれる**
> Codespaces では VS Code サーバーやツール用のパス（`/vscode/vscode-server/...`）が自動で追加されます。
> 第6章で追加した `/usr/local/nginx/sbin` が含まれているかどうかを確認することが目的なので、先頭にそのパスがあれば正常です。

`echo $PATH` と同じ結果が得られますが、`printenv` はシェル変数を参照せず環境変数のみを表示します。

#### 主要な環境変数

| 変数 | 内容 | 確認コマンド |
|:---|:---|:---|
| `PATH` | コマンドを検索するディレクトリ一覧（`:`区切り） | `printenv PATH` |
| `HOME` | ホームディレクトリのパス（`~` と等価） | `echo $HOME` |
| `USER` | 現在のユーザー名 | `echo $USER` |
| `SHELL` | 現在のシェルのパス | `echo $SHELL` |
| `LANG` | ロケール設定（文字コード・言語）※未設定の場合は空。第8章で設定する | `echo $LANG` |
| `EDITOR` | デフォルトエディタ | `echo $EDITOR` |
| `TERM` | 端末の種類（色対応などに影響） | `echo $TERM` |

> **`echo $VAR` と `printenv VAR` の違い**
> `echo $VAR` はシェルが変数を展開してから `echo` に渡します。シェル変数も環境変数も表示されます。
> `printenv VAR` は環境変数のみを表示します。変数がシェル変数（`export` なし）の場合は何も表示されません。

#### Nginx との接点: PATH が正しく設定されているか確認する

> **新しいターミナルで確認する**
> `~/.bashrc` の変更は、そのファイルを `source` したセッション（または新しく開いたターミナル）に反映されます。
> 以下の確認は**新しいターミナルタブを開いてから**実行してください。

```bash
$ printenv PATH
/usr/local/nginx/sbin:/vscode/vscode-server/bin/.../remote-cli:/usr/local/sbin:/usr/local/bin:...
```

`/usr/local/nginx/sbin` が先頭に含まれていれば、第6章の設定が正しく反映されています。
Codespaces 固有のパス（`/vscode/...`）が間に挟まっていても問題ありません。

```bash
$ which nginx
（何も表示されない — exit code 1）
```

`which` は PATH を順番に検索してコマンドを探します。
現時点では `/usr/local/nginx/sbin/` ディレクトリ自体が存在しないため何も返りませんが、
第17章でソースビルドを完了すると、このパスに `nginx` の実行ファイルが配置され、自動的に `nginx` コマンドが使えるようになります。

---

### 7-3. EDITOR 環境変数を設定する

`EDITOR` は「システムがエディタを自動起動するとき」に参照される変数です。

#### 現在の設定を確認する

```bash
$ echo $EDITOR
（設定されていない場合は空白）
```

#### `~/.bashrc` に追記して永続化する

```bash
$ vim ~/.bashrc
```

ファイルの末尾に追記します:

```bash
# Default editor
export EDITOR=vim
```

```bash
$ source ~/.bashrc
$ echo $EDITOR
vim
```

#### EDITOR が使われる場面

| コマンド | 用途 | 解説される章 |
|:---|:---|:---|
| `git commit` | コミットメッセージの入力 | — |
| `crontab -e` | cron ジョブの編集 | — |
| `visudo` | sudoers ファイルの安全な編集 | 第9章（ユーザー管理） |

> **`git commit` を試してみる**
> このリポジトリでファイルを適当に変更して `git add` → `git commit` を実行すると、
> EDITOR に設定したエディタが起動してコミットメッセージの入力を求めます。

#### 一時的に別のエディタを使う

`VAR=value command` という書き方で、**そのコマンドのみ**環境変数を一時的に上書きできます:

```bash
$ EDITOR=nano git commit    # このコマンドのみ nano で起動
$ echo $EDITOR              # vim のまま（現在のシェルは変わっていない）
vim
```

`export EDITOR=nano` と書いてしまうと現在のシェル全体に影響しますが、`EDITOR=nano git commit` は実行したコマンドへの一時設定にとどまります。

#### `EDITOR` と `update-alternatives` の使い分け

第5章で学んだ `sudo update-alternatives --config editor` との違いを整理します:

| 設定方法 | 有効範囲 | 永続性 |
|:---|:---|:---|
| `export EDITOR=vim`（`~/.bashrc`） | 自分のユーザーセッション | ログイン中は永続（`~/.bashrc` に書けば恒久的） |
| `EDITOR=vim git commit` | そのコマンドのみ | 一時的 |
| `sudo update-alternatives --config editor` | システム全体（全ユーザー） | 永続的 |

通常は `~/.bashrc` への `export EDITOR=vim` が適切です。

---

### 7-4. Tab 補完を使いこなす

Tab キーを押すと、bash が入力途中のコマンドやパスを自動補完します。
Linux 操作の速度と正確さを大きく向上させる機能です。

#### コマンド名の補完

```bash
$ gi<Tab>
git
```

候補が複数ある場合は Tab を2回押すと一覧が表示されます:

```bash
$ gi<Tab><Tab>
git  gip  gimp  ...（gi で始まるコマンド一覧）
```

#### ファイルパスの補完

```bash
$ cat /etc/ng<Tab>
/etc/nginx/

$ cat /etc/nginx/<Tab><Tab>
conf.d/       mime.types    modules-available/  nginx.conf    ...
```

第6章で `vim /etc/nginx/nginx.conf` を開いたとき、毎回フルパスを手入力する必要はありません。
`vim /etc/n<Tab>` と打てば `nginx/` まで補完され、`<Tab>` を繰り返すことで nginx.conf まで到達できます。

#### オプションの補完

```bash
$ git commit --<Tab><Tab>
--all         --amend       --author      --cleanup     --date
--dry-run     --edit        --file        --message     ...
```

> **bash-completion パッケージ**
> コマンドのオプション補完（`--` で始まる引数）には `bash-completion` パッケージが必要です。
> Codespaces にはあらかじめインストールされています。

```bash
# インストール済みか確認（バージョンは環境により異なります）
$ dpkg -l bash-completion
ii  bash-completion  1:2.16.0-7  all  programmable completion for the bash shell
```

> **`complete -p git` コマンドについて**
> インタラクティブなターミナルで `bash-completion` が読み込まれている場合は `complete -p git` で補完設定を確認できますが、環境によっては `no completion specification` と表示されることがあります。
> `dpkg -l bash-completion` でインストール済みであることが確認できれば、補完機能は利用可能です。

#### 候補が多すぎるとき

```bash
$ ls /usr/bin/<Tab><Tab>
Display all 1162 possibilities? (y or n)
```

`y` で全候補表示、`n` で中断します。Ctrl+C でも中断できます。

> **Tab 補完は「覚え方」の補助ではない**
> Tab 補完に頼ってコマンドを「なんとなく打てる」状態になることは推奨しません。
> 基本コマンドはそのまま覚えてください。Tab 補完は入力ミスの防止や長いパスの入力に使うものです。

---

### 7-5. カラー表示の仕組みを知る

第6章では `ls --color=auto` と `grep --color=auto` をエイリアスとして設定しました。
ここではその仕組みを理解し、`diff` のカラー設定を追加します。

#### `diff --color=auto` を追加する

```bash
$ vim ~/.bashrc
```

エイリアスの末尾に追記します:

```bash
alias diff='diff --color=auto'
```

```bash
$ source ~/.bashrc

# 差分のあるファイルを比較して確認
$ diff /etc/hosts /etc/hostname
```

削除行は赤、追加行は緑で表示されます（差分がない場合は何も表示されません）。

#### ANSI エスケープコードの仕組み

`ls --color` や PS1 の色指定で使った `\e[32m` は **ANSI エスケープコード**と呼ばれます。

```text
\e  [  32  m
↑   ↑   ↑  ↑
│   │   │  └─── 終端文字 m（SGR: Select Graphic Rendition）
│   │   └────── 色番号（30〜37: 文字色、40〜47: 背景色）
│   └────────── CSI（Control Sequence Introducer）
└────────────── ESC（エスケープ文字。\033 や ^[ とも表記する）
```

同じ ESC 文字でも文脈によって表記が異なります:

| 表記 | 意味 |
|:---|:---|
| `\e` | bash のエスケープシーケンス（`$'...'` 内や `echo -e` で使用） |
| `\033` | 8進数表記（シェルスクリプト全般で使用） |
| `^[` | 端末での制御文字表示（`cat` 等で出力したとき） |

#### 主要なカラーコード一覧

| コード | 色 | コード | 色 |
|:---|:---|:---|:---|
| `\e[30m` | 黒 | `\e[90m` | 明るい黒（灰） |
| `\e[31m` | 赤 | `\e[91m` | 明るい赤 |
| `\e[32m` | 緑 | `\e[92m` | 明るい緑 |
| `\e[33m` | 黄 | `\e[93m` | 明るい黄 |
| `\e[34m` | 青 | `\e[94m` | 明るい青 |
| `\e[35m` | マゼンタ | `\e[1m` | 太字 |
| `\e[0m`  | リセット（全属性解除） | `\e[7m` | 反転（前景色と背景色を入れ替え） |

#### 試してみる

```bash
# echo -e で直接色を確認する
$ echo -e "\e[32m緑色のテキスト\e[0m"
$ echo -e "\e[31m赤色のテキスト\e[0m"
$ echo -e "\e[1m\e[34m太字の青\e[0m"
```

> **`\e[0m` を忘れると**
> リセットコードを付け忘れると、それ以降のターミナル出力がすべてその色のままになります。
> `echo -e "\e[0m"` を実行すれば元に戻ります。

第6章の PS1 設定を見直してみましょう:

```bash
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\n\$ '
```

- `\[\e[32m\]` → 緑色開始（ユーザー名＋ホスト名を緑にする）
- `\[\e[0m\]` → リセット（コロンの前で色を戻す）
- `\[\e[34m\]` → 青色開始（パスを青にする）
- `\[\e[0m\]` → リセット（改行の前で色を戻す）

---

## よくあるミス

| ミス | 内容 | 対処 |
|:---|:---|:---|
| `export` を付け忘れる | シェル変数のため子プロセス（スクリプト等）に変数が引き継がれない | `export VAR=value` と書く |
| `MY_VAR = "value"` とスペースを入れる | bash はスペースをコマンドの区切りとして解釈しエラーになる | `=` の前後にスペースを入れない |
| PATH の末尾に `:` を残す | `PATH="/usr/local/bin:"` の末尾コロンが「カレントディレクトリ」を意味し、セキュリティリスクになる | `:$PATH` を後ろに付け、末尾コロンで終わらせない |
| `echo -e` の色コードで `\e[0m` を忘れる | 以降のターミナル出力がすべてその色で表示される | 必ず末尾に `\e[0m` でリセットする |
| Tab 補完が効かない | `bash-completion` が読み込まれていない | `source /usr/share/bash-completion/bash_completion` を試す |

---

## 類似比較

| 操作 | コマンドA | コマンドB | 違い |
|:---|:---|:---|:---|
| 変数の表示 | `echo $PATH` | `printenv PATH` | `echo` はシェル変数も表示。`printenv` は環境変数のみ |
| 全変数の表示 | `env` | `set` | `env` は環境変数のみ。`set` はシェル変数・関数・環境変数すべて |
| 変数の設定 | `MY_VAR="val"` | `export MY_VAR="val"` | `export` なしは現在のシェルのみ。`export` ありは子プロセスへ継承 |
| 一時設定 | `EDITOR=nano git commit` | `export EDITOR=nano` | 前者はそのコマンドのみ。後者は以降すべてに影響 |

---

## 他OSとの比較

| 操作 | Linux (bash) | Windows (PowerShell) | macOS (zsh) |
|:---|:---|:---|:---|
| 環境変数の確認 | `env` または `printenv VAR` | `Get-ChildItem Env:` または `$env:VAR` | `env` または `printenv VAR` |
| 環境変数の設定 | `export VAR=value` | `$env:VAR = "value"` | `export VAR=value` |
| 一時的な設定 | `VAR=value command` | `$env:VAR="val"; command` | `VAR=value command` |
| 変数の削除 | `unset VAR` | `Remove-Item Env:VAR` | `unset VAR` |
| Tab 補完 | bash-completion | PSReadLine（標準搭載） | zsh 標準搭載（強力） |

---

## 理解度チェック

1. `MY_VAR="hello"` と `export MY_VAR="hello"` の違いは何か？違いを確認するコマンドも合わせて答えよ。

<details><summary>答え</summary>

`MY_VAR="hello"` はシェル変数で、現在のシェルのみで有効です。
`export MY_VAR="hello"` は環境変数で、子プロセス（スクリプト・起動したコマンド）にも引き継がれます。

確認方法:

```bash
MY_VAR="hello"
bash -c 'echo $MY_VAR'    # 空白（継承されない）

export MY_VAR="hello"
bash -c 'echo $MY_VAR'    # hello（継承される）
```

</details>

2. `env` と `printenv PATH` の違いは何か？

<details><summary>答え</summary>

`env` はすべての環境変数を一覧表示します。
`printenv PATH` は `PATH` の値のみを取り出して表示します。

`echo $PATH` と似ていますが、`printenv` は環境変数のみを参照するため、`export` していないシェル変数は表示されません。
特定の変数の値だけ確認したい場合は `printenv` が簡潔です。

</details>

3. `EDITOR=nano git commit` と `export EDITOR=nano` の違いは何か？

<details><summary>答え</summary>

`EDITOR=nano git commit` はそのコマンドのみに有効な一時的な環境変数設定です。
コマンド終了後、現在のシェルの `EDITOR` は変わりません。

`export EDITOR=nano` は現在のシェル全体と、以降に起動するすべての子プロセスに影響します。

使い分け:

- 1回だけ別エディタを使いたいとき → `EDITOR=nano git commit`
- 恒久的に変更したいとき → `~/.bashrc` に `export EDITOR=nano` を追記

</details>

4. Tab キーを2回押すと何が起きるか？候補が多い場合はどうなるか？

<details><summary>答え</summary>

Tab を2回押すと、入力途中の文字列に一致する**補完候補の一覧**が表示されます。

候補が多い場合（例: `/usr/bin/<Tab><Tab>`）は:

```text
Display all 1162 possibilities? (y or n)
```

と確認が出ます。`y` で全候補を表示、`n` または `Ctrl+C` で中断します。

</details>

5. ANSI エスケープコード `\e[32m` の各部分の意味を説明せよ。

<details><summary>答え</summary>

| 部分 | 意味 |
|:---|:---|
| `\e` | ESC（エスケープ文字）。端末に「制御シーケンスが始まる」と伝える |
| `[` | CSI（Control Sequence Introducer）。制御シーケンスの開始を示す |
| `32` | 色番号。32 は緑色（文字色）を意味する |
| `m` | SGR（Select Graphic Rendition）の終端文字。テキスト属性の変更を意味する |

`\e[0m` の `0` は「すべての属性をリセット」を意味します。
色を設定したあとは必ず `\e[0m` で元に戻す習慣をつけてください。

</details>

---

| [← 第6章: シェル環境をカスタマイズする](../chapter-06/README.md) | [全章目次](../README.md) | [第8章: Locale・Timezone を設定する →](../chapter-08/README.md) |
|:---|:---:|---:|
