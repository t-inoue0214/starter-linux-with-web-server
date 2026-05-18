#!/usr/bin/env bash
set -euo pipefail

echo "================================================================"
echo " Linux Hard Way 学習環境セットアップ開始"
echo "================================================================"

sudo apt-get update -qq

echo "--- [1/6] テキストエディタのインストール (chapter-05) ---"
# vim-tiny は機能が不足するため vim（フル版）をインストール
sudo apt-get install -y -qq vim emacs-nox

echo "--- [2/6] OSログ関連ツールのインストール (chapter-14) ---"
sudo apt-get install -y -qq rsyslog

echo "--- [3/6] SystemD 関連パッケージのインストール (chapter-15) ---"
# コンテナ内では systemd が PID 1 として動作しない場合がある
# パッケージをインストールすることで systemctl コマンドとユニットファイルの学習が可能
sudo apt-get install -y -qq systemd systemd-sysv dbus

echo "--- [4/6] Nginx ソースビルド用依存ライブラリのインストール (chapter-17) ---"
# nginx は意図的にインストールしない。chapter-17 でソースから手動ビルドする
sudo apt-get install -y -qq \
    build-essential \
    libpcre2-dev \
    libssl-dev \
    zlib1g-dev

echo "--- [5/6] ネットワーク・学習補助ツールのインストール ---"
sudo apt-get install -y -qq \
    bash-completion \
    man-db \
    manpages \
    lsof \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    traceroute \
    tree \
    strace \
    openssl \
    wget \
    curl

echo "--- [6/6] 日本語ロケールとタイムゾーン設定 (chapter-08 の予習) ---"
sudo apt-get install -y -qq locales
if ! grep -q "ja_JP.UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "ja_JP.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
fi
sudo locale-gen
sudo update-locale LANG=ja_JP.UTF-8
sudo ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo "Asia/Tokyo" | sudo tee /etc/timezone > /dev/null

echo ""
echo "================================================================"
echo " セットアップ完了！"
echo " chapter-00/ から学習を始めましょう。"
echo "================================================================"
