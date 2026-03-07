<?php
/**
 * Biblion AI Proxy
 * エンドポイント: POST /api/biblion/ai
 *
 * iOSアプリからのリクエストを受け取り、Anthropic APIへ転送する。
 * APIキーはサーバー側にのみ保持する。
 */

// --------------------------------------------------------------------------
// 設定読み込み
// --------------------------------------------------------------------------
$configPath = dirname(__DIR__, 2) . '/biblion_config.php';
if (!file_exists($configPath)) {
    http_response_code(500);
    echo json_encode(['error' => 'Server configuration missing.']);
    exit;
}
require $configPath;

// $ANTHROPIC_API_KEY が定義されている前提
// $ALLOWED_SECRET   が定義されている前提（iOSアプリ側と共有する簡易シークレット）

// --------------------------------------------------------------------------
// CORSヘッダー（必要に応じて）
// --------------------------------------------------------------------------
header('Content-Type: application/json; charset=utf-8');

// --------------------------------------------------------------------------
// POSTリクエストのみ受け付ける
// --------------------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed.']);
    exit;
}

// --------------------------------------------------------------------------
// 簡易シークレット認証（X-App-Secret ヘッダー）
// --------------------------------------------------------------------------
$receivedSecret = $_SERVER['HTTP_X_APP_SECRET'] ?? '';
if (!hash_equals($ALLOWED_SECRET, $receivedSecret)) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized.']);
    exit;
}

// --------------------------------------------------------------------------
// リクエストボディのパース
// --------------------------------------------------------------------------
$raw  = file_get_contents('php://input');
$body = json_decode($raw, true);

if (
    !isset($body['menuType'], $body['userInput'], $body['bookData']) ||
    !in_array($body['menuType'], ['consultation', 'summary', 'sns'], true) ||
    !is_string($body['userInput']) ||
    !is_array($body['bookData'])
) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid request parameters.']);
    exit;
}

$userInput = trim($body['userInput']);
$bookData  = $body['bookData'];

if (strlen($userInput) === 0 || strlen($userInput) > 20000) {
    http_response_code(400);
    echo json_encode(['error' => 'userInput is empty or too long.']);
    exit;
}

// --------------------------------------------------------------------------
// Anthropic API へリクエスト
// --------------------------------------------------------------------------
$anthropicPayload = json_encode([
    'model'      => 'claude-opus-4-6',
    'max_tokens' => 2048,
    'messages'   => [
        ['role' => 'user', 'content' => $userInput]
    ]
]);

$ch = curl_init('https://api.anthropic.com/v1/messages');
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => $anthropicPayload,
    CURLOPT_TIMEOUT        => 60,
    CURLOPT_HTTPHEADER     => [
        'Content-Type: application/json',
        'x-api-key: ' . $ANTHROPIC_API_KEY,
        'anthropic-version: 2023-06-01',
    ],
]);

$response   = curl_exec($ch);
$httpStatus = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError  = curl_error($ch);
curl_close($ch);

if ($curlError) {
    http_response_code(502);
    echo json_encode(['error' => 'Failed to connect to AI service.']);
    exit;
}

if ($httpStatus !== 200) {
    http_response_code(502);
    echo json_encode(['error' => "AI service returned HTTP $httpStatus."]);
    exit;
}

// --------------------------------------------------------------------------
// レスポンス整形（iOSアプリが期待する形式に変換）
// AIResponse: { result: String, referencedBooks: [String] }
// --------------------------------------------------------------------------
$decoded = json_decode($response, true);
$text    = $decoded['content'][0]['text'] ?? '';

// 参照書籍: bookDataのタイトルをそのまま返す
$referencedBooks = array_map(fn($b) => $b['title'] ?? '', $bookData);

echo json_encode([
    'result'          => $text,
    'referencedBooks' => $referencedBooks,
], JSON_UNESCAPED_UNICODE);
