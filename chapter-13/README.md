# 第13章: ファイルシステムとディスク使用量を確認する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第2章: ファイルシステムの基礎（ディレクトリ・パス）
- 第11章: パーミッションを理解する

---

## 概要

第11章でパーミッション、第12章でネットワークを学んだ。この章では「ファイルがどこのディスクに保存されているのか」という視点で Linux を理解する。

例えば nginx の設定ファイル `/etc/nginx/nginx.conf` やドキュメントルート `/var/www/html` — これらは「ディスク上のどこ」にあるのだろうか？`df -h /etc/nginx` を実行するとすぐにわかる。

この章で学ぶこと:

- ファイルシステムとマウントの概念（Windows との比較）
- `df` でファイルシステム全体の残量を把握する
- `du` でどのディレクトリが容量を消費しているか探索する
- `lsblk`・`findmnt` でマウント状態を読み取る
- `/etc/fstab` の構造を読み解く

> **この章は「読み取り専用」の実習です**
> `mount`・`umount`・`mkfs`・`/etc/fstab` 編集は Codespaces コンテナでは安全に実施できません。
> この章では概念説明のみとし、実際のコマンド操作は `df`・`du`・`lsblk`・`findmnt`・`cat /etc/fstab` の読み取りに限定します。

---

## 手順

### 13-1. ファイルシステムとは何か

ファイルシステム（file system）= 「ファイルをディスクに保存・管理する方式」のことです。

Windows を使ったことがあれば、C ドライブ・D ドライブという概念はなじみがあるはずです。まず Windows と Linux でストレージの「見え方」がどう違うかを確認します。

**Windows — ドライブ文字ごとに独立したツリー:**

```text
C:\ (NTFS)            D:\ (NTFS)         E:\ (FAT32)
┌─────────────┐       ┌────────────┐     ┌───────────┐
│ Windows\    │       │ Documents\ │     │ Photos\   │
│ Program     │       │ Videos\    │     │ Music\    │
│   Files\    │       │ ...        │     │ ...       │
│ Users\      │       └────────────┘     └───────────┘
└─────────────┘       ↑                  ↑
↑                     D: を開いて        E: を開いて
C: を開いて           初めて見える        初めて見える
初めて見える

→ ドライブ文字（C:, D:, E:）ごとに「別々のツリー」が存在する
```

**Linux — すべてが 1 本のツリーに統合:**

```text
/（ルート、ext4）              ← メインのディスク
├── boot/   ←─────────────── 別パーティション（ext4）がここに接続される
├── home/
│   └── vscode/
├── mnt/
│   └── usb/  ←──────────── USB メモリ（FAT32）がここに接続される
└── tmp/    ←─────────────── RAM 上の仮想 FS（tmpfs）がここに接続される

→ ドライブ文字はなく、すべてが「/ から始まる 1 本のツリー」に統合される
→ 複数のディスクやUSBメモリも「ディレクトリ」として木の中に組み込まれる
```

**まとめると:**

| | Windows | Linux |
|:---|:---|:---|
| ストレージの区別 | ドライブ文字（C:, D:, E:）| ディレクトリ（`/boot`, `/mnt/usb`）|
| ツリーの本数 | ドライブの数だけ存在 | 常に 1 本（`/` から始まる）|
| USB を使うには | 挿すと自動で E: が現れる | `mount` でどこかのディレクトリに接続する |

よく使われるファイルシステムの種類:

| ファイルシステム | 特徴 | 主な用途 |
|:---|:---|:---|
| ext4 | Linux 標準。ジャーナリング対応 | ルート FS、データ領域 |
| tmpfs | RAM 上の仮想 FS（再起動で消える） | `/tmp` など一時領域 |
| overlay | 複数の FS を重ね合わせる | Docker コンテナ |
| FAT32 / exFAT | Windows / macOS / Linux 共通 | USB メモリ |
| NTFS | Windows 標準 | Windows ディスク |
| NFS | ネットワーク越しのファイル共有 | サーバー間共有 |

---

### 13-2. マウントとは何か

マウント（mount）= 「あるデバイスのファイルシステムを、ディレクトリツリーの特定の場所に接続する」操作です。

**Windows ではどうなっているか:**

Windows は USB メモリを挿すと「E: ドライブ」として自動認識します。この「E:」という概念がマウントです。

**Linux ではどうなっているか:**

```text
USB メモリを挿しても、そのままでは使えない（コマンドで明示的にマウントが必要）

     /（ルート FS: ext4）
     ├── etc/
     ├── var/
     │   └── www/
     │       └── html/     ← nginx のドキュメントルート
     ├── mnt/
     │   └── usb/          ← ここに USB メモリの内容が見える（マウント後）
     └── tmp/              ← tmpfs（メモリ上。再起動で消える）
```

- **マウントポイント** = 接続先のディレクトリ（`/mnt/usb` など）
- マウント後は `/mnt/usb` の中を普通のディレクトリとして操作できる
- アンマウント（`umount`）するとそのディレクトリへのアクセスが切断される

> **[コンテナ制限] Codespaces での注意**
> `mount` コマンドは `--privileged`（特権）コンテナでないと動作しません。
> Codespaces は通常コンテナのため `sudo mount` を実行しても `Permission denied` になります。
> この章では読み取り専用の確認コマンドだけを実習します。

---

### 13-3. df でファイルシステム全体のディスク使用量を確認する

`df`（disk free）はファイルシステム単位でディスクの使用量・残量を表示するコマンドです。

```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay          32G  2.5G   28G   9% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/root        29G   23G  5.9G  80% /vscode
/dev/loop4       32G  2.5G   28G   9% /workspaces
/dev/sda1        44G  1.6G   41G   4% /tmp
```

各フィールドの意味:

| フィールド | 意味 |
|:---|:---|
| `Filesystem` | デバイス名またはファイルシステムの種類 |
| `Size` | 総容量 |
| `Used` | 使用中の容量 |
| `Avail` | 残り容量 |
| `Use%` | 使用率（**90% を超えたら要注意**） |
| `Mounted on` | マウントポイント（どのディレクトリに接続されているか） |

**Codespaces 固有の出力について:**

| 表示 | 意味 |
|:---|:---|
| `overlay` | Docker コンテナで使われる重ね合わせ型 FS。複数のレイヤーを重ねて `/` として見せている |
| `tmpfs` | RAM 上の仮想 FS。`/dev` や `/dev/shm` はメモリ上に展開されている |
| `/dev/loop4` | ループデバイス（ファイルをディスクのように見せる仮想デバイス） |

特定のディレクトリがどのファイルシステムにあるかも確認できます:

```bash
$ df -h /var/log
Filesystem      Size  Used Avail Use% Mounted on
overlay          32G  2.5G   28G   9% /
```

`/var/log` はルートの overlay FS 上にあることがわかります。nginx のファイル（`/etc/nginx`・`/var/www/html`）も同じ overlay FS 上にあります。

---

### 13-4. du でどこが容量を食っているか探索する

`df -h` はファイルシステム全体の残量を見るツールですが、「どのディレクトリが容量を使っているか」まではわかりません。それを調べるのが `du`（disk usage）です。

「ディスクがいっぱい！」という状況を想定して、次の手順で原因ディレクトリを特定します。

```text
① df -h         → どのファイルシステムが逼迫しているか把握する
② du -sh /var/log /var/cache /var/lib /home /tmp
                → どのディレクトリが大きいか絞り込む
③ sudo du -sh /var/log/* | sort -rh | head -10
                → そのディレクトリの中でさらに大きいものを特定する
```

#### Step ②: 主要ディレクトリのサイズを確認する

```bash
$ du -sh /var/log /var/cache /var/lib /home /tmp
du: cannot read directory '/var/log/exim4': Permission denied
du: cannot read directory '/var/cache/apt/archives/partial': Permission denied
344K    /var/log
5.2M    /var/cache
 37M    /var/lib
638M    /home
2.6M    /tmp
```

`Permission denied` が出ても対象ディレクトリの合計は表示されます（root 所有のサブディレクトリが読めないだけで、合計値は正しく計算されます）。正確に計測したい場合は `sudo du -sh` を使います。

オプションの意味:

| オプション | 意味 |
|:---|:---|
| `-s` | そのディレクトリの合計のみ表示（summarize。サブディレクトリは展開しない） |
| `-h` | 人間が読みやすい単位（K / M / G）で表示（human-readable） |

#### Step ③: さらに詳細を確認する（大きい順）

```bash
$ sudo du -sh /var/log/* | sort -rh | head -10
160K    /var/log/dpkg.log
140K    /var/log/apt
 20K    /var/log/alternatives.log
  8.0K  /var/log/journal
  0     /var/log/wtmp
  0     /var/log/lastlog
```

- `sort -rh` = 人間可読な数値（K / M / G）を認識して降順ソート（`-r` = reverse、`-h` = human-readable 対応）
- `head -10` = 上位 10 件のみ表示

> **本番サーバーでは `/var/log` が急増することがある**
> nginx・Apache・アプリのアクセスログが溜まると `/var/log` が GB 単位になることがあります。
> `sudo du -sh /var/log/*` で定期的にどのログが大きいか確認しましょう。

---

### 13-5. lsblk でブロックデバイスを確認する

ブロックデバイス = HDD・SSD・USB メモリのように「ブロック単位でデータを読み書きするデバイス」のことです。Windows のデバイスマネージャーで見えるストレージデバイスに相当します。

`lsblk`（list block devices）でシステム上のすべてのブロックデバイスを一覧表示できます。

```bash
$ lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0     7:0    0  63.8M  1 loop
loop4     7:4    0    32G  0 loop /workspaces
sda       8:0    0    45G  0 disk
`-sda1    8:1    0    45G  0 part /tmp
sdb       8:16   0    30G  0 disk
`-sdb1    8:17   0  29.9G  0 part /vscode
sdc       8:32   0   512G  0 disk
（一部省略）
```

> **出力の読み方: `` ` `` 記号について**
> `` `-sda1 `` のように先頭に `` ` `` が付いている行は、直上の `sda`（親デバイス）の**子デバイス（パーティション）**を意味します。
> これはツリー表示の枝記号で、「`sda` というディスクの中に `sda1` というパーティションが入っている」ことを表しています。

各フィールドの意味:

| フィールド | 意味 |
|:---|:---|
| `NAME` | デバイス名（`sda` = 1枚目のディスク、`sda1` = そのパーティション（ディスクを論理的に分割した区画）1 番） |
| `RM` | リムーバブルかどうか（1 = USB 等、0 = 固定） |
| `SIZE` | 容量 |
| `RO` | 読み取り専用かどうか（1 = 読み取り専用） |
| `TYPE` | `disk`（物理ディスク）/ `part`（パーティション）/ `loop`（ループデバイス） |
| `MOUNTPOINTS` | マウントされているパス（空欄 = 未マウント） |

**Codespaces 固有の出力について:**

| 表示 | 意味 |
|:---|:---|
| `loop0`〜`loop5` | ループデバイス（ファイルをディスクとして扱う仮想デバイス）。Codespaces が内部で使用 |
| `sda`・`sdb`・`sdc` | Azure が提供する仮想ディスク |
| `MOUNTPOINTS` に複数行 | 同じパーティションが複数の場所にマウントされている（コンテナ固有の挙動） |

---

### 13-6. findmnt でマウントツリーを確認する

`findmnt` は現在のマウント状態をツリー構造で表示するコマンドです。`df -h` より詳細で、どのデバイスがどのディレクトリにマウントされているかが一目でわかります。

```bash
$ findmnt
TARGET        SOURCE      FSTYPE   OPTIONS
/             overlay     overlay  rw,relatime,...
├─/dev        tmpfs       tmpfs    rw,nosuid,...
│ └─/dev/shm  shm         tmpfs    rw,...
├─/proc       proc        proc     rw,...
├─/sys        sysfs       sysfs    rw,...
├─/vscode     /dev/sdb1   ext4     rw,relatime,...
├─/workspaces /dev/loop4  ext4     rw,nodev,...
└─/tmp        /dev/sda1   ext4     rw,relatime,...
（一部省略）
```

各フィールドの意味:

| フィールド | 意味 |
|:---|:---|
| `TARGET` | マウントポイント（どのディレクトリに接続されているか） |
| `SOURCE` | マウント元（デバイス名や仮想 FS 名） |
| `FSTYPE` | ファイルシステムの種類 |
| `OPTIONS` | マウントオプション（`rw` = 読み書き可、`ro` = 読み取り専用 など） |

**`df -h` との使い分け:**

| コマンド | 確認できること | 使うとき |
|:---|:---|:---|
| `df -h` | ファイルシステムの残量・使用率 | 「残り容量はいくらか?」 |
| `findmnt` | マウント状態のツリー構造 | 「このデバイスはどこにマウントされているか?」 |

---

### 13-7. /etc/fstab を読む（閲覧のみ）

`/etc/fstab`（FileSystem TABle）= 起動時に自動でマウントするデバイスと設定を記述したファイルです。

```bash
$ cat /etc/fstab
# UNCONFIGURED FSTAB FOR BASE SYSTEM
```

> **Codespaces では fstab がほぼ空です**
> 通常の Linux サーバーでは fstab にディスクのマウント設定が書かれています。
> Codespaces（Docker コンテナ）は起動時のマウントを Docker の仕組みで行うため、
> 伝統的な fstab は使われていません。これはコンテナ固有の挙動です。

**通常の Linux サーバーの fstab 例（参考）:**

```text
# デバイス           マウントポイント  FS タイプ  オプション       dump  pass
UUID=1234-abcd       /                ext4       defaults         0     1
UUID=5678-efgh       /boot            ext4       defaults         0     2
UUID=9012-ijkl       swap             swap       defaults         0     0
tmpfs                /tmp             tmpfs      defaults,noatime 0     0
```

6 つのフィールドの意味:

| フィールド | 意味 | 例 |
|:---|:---|:---|
| デバイス | マウントするデバイス（UUID 推奨） | `UUID=1234-abcd` |
| マウントポイント | 接続先ディレクトリ | `/` |
| FS タイプ | ファイルシステムの種類 | `ext4` |
| オプション | マウントオプション | `defaults`・`ro`・`noexec` |
| dump | バックアップ対象か（0 = なし、1 = あり） | `0` |
| pass | 起動時の fsck チェック順（0 = しない、1 = 最初、2 = 後） | `1` |

**UUID を使う理由:**

```text
デバイス名（/dev/sda1）は起動順序によって変わることがある
→ 再起動後に /dev/sdb1 が /dev/sda1 に変わってしまう問題が起きうる

UUID はディスク固有の番号なので起動順序に依存しない
→ fstab には UUID を使うのが安全
```

UUID は `sudo blkid` で確認できます:

```bash
$ sudo blkid
/dev/sda1: UUID="xxxx-yyyy-..." TYPE="ext4"
```

**この章で実習しないコマンド（概念のみ）:**

```bash
# ※ Codespaces では実行しないこと（説明のみ）
# sudo mount /dev/sdb1 /mnt/data     # マウント
# sudo umount /mnt/data               # アンマウント（使用中は Device busy エラー）
# sudo mkfs.ext4 /dev/sdb1           # フォーマット（既存データが消える）
# sudo nano /etc/fstab               # fstab 編集（ミスするとコンテナが起動しなくなる）
```

---

### コラム: NFS — ネットワーク越しのマウント

NFS（Network File System）= ネットワーク上の別のサーバーのディレクトリを、自分のディレクトリツリーにマウントする仕組みです。

```text
ファイルサーバー（192.168.1.10）      Web サーバー
  /data/shared/       ────────────▶  /mnt/fileserver/
                   NFS マウント          （ここからファイルを操作）
```

複数のサーバーがファイルを共有したいときに使います。現代のクラウド環境では AWS EFS・GCP Filestore などのマネージド NFS がよく使われています。

---

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| `df` と `du` の混同 | ― | `df` はファイルシステム単位の残量確認、`du` は特定ディレクトリの使用量確認 |
| `du -sh /*` で Permission denied | `du: cannot read directory '/root': Permission denied` | 対象ディレクトリを絞るか `sudo du -sh` で実行 |
| `du` でサブディレクトリが全展開される | 大量の出力 | `-s` オプションで各ディレクトリの合計のみ表示にする |
| `/etc/fstab` が空（Codespaces） | `# UNCONFIGURED FSTAB FOR BASE SYSTEM` | Codespaces はコンテナのため fstab が最小構成。正常な挙動 |

---

## 類似比較

| コマンドA | コマンドB | 違い |
|:---|:---|:---|
| `df -h` | `du -sh /path` | `df` は FS 全体の残量、`du` は特定ディレクトリの使用量 |
| `lsblk` | `df -h` | `lsblk` はブロックデバイスの物理構成、`df` は FS の使用量 |
| `findmnt` | `df -h` | `findmnt` はマウントツリー確認、`df` はディスク使用量確認 |
| `du -sh /path` | `du -sh /path/*` | 前者は合計のみ、後者はサブディレクトリを一覧表示 |

---

## 他OSとの比較

| 操作 | Linux (Debian) | Windows | macOS |
|:---|:---|:---|:---|
| ディスク使用量確認 | `df -h` | エクスプローラーのプロパティ / `dir` | `df -h` |
| ディレクトリサイズ確認 | `du -sh /path` | `dir /s /q` | `du -sh /path` |
| デバイス一覧 | `lsblk` | デバイスマネージャー / `diskpart` | `diskutil list` |
| マウント状態確認 | `findmnt` / `mount` | `mountvol` | `mount` |
| 自動マウント設定 | `/etc/fstab` | レジストリ | `/etc/fstab` |

> **Windows との違い**
> Windows はドライブ文字（C:, D:）でストレージを区別しますが、Linux はすべてがルート（`/`）から始まるひとつのツリーです。
> D ドライブの代わりに `/mnt/data` のような「ディレクトリ」としてマウントされます。

---

## 理解度チェック

1. `df -h` と `du -sh` はそれぞれ何を確認するコマンドか。「ディスクがいっぱい」になったとき、どちらを先に実行すべきか説明せよ。

<details><summary>答え</summary>

- `df -h`: **ファイルシステム全体**の使用量・残量を確認する
- `du -sh`: **特定のディレクトリ**が何 GB 使っているかを確認する

手順: まず `df -h` で「どのファイルシステムが逼迫しているか」を把握し、その後 `sudo du -sh /var/log /home /var/lib ...` で「どのディレクトリが原因か」を絞り込む。

</details>

2. `lsblk` の出力で `TYPE` が `loop` のデバイスは何を意味するか。

<details><summary>答え</summary>

ループデバイス（loop device）= ファイルをブロックデバイス（ディスク）として見せる仮想デバイスのこと。Codespaces では Docker コンテナの仕組みでループデバイスが多数使われている。物理ディスクではない。

</details>

3. Linux でマウントポイントとは何か。Windows の概念と比較して説明せよ。

<details><summary>答え</summary>

マウントポイント = あるファイルシステムを接続するディレクトリのこと。

- Windows: ストレージは「ドライブ文字（C:, D:）」として区別される
- Linux: ドライブ文字はなく、すべてのストレージが「ディレクトリ」として `/` 以下のツリーに接続される

例: USB メモリを `/mnt/usb` にマウントすると、`/mnt/usb/` の中で USB の内容を操作できる。

</details>

4. `/etc/fstab` で UUID が推奨される理由を説明せよ。

<details><summary>答え</summary>

デバイス名（`/dev/sda1` など）は起動順序によって変わる場合がある。例えば新しいディスクを追加すると、`sda` と `sdb` の順序が逆転することもある。UUID（デバイス固有の識別子）は物理デバイスに結びついており、起動順序に依存しない。そのため fstab での指定には UUID を使うのが安全。

</details>

5. `overlay` ファイルシステムとはどのようなものか。Codespaces でルート（`/`）に使われている理由を説明せよ。

<details><summary>答え</summary>

overlay FS = 複数のファイルシステムのレイヤーを重ね合わせて、ひとつのファイルシステムとして見せる仕組み。

- 下のレイヤー（lowerdir）= 読み取り専用（Docker イメージの各レイヤー）
- 上のレイヤー（upperdir）= 読み書き可能（コンテナ固有の変更分）

Codespaces は Docker コンテナとして動作しているため、ルート（`/`）が overlay FS になっている。コンテナが削除されると upperdir の変更は消え、下のイメージレイヤーは保持される。

</details>

---

次章では、Linux がシステムの動作を記録する「ログ」の仕組みと、`journalctl`・`logger` を使ったログの読み書きを学びます。

| [← 第12章: ネットワーク基礎](../chapter-12/README.md) | [全章目次](../README.md) | [第14章: OS ログを読む・書く →](../chapter-14/README.md) |
|:---|:---:|---:|
