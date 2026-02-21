# デプロイメントガイド

このガイドはアプリ���ーションをデプロイするための手順を説明します。

## 1. 環境設定

必要な環境を設定します。主に以下のツールが必要です:
- Node.js
- npm
- Docker

## 2. コードの取得

リポジトリから最新のコードを取得します。コマンドは以下の通りです:
```bash
git clone https://github.com/gaojiemm/dev-test.git
cd dev-test
```

## 3. 依存関係のインストール

プロジェクトのルートディレクトリで以下のコマンドを実行して、依存関係をインストールします:
```bash
npm install
```

## 4. アプリケーションのビルド

次に、アプリケーションをビルドします:
```bash
npm run build
```

## 5. Dockerの設定

アプリケーション用のDockerイメージをビルドします:
```bash
docker build -t your-image-name .
```

## 6. アプリケーションのデプロイ

Dockerコンテナを起動します:
```bash
docker run -d -p 80:80 your-image-name
```

## 7. 確認

ブラウザで `http://localhost` にアクセスして、アプリケーションが正しくデプロイされたか確認します。

## 8. トラブルシューティング

問題が発生した場合には、以下のコマンドでログを確認できます:
```bash
docker logs container_id
```

このガイドが役に立つことを願っています！