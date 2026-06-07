# 第22章: Docker で全部まとめて自動化する

## 前提知識

この章を始める前に、以下の章を完了していること:

- 第04章: nginx をインストールして動かす（`apt install nginx` の使い方）
- 第20章: Nginx をソースからビルドする（手動でのインストール全工程）

## 概要

chapter-00 から chapter-21 まで、Linux の各種操作を手動でひとつひとつ実行してきた。
この章では Docker を使い、その全作業をわずか数十行の「Dockerfile」で自動的に再現する。
手動作業の苦労を経験しているからこそ、Dockerfile の各行が何をしているかを深く理解できる。
コンテナ技術がなぜ普及したかを体感的に学ぶ、カリキュラムのフィナーレとなる章だ。

## 手順

### 22-1. Docker とは何か

Docker は「コンテナ」と呼ばれる仕組みで、アプリケーションとその実行に必要な環境をひとまとめにして動かすツールだ。

**Docker の3つの基本概念:**

| 用語 | 意味 | たとえ |
|:---|:---|:---|
| **Image（イメージ）** | コンテナの設計図。Dockerfile から作成する | 料理のレシピ |
| **Container（コンテナ）** | Image から作った実行中のプロセス（アプリ） | 料理（レシピから作った実物） |
| **Layer（レイヤー）** | Dockerfile の各命令が積み重なった構造 | 玉ねぎの皮（重ね合わせ） |

**手動ビルドと Docker の対比:**

| 項目 | 第20章（手動） | 第22章（Docker） |
|:---|:---|:---|
| OS のセットアップ | 手動で依存パッケージをインストール | `FROM debian:bookworm-slim`（1 行） |
| nginx のインストール | ソースコードをダウンロード・コンパイル（30〜60 分） | `apt-get install -y nginx`（1 行） |
| HTML ファイルの配置 | vim で手動編集・配置 | `COPY html/ /var/www/html/`（1 行） |
| サービスの起動 | `sudo /usr/local/nginx/sbin/nginx` | `CMD ["nginx", "-g", "daemon off;"]`（1 行） |
| 再現性 | 手順書に従えば再現可 | `docker build` で完全再現 |
| 配布 | サーバーごとに設定が必要 | `docker push` でイメージを配布可能 |

> **「コンテナ内で `apt install nginx` を使っているのは chapter-04 と同じでは？」**
> その通り。しかし chapter-20 で 30〜60 分かけて手動ビルドしたからこそ、nginx の内部構造を理解できた。
> コンテナは「作業を自動化する道具」だが、中身を理解せずに使うと問題発生時に対処できない。
> 手動構築の経験が、コンテナを「使いこなす」エンジニアとの差になる。

### 22-2. Docker をインストールして起動する

Codespaces には Docker がプリインストールされていないため、まずインストールする。
Codespaces 自体が Docker コンテナで動いているが、`devcontainer.json`（Codespaces の開発環境設定ファイル）に `--privileged` が設定済みだ。
そのため、コンテナ内でさらに Docker（Docker-in-Docker: コンテナの中でさらに Docker を動かす構成）を起動できる。

```bash
# Docker のインストール
$ sudo apt update
$ sudo apt install -y docker.io

# Docker daemon の起動
# （Codespaces はコンテナ環境なので systemctl ではなく service コマンドを使う）
$ sudo service docker start
mount: /sys/fs/cgroup/cpuset: cgroup already mounted on /sys/fs/cgroup.
（中略：cgroup already mounted の警告が複数行出るが無害）
Starting Docker: docker.
```

> **cgroup の警告について:**
> `mount: cgroup already mounted` の警告が複数行表示されるが、これは Codespaces 自体がコンテナ環境で動いているためであり、無害だ。
> 最後に `Starting Docker: docker.` が表示されれば正常に起動している。

```bash
# バージョン確認
$ docker --version
Docker version 26.1.5+dfsg1, build a72d7cd

# sudo なしで docker コマンドを使えるようにする
$ sudo usermod -aG docker $USER
$ newgrp docker

# 動作確認（hello-world イメージを pull して実行）
$ docker run hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.
（以下省略）
```

> **`newgrp docker` について:**
> `usermod` でグループを追加しても、現在のセッションには即座に反映されない。
> `newgrp docker` を実行すると、再ログインなしで新しいグループで新しいシェルを起動できる。
> ターミナルを一度閉じて再度開いても同様に反映される。

### 22-3. Dockerfile を書く

`chapter-22/Dockerfile` をテキストエディタで確認しよう。

```bash
$ cat /workspaces/starter-linux-with-web-server/chapter-22/Dockerfile
```

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY html/ /var/www/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**各命令の解説:**

| 命令 | 役割 | この Dockerfile での使い方 |
|:---|:---|:---|
| `FROM` | ベースとなる Image を指定（最初の Layer） | `debian:bookworm-slim`（軽量 Debian） |
| `RUN` | ビルド中にコマンドを実行して Layer を積み上げる | nginx のインストールとキャッシュの削除 |
| `COPY` | ホストのファイルをコンテナ内にコピーする | `html/` ディレクトリを `/var/www/html/` に配置 |
| `EXPOSE` | コンテナが使うポート番号を宣言する | HTTP の 80 番ポートを使用 |
| `CMD` | コンテナ起動時に実行するコマンドを指定する | nginx をフォアグラウンドで実行 |

> **`apt-get clean && rm -rf /var/lib/apt/lists/*` の理由:**
> `RUN` 命令の最後にキャッシュを削除することで、Image のサイズを小さくできる。
> `RUN` 命令は 1 行ごとに Layer を作るため、`&&` でつなげて 1 つの Layer にまとめるのが定石だ。
>
> **`daemon off;` の理由:**
> Docker はコンテナのメインプロセス（PID 1: コンテナ起動時に最初に動くプロセス番号 1 のプロセス）が終了するとコンテナも停止する。
> nginx はデフォルトでバックグラウンド（daemon）として起動するため、
> フォアグラウンドで動かす `daemon off;` オプションが必要だ。

### 22-4. イメージをビルドする

```bash
$ cd /workspaces/starter-linux-with-web-server/chapter-22
$ docker build -t nginx-hardway .
```

`docker build` の実行中、Dockerfile の各命令が Layer として積み上げられる様子が確認できる:

```text
#1 [internal] load build definition from Dockerfile
#2 [internal] load metadata for docker.io/library/debian:bookworm-slim
#3 [internal] load .dockerignore
#4 [internal] load build context
#5 [1/3] FROM docker.io/library/debian:bookworm-slim
  ダウンロード完了
#6 [2/3] RUN apt-get update && apt-get install -y nginx ...
  nginx インストール完了（約9秒）
#7 [3/3] COPY html/ /var/www/html/
#8 exporting to image
```

ビルドが完了したらイメージを確認しよう:

```bash
$ docker images nginx-hardway
REPOSITORY      TAG       IMAGE ID       CREATED          SIZE
nginx-hardway   latest    4c6eec2e61e8   21 seconds ago   90.3MB
```

> **`[1/3]`, `[2/3]`, `[3/3]` の意味:**
> Dockerfile の `RUN`・`COPY` など、Layer を作る命令の番号。
> `FROM` はベースイメージなので `[1/3]`、`RUN` が `[2/3]`、`COPY` が `[3/3]` となる。
> Layer はキャッシュされるため、2 回目以降の `docker build` は変更された Layer 以降のみ再実行される。

### 22-5. コンテナを起動して確認する

```bash
# コンテナを起動（-d: バックグラウンド、-p: ポートのマッピング、--name: コンテナ名）
$ docker run -d -p 8080:80 --name nginx-test nginx-hardway
e9f662c10cc2128027a6ee5297609a715ef5ee95c792795f90c2a44442b7eec8

# 起動中のコンテナを確認
$ docker ps
CONTAINER ID   IMAGE           COMMAND                  CREATED        STATUS        PORTS                                   NAMES
e9f662c10cc2   nginx-hardway   "nginx -g 'daemon of…"   6 seconds ago  Up 6 seconds  0.0.0.0:8080->80/tcp, :::8080->80/tcp   nginx-test
```

```bash
# HTTP リクエストを送って動作確認
$ curl http://localhost:8080
<!DOCTYPE html>
<html>
<head><title>Hello from Docker!</title></head>
<body>
<h1>Hello from Docker!</h1>
<p>chapter-00〜21 の学習お疲れさまでした。</p>
</body>
</html>
```

```bash
# コンテナ内の nginx バージョンを確認（ホストのバージョンと比較してみよう）
$ docker exec nginx-test nginx -v
nginx version: nginx/1.22.1
```

> **バージョンの違いに注目:**
> コンテナ内の nginx は `apt install` で入れた `1.22.1`（Debian 公式パッケージ）。
> ホストにインストールした nginx はソースからビルドした `1.30.2`。
> どちらも「nginx を動かす」という点は同じだが、管理方法と自由度が大きく異なる。

```bash
# コンテナのログを確認（nginx はファイルにログを書くため、通常は空）
$ docker logs nginx-test
（出力なし）

# コンテナ内に入って直接確認する
$ docker exec -it nginx-test bash
root@e9f662c10cc2:/# nginx -v
nginx version: nginx/1.22.1
root@e9f662c10cc2:/# cat /var/log/nginx/access.log
（curl でアクセスした記録が表示される）
root@e9f662c10cc2:/# exit
```

```bash
# コンテナの停止・削除・イメージの削除
$ docker stop nginx-test
nginx-test
$ docker rm nginx-test
nginx-test
$ docker rmi nginx-hardway
Untagged: nginx-hardway:latest
Deleted: sha256:4c6eec2e61e8...
```

### 22-6. まとめ: 手動とコンテナの価値

chapter-00 から chapter-21 まで、あなたは以下のことを手動で行ってきた:

- ファイルの操作・パーミッションの設定（chapter-02〜06）
- ユーザー管理・プロセス管理（chapter-09〜11）
- ネットワーク・SSH の設定（chapter-12〜14）
- nginx のインストールと設定（chapter-04、chapter-20）
- TLS/HTTPS の設定（chapter-21）

この章で作成した Dockerfile は、その一部をわずか 10 行で再現した。

**手動構築の価値:**
Dockerfile の `RUN apt-get install -y nginx` の 1 行の裏に、chapter-20 での 30〜60 分の作業がある。
その経験があるからこそ、「`apt install` で何が起きているか」「ビルドオプションの意味」を理解できる。
コンテナは「作業を自動化する道具」であり、中身を理解している人だけが使いこなせる。

**コンテナ技術の価値:**
「どの環境でも同じように動く」「すぐに再現・配布できる」「不要になればきれいに削除できる」。
これらを体感したうえで Docker や Kubernetes（多数のコンテナを一元管理するオーケストレーションツール）を学ぶと、技術の本質を理解したうえで活用できる。

## よくあるミス

| ミス | エラーメッセージ例 | 正しい対処 |
|:---|:---|:---|
| `docker build` を `chapter-22/` 以外で実行 | `ERROR: failed to solve: failed to read dockerfile: open Dockerfile: no such file or directory` | `cd chapter-22` してから実行する |
| `sudo service docker start` を忘れる | `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | `sudo service docker start` を実行する |
| `newgrp docker` を忘れて sudo なしで実行 | `permission denied while trying to connect to the Docker daemon socket` | `newgrp docker` を実行するか `sudo docker` を使う |
| 同名コンテナが残っている | `Conflict. The container name "/nginx-test" is already in use` | `docker rm nginx-test` してから再実行 |
| `COPY html/` を書いて `html/` がない | `COPY failed: file not found in build context` | `chapter-22/html/index.html` を作成する |
| `daemon off;` を書かない | コンテナが起動してもすぐに終了する | `CMD ["nginx", "-g", "daemon off;"]` を確認する |

## 類似比較

| コマンド | 対象 | 違い |
|:---|:---|:---|
| `docker build` | Dockerfile | Dockerfile を読んで Image を作成する |
| `docker run` | Image | Image からコンテナを起動する |
| `docker exec` | 起動中のコンテナ | 起動中のコンテナ内でコマンドを実行する |
| `docker stop` | 起動中のコンテナ | コンテナを停止する（削除はしない） |
| `docker rm` | 停止中のコンテナ | 停止済みのコンテナを削除する |
| `docker rmi` | Image | ローカルの Image を削除する |

## 他OSとの比較

| 操作 | Linux（Debian） | Windows | macOS |
|:---|:---|:---|:---|
| Docker のインストール | `apt install docker.io` | Docker Desktop（公式インストーラー） | Docker Desktop（公式インストーラー） |
| daemon の起動 | `sudo service docker start` | Docker Desktop が自動で起動 | Docker Desktop が自動で起動 |
| ソケットのパス | `/var/run/docker.sock` | `//./pipe/docker_engine` | `/var/run/docker.sock`（Lima 経由） |
| コンテナ内の OS | Linux（ホストカーネルを共有） | Linux（WSL2 または Hyper-V） | Linux（仮想マシン） |

> **Windows / macOS での注意:**
> Windows と macOS では Docker Desktop がバックグラウンドで Linux 仮想マシンを動かし、その中でコンテナを実行する。
> そのため、コンテナ内は常に Linux 環境になる。

## 理解度チェック

1. Docker の「Image」と「Container」の違いを説明してください。

<details><summary>答え</summary>

Image はコンテナの設計図（Dockerfile から作成した静的なもの）。
Container は Image から作った実行中のプロセス（動いているもの）。
1 つの Image から複数の Container を同時に起動できる。

</details>

2. `CMD ["nginx", "-g", "daemon off;"]` に `daemon off;` が必要な理由を説明してください。

<details><summary>答え</summary>

Docker はコンテナのメインプロセス（PID 1）が終了するとコンテナも停止する。
nginx はデフォルトでバックグラウンド（daemon）として起動するため、すぐに PID 1 が終了してコンテナが止まってしまう。
`daemon off;` を指定することで nginx がフォアグラウンドで動き続け、コンテナが起動状態を維持できる。

</details>

3. `docker build -t nginx-hardway .` コマンドの各部分（`-t nginx-hardway`・`.`）の意味を説明してください。

<details><summary>答え</summary>

`-t nginx-hardway`: 作成する Image に `nginx-hardway` という名前（タグ）をつける。
`.`: Dockerfile が置いてあるディレクトリ（ここではカレントディレクトリ）を指定する。
`.` は「このディレクトリの Dockerfile を使う」という意味。

</details>

4. `docker run -d -p 8080:80 --name nginx-test nginx-hardway` の `-p 8080:80` は何を意味しますか？

<details><summary>答え</summary>

ホスト（Codespaces）の 8080 番ポートを、コンテナ内の 80 番ポートにつなぐ（転送する）指定。
`curl http://localhost:8080` でアクセスすると、コンテナ内の nginx（80 番ポート）にリクエストが届く。
書式は `-p ホスト側ポート:コンテナ側ポート`。

</details>

5. chapter-20 で nginx を手動でソースからビルドした経験は、Docker を使う上でどのような価値がありますか？

<details><summary>答え</summary>

Dockerfile の `RUN apt-get install -y nginx` の 1 行の裏に、どれだけの作業があるかを理解できる。
ビルドオプション（`--with-http_ssl_module` など）の意味を知っているため、コンテナ設定を適切に調整できる。
問題が発生したときに「コンテナの中で何が起きているか」を追跡できる。
手動構築の経験は、コンテナを「使いこなす」エンジニアになるための土台になる。

</details>

chapter-00 からここまで、全23章の Linux 基礎学習お疲れさまでした。コマンドラインの操作からプロセス管理・ネットワーク・セキュリティ・ソースビルド・コンテナ化まで、手を動かして体験したすべての経験が、これからのエンジニアリングの土台になります。

---

| [← 第21章: OpenSSL 証明書で HTTPS 化する](../chapter-21/README.md) | [全章目次](../README.md) | 最終章 |
|:---|:---:|---:|
