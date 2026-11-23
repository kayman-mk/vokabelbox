<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

session_name('vokabelbox_session');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'httponly' => true,
    'samesite' => 'Strict',
]);
ini_set('session.use_strict_mode', '1');
session_start();

function respond(int $status, array $payload): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function database(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $host = getenv('DB_HOST') ?: 'db';
    $name = getenv('DB_NAME') ?: 'vokabelbox';
    $user = getenv('DB_USER') ?: 'vokabelbox';
    $password = getenv('DB_PASSWORD') ?: '';
    $pdo = new PDO(
        "mysql:host={$host};dbname={$name};charset=utf8mb4",
        $user,
        $password,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
    return $pdo;
}

function request_body(): array
{
    $decoded = json_decode(file_get_contents('php://input') ?: '', true);
    return is_array($decoded) ? $decoded : [];
}

function authenticated_user(): array
{
    if (!isset($_SESSION['user_id'])) {
        respond(401, ['error' => 'Please sign in.']);
    }

    $query = database()->prepare('SELECT id, username FROM users WHERE id = :id AND is_active = 1');
    $query->execute(['id' => $_SESSION['user_id']]);
    $user = $query->fetch();
    if ($user === false) {
        $_SESSION = [];
        session_destroy();
        respond(401, ['error' => 'Please sign in.']);
    }
    return $user;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if ($method === 'GET' && $path === '/api/v1/health') {
    database()->query('SELECT 1');
    respond(200, ['status' => 'ok']);
}

if ($method === 'POST' && $path === '/api/v1/auth/login') {
    $body = request_body();
    $username = trim((string)($body['username'] ?? ''));
    $password = (string)($body['password'] ?? '');
    $query = database()->prepare('SELECT id, username, password_hash FROM users WHERE username = :username AND is_active = 1');
    $query->execute(['username' => $username]);
    $user = $query->fetch();

    if ($user === false || !password_verify($password, $user['password_hash'])) {
        respond(401, ['error' => 'Username or password is incorrect.']);
    }

    session_regenerate_id(true);
    $_SESSION['user_id'] = (int)$user['id'];
    respond(200, ['id' => (int)$user['id'], 'username' => $user['username']]);
}

if ($method === 'GET' && $path === '/api/v1/auth/me') {
    $user = authenticated_user();
    respond(200, ['id' => (int)$user['id'], 'username' => $user['username']]);
}

if ($method === 'POST' && $path === '/api/v1/auth/logout') {
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', [
            'expires' => time() - 42000,
            'path' => $params['path'],
            'secure' => $params['secure'],
            'httponly' => $params['httponly'],
            'samesite' => $params['samesite'],
        ]);
    }
    session_destroy();
    respond(200, ['status' => 'ok']);
}

$user = authenticated_user();
$userId = (int)$user['id'];

if ($method === 'GET' && $path === '/api/v1/sets') {
    $query = database()->prepare(
        'SELECT s.id, s.name, COUNT(v.id) AS word_count
         FROM vocabulary_sets s
         LEFT JOIN vocabularies v ON v.vocabulary_set_id = s.id
         WHERE s.owner_user_id = :owner_user_id
         GROUP BY s.id, s.name
         ORDER BY s.created_at DESC'
    );
    $query->execute(['owner_user_id' => $userId]);
    respond(200, ['sets' => array_map(static fn(array $row): array => [
        'id' => (int)$row['id'],
        'name' => $row['name'],
        'wordCount' => (int)$row['word_count'],
    ], $query->fetchAll())]);
}

if ($method === 'POST' && $path === '/api/v1/sets') {
    $name = trim((string)(request_body()['name'] ?? ''));
    if ($name === '' || mb_strlen($name) > 120) {
        respond(422, ['error' => 'List name must contain between 1 and 120 characters.']);
    }
    $insert = database()->prepare('INSERT INTO vocabulary_sets (owner_user_id, name) VALUES (:owner, :name)');
    $insert->execute(['owner' => $userId, 'name' => $name]);
    respond(201, ['id' => (int)database()->lastInsertId(), 'name' => $name, 'wordCount' => 0]);
}

if (preg_match('#^/api/v1/sets/(\d+)/words$#', $path, $matches) === 1) {
    $setId = (int)$matches[1];
    $setQuery = database()->prepare('SELECT id FROM vocabulary_sets WHERE id = :id AND owner_user_id = :owner');
    $setQuery->execute(['id' => $setId, 'owner' => $userId]);
    if ($setQuery->fetchColumn() === false) {
        respond(404, ['error' => 'List not found.']);
    }

    if ($method === 'GET') {
        $query = database()->prepare(
            'SELECT id, prompt, answer FROM vocabularies WHERE vocabulary_set_id = :set_id ORDER BY id'
        );
        $query->execute(['set_id' => $setId]);
        respond(200, ['words' => array_map(static fn(array $row): array => [
            'id' => (int)$row['id'],
            'prompt' => $row['prompt'],
            'answer' => $row['answer'],
        ], $query->fetchAll())]);
    }

    if ($method === 'POST') {
        $body = request_body();
        $prompt = trim((string)($body['prompt'] ?? ''));
        $answer = trim((string)($body['answer'] ?? ''));
        if ($prompt === '' || $answer === '' || mb_strlen($prompt) > 255 || mb_strlen($answer) > 500) {
            respond(422, ['error' => 'Prompt and answer are required and must fit the allowed length.']);
        }
        $insert = database()->prepare(
            'INSERT INTO vocabularies (vocabulary_set_id, prompt, answer) VALUES (:set_id, :prompt, :answer)'
        );
        $insert->execute(['set_id' => $setId, 'prompt' => $prompt, 'answer' => $answer]);
        respond(201, ['id' => (int)database()->lastInsertId(), 'prompt' => $prompt, 'answer' => $answer]);
    }
}

respond(404, ['error' => 'Endpoint not found.']);
