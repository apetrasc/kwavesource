<!-- omit in toc -->
# 2021-07-14 株式会社XXXXX様 SIEM on Amazon ES環境設定手順

## 1. ドキュメント作成者

CM) のんピ(のんピのメールアドレス)

## 2. 改訂履歴

- 1.0:
  - 作成日時: 2021-07-12 13:48:45
  - 更新内容: 初版作成

## 3. このドキュメントの目次

- [1. ドキュメント作成者](#1-ドキュメント作成者)
- [2. 改訂履歴](#2-改訂履歴)
- [3. このドキュメントの目次](#3-このドキュメントの目次)
- [4. このドキュメントの目的・概要](#4-このドキュメントの目的概要)
- [5. 前提条件](#5-前提条件)
- [6. 作業完了条件](#6-作業完了条件)
- [7. 作業者](#7-作業者)
- [8. 副作業者 (チェッカー)](#8-副作業者-チェッカー)
- [9. 作業場所](#9-作業場所)
- [10. 作業端末](#10-作業端末)
- [11. 予定作業時間](#11-予定作業時間)
- [12. その他制約事項・備考](#12-その他制約事項備考)
- [13. 参考情報](#13-参考情報)
- [14. 作業実績](#14-作業実績)
  - [14.1. 作業結果](#141-作業結果)
    - [14.1.1. OK or NG](#1411-ok-or-ng)
    - [14.1.2. NGと判断した理由](#1412-ngと判断した理由)
    - [14.1.3. NGとなった原因](#1413-ngとなった原因)
    - [14.1.4. 次回アクション](#1414-次回アクション)
  - [14.2. 作業開始・終了時間](#142-作業開始終了時間)
- [15. 手順書](#15-手順書)
  - [15.1. ログイン [想定作業時間: 3分]](#151-ログイン-想定作業時間-3分)
  - [15.2. スイッチロール [想定作業時間: 3分]](#152-スイッチロール-想定作業時間-3分)

## 4. このドキュメントの目的・概要

株式会社XXXXX様(以下XXX)のSIEM on Amazon ESの環境設定を行うための手順書。  
既存お客様環境にはログ集約の仕組みはないため、新規にSIEM on Amazon ESをVPC上にデプロイし、SIEM on Amazon ESにログを集約し、分析する。

なお、本作業ではSIEM on Amazon ES用AWSアカウント(`123456789012`)以外のAWSアカウント上のリソースからのログ集約は行わない。

設定範囲は以下の通り。  

![全体構成図](./images/全体構成図.png)

設定するリソースは以下の通り。

- VPC: 1
- VPC Flow Logs: 1
- DHCP Options Sets: 1
- Subnet: 6
- Route Table: 6
- Internet Gateway: 1
- NAT Gateway: 1
- Elastic IP IP: 2
- Security Group: 2
- Network ACL: 1
- EC2 Instance: 1
- EBS Volume: 1
- CloudTrail: 1
- Secrutiy Hub: 1
- GuardDuty: 1
- IAM Access Analyzer: 1
- CloudWatch Logs
- Kinesis Data Firehose: 2
- SIEM on Amazon ES: 1
  - SIEM on Amazon ESをデプロイ時に作成されるリソースは、[SIEM on Amazon ESの公式ドキュメント](https://github.com/aws-samples/siem-on-amazon-elasticsearch-service/blob/main/README_ja.md#%E4%BD%9C%E6%88%90%E3%81%95%E3%82%8C%E3%82%8B-aws-%E3%83%AA%E3%82%BD%E3%83%BC%E3%82%B9)を参照

## 5. 前提条件

- [BacklogのWikiに記載したパラメーターシート](URL)をXXX様にレビューしていただいていること。
- XXX様のSIEM on Amazon ES用のAWSアカウント(`123456789012`)で、作業者の作業用のIAM Roleの作成が完了していること。
- 作業用端末に、[AWS Extend Switch Roles](URL)がインストール済みであり、`cm-XXX-Read`と、`cm-XXX-Admin`にスイッチロールする設定がされていること。

## 6. 作業完了条件

- 全てのリソースの作成が完了する。
- 作業者及び、副作業者が[BacklogのWikiに記載したパラメーターシート](URL)と実機とを見比べて、誤った設定がされていないと確認できる。

## 7. 作業者

CM) のんピ(のんピのメールアドレス)

## 8. 副作業者 (チェッカー)

CM) チバユキ(チバユキさんのメールアドレス)

## 9. 作業場所

岩本町ツインビル 7階

## 10. 作業端末

自端末(MacBook Pro 13-inch, 2020)

## 11. 予定作業時間

2021-07-14 09:00 〜 2021-07-14 16:00

## 12. その他制約事項・備考

- [お客様のBacklog](URL)は、IPアドレス制限をしているため、アクセスする際は、[こちらの手順](URL) を参考にVPN接続をすること。
- リソースの設定が出来次第、対応するBacklogの課題のステータスを`処理済み`に変更すること。
- 全ての作業が完了したら、XXX)xx様、XXX)yy様に連絡すること。
- **意図しない事象に遭遇した場合は、CM)チバユキさんに連絡すること。**

## 13. 参考情報

- [XXX他プロジェクト(XXXX)のBacklog](URL)
- [パラメーターシート](URL)
- [SIEM on Amazon ES公式ドキュメント](https://github.com/aws-samples/siem-on-amazon-elasticsearch-service/blob/main/README_ja.md)

## 14. 作業実績

以下項目は、作業終了後に入力すること

### 14.1. 作業結果

#### 14.1.1. OK or NG

以下に OK or NG を記入

```text

```

#### 14.1.2. NGと判断した理由

NGだった場合、以下に NGと判断した理由 を記入

```text

```

例)

```text
手順15.5.2. で意図しないエラーが発生したため。
エラー文は以下の通り。

error error error error error error
```

#### 14.1.3. NGとなった原因

NGだった場合、以下に NGとなった原因 を記入

```text

```

例)

```text
エラー文の`error`という文言と、リソースがxxな状態であることからIAMロールの権限不足だと考える
```

#### 14.1.4. 次回アクション

NGだった場合、以下に 原因解消のために次に行うべきアクション を記入

```text

```

例)

```text
以下の流れでアクションする
1. 検証環境にて、IAMロール 'test-role' にアタッチしているIAMポリシー `test-policy` で 'xxxx'を許可するように変更する
2. NGとなった15.5.2と同様の手順を実施し、エラーが解消されていることを確認する
3. エラーが解消されたことを確認して、お客様と次回作業日時をすり合わせる
```

### 14.2. 作業開始・終了時間

以下に 作業開始・終了時間(YYYY-MM-DD HH:MM 〜 YYYY-MM-DD HH:MM) を記入

```text

```

例)

```text
2021-07-14 10:10 〜 2021-07-14 12:25
2021-07-14 14:23 〜 2021-07-14 17:30
```

## 15. 手順書

### 15.1. ログイン [想定作業時間: 3分]

- [ ] [AWSマネージメントコンソールのURL](https://console.aws.amazon.com/console/home)をクリックする。
- [ ] 以下の必要な情報を入力して`サインイン`をクリックする。
  - [ ] アカウントID: `123456789012`
  - [ ] ユーザー名: `xxxxxxxx`
  - [ ] パスワード: `自分のIAMユーザーのパスワード`
- [ ] MFAコードを入力し、`送信`をクリックする。
- [ ] マネジメントコンソール上部に、**AWS マネジメントコンソール**を大きく表示されることを確認する。

### 15.2. スイッチロール [想定作業時間: 3分]

- [ ] ブラウザの拡張機能のAWS Extend Switch Rolesから、`cm-XXX-Read`をクリックする。
- [ ] マネジメントコンソール上部のメニューの`cm-XXX-Read`をクリックし、アカウントが、XXX様SIEM on Amazon ES用のAWSアカウントIDの`123456789012`であることを確認する。
- [ ] マネジメントコンソール上部の検索バーで`Lambda`と入力し、`Lambda`をクリックする。
- [ ] `cm-yamamoto-ryota-iamRole-LU-Level-upper`をクリックする。
- [ ] `テスト`タブをクリックする。
- [ ] 以下情報を入力し、`テスト`をクリックする。
  - [ ] 名前: `LevelUpFor3Hours`
  - [ ] テキストエリア:

```json
{
  "limit": "3:00"
}
```

- **実行結果: 成功**と表示され、`詳細`をクリックすると、**YYYY-MM-DD HH:MM:SSまで権限が与えられます**といった文章が表示されることを確認する。
- [ ] ブラウザの拡張機能のAWS Extend Switch Rolesから、`cm-XXX-Read`をクリックする。
- [ ] マネジメントコンソール上部のメニューの`cm-XXX-Admin`をクリックし、アカウントが、XXX様のSIEM on Amazon ES用のAWSアカウントIDの`123456789012`であることを確認する。

