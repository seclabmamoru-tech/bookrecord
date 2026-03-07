<?php
/**
 * Biblion サーバー設定ファイル
 *
 * 【重要】このファイルはWebルートの外に配置してください。
 * 推奨配置場所: public_html の一つ上のディレクトリ
 *   例: /home/（ユーザー名）/biblion_config.php
 *
 * ai.php 内の $configPath を実際の配置パスに合わせて変更してください。
 */

// Anthropic APIキー
// https://console.anthropic.com/ で取得したキーを設定
$ANTHROPIC_API_KEY = 'sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx';

// iOSアプリと共有する簡易シークレット（推測されにくいランダム文字列）
// 例: openssl rand -hex 32 で生成
$ALLOWED_SECRET = 'your-random-secret-here';
