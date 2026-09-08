<?php
declare(strict_types=1);

// YBS AI PHP + MySQL API
// Endpoints:
// GET  /api/notifications?limit=50
// POST /api/notifications          (X-Admin-Token required)
// POST /api/feedback

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, X-Admin-Token');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function env_value(string $key, ?string $fallback = null): ?string {
    static $localEnv = null;
    if ($localEnv === null) {
        $localEnv = [];
        $envFile = dirname(__DIR__) . DIRECTORY_SEPARATOR . '.env';
        if (is_readable($envFile)) {
            foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
                $line = trim($line);
                if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
                [$name, $value] = explode('=', $line, 2);
                $localEnv[trim($name)] = trim($value, " \t\"'");
            }
        }
    }
    $value = getenv($key);
    if ($value === false || $value === '') $value = $localEnv[$key] ?? false;
    return ($value === false || $value === '') ? $fallback : $value;
}

function respond(array $payload, int $status = 200): never {
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function fail(string $message, int $status = 400): never {
    respond(['error' => $message], $status);
}

function body_json(): array {
    $raw = file_get_contents('php://input') ?: '';
    $data = json_decode($raw, true);
    if (!is_array($data)) fail('Invalid JSON body');
    return $data;
}

function text_field(array $data, string $key, int $max, bool $required = false): ?string {
    $value = isset($data[$key]) && is_string($data[$key]) ? trim($data[$key]) : '';
    if ($required && $value === '') fail("$key is required");
    if (mb_strlen($value) > $max) fail("$key is too long");
    return $value === '' ? null : $value;
}

function db(): PDO {
    static $pdo = null;
    if ($pdo instanceof PDO) return $pdo;
    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        env_value('DB_HOST', '127.0.0.1'),
        env_value('DB_PORT', '3306'),
        env_value('DB_NAME', 'ybs_ai')
    );
    try {
        $pdo = new PDO($dsn, env_value('DB_USER', 'ybs_api'), env_value('DB_PASS', ''), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        return $pdo;
    } catch (Throwable $e) {
        error_log('YBS API DB error: ' . $e->getMessage());
        fail('Database temporarily unavailable', 503);
    }
}

function request_path(): string {
    $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $path = preg_replace('#^/index\.php#', '', $path) ?: $path;
    return rtrim($path, '/') ?: '/';
}

function require_admin(): void {
    $expected = env_value('ADMIN_API_TOKEN');
    $provided = $_SERVER['HTTP_X_ADMIN_TOKEN'] ?? '';
    if (!$expected || !$provided || !hash_equals($expected, $provided)) {
        fail('Admin authentication required', 401);
    }
}

function check_feedback_rate_limit(): void {
    // Lightweight per-IP limit: 10 feedback submissions per hour.
    $ipHash = hash('sha256', $_SERVER['REMOTE_ADDR'] ?? 'unknown');
    $stmt = db()->prepare(
        'SELECT COUNT(*) FROM feedback WHERE ip_hash = :ip AND created_at >= (UTC_TIMESTAMP() - INTERVAL 1 HOUR)'
    );
    $stmt->execute(['ip' => $ipHash]);
    if ((int)$stmt->fetchColumn() >= 10) fail('Too many feedback submissions. Try again later.', 429);
}

$path = request_path();
$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($path === '/api/notifications' && $method === 'GET') {
        $limit = max(1, min(100, (int)($_GET['limit'] ?? 50)));
        $stmt = db()->prepare(
            'SELECT id, title, message, type, UNIX_TIMESTAMP(created_at) * 1000 AS createdAt
             FROM notifications WHERE is_published = 1 ORDER BY created_at DESC LIMIT :limit'
        );
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = array_map(static function (array $row): array {
            return [
                'id' => (int)$row['id'],
                'title' => (string)$row['title'],
                'message' => (string)$row['message'],
                'type' => (string)$row['type'],
                'createdAt' => (int)$row['createdAt'],
            ];
        }, $stmt->fetchAll());
        respond(['notifications' => $rows]);
    }

    if ($path === '/api/notifications' && $method === 'POST') {
        require_admin();
        $data = body_json();
        $title = text_field($data, 'title', 160, true);
        $message = text_field($data, 'message', 5000, true);
        $type = text_field($data, 'type', 20) ?? 'info';
        if (!in_array($type, ['info', 'update', 'alert'], true)) fail('Invalid notification type');
        $stmt = db()->prepare(
            'INSERT INTO notifications (title, message, type, is_published) VALUES (:title, :message, :type, 1)'
        );
        $stmt->execute(['title' => $title, 'message' => $message, 'type' => $type]);
        respond(['ok' => true, 'id' => (int)db()->lastInsertId()], 201);
    }

    if ($path === '/api/feedback' && $method === 'POST') {
        check_feedback_rate_limit();
        $data = body_json();
        $type = text_field($data, 'type', 30, true);
        $message = text_field($data, 'message', 5000, true);
        $routeId = text_field($data, 'routeId', 80);
        $userId = text_field($data, 'userId', 120);
        if (!in_array($type, ['bug', 'wrong_info', 'suggestion', 'other'], true)) {
            fail('Invalid feedback type');
        }
        $stmt = db()->prepare(
            'INSERT INTO feedback (type, message, route_id, user_id, ip_hash)
             VALUES (:type, :message, :route_id, :user_id, :ip_hash)'
        );
        $stmt->execute([
            'type' => $type,
            'message' => $message,
            'route_id' => $routeId,
            'user_id' => $userId,
            'ip_hash' => hash('sha256', $_SERVER['REMOTE_ADDR'] ?? 'unknown'),
        ]);
        respond(['ok' => true, 'id' => (int)db()->lastInsertId()], 201);
    }

    fail('Endpoint not found', 404);
} catch (PDOException $e) {
    error_log('YBS API query error: ' . $e->getMessage());
    fail('Request could not be completed', 500);
} catch (Throwable $e) {
    error_log('YBS API error: ' . $e->getMessage());
    fail('Request could not be completed', 500);
}
