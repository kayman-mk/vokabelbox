<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
require __DIR__ . '/../src/config_loader.php';
$config = load_app_config();
require __DIR__ . '/../src/uuid.php';
require __DIR__ . '/../src/fsrs.php';

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
    global $config;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $database = $config['database'];
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $database['host'], $database['port'], $database['name']),
        $database['user'],
        $database['password'],
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

function is_local_ip(string $ip): bool
{
    $packed = inet_pton($ip);
    if ($packed === false) {
        return false;
    }
    $ranges = str_contains($ip, ':')
        ? [['::1', 128], ['fc00::', 7], ['fe80::', 10]]
        : [['127.0.0.0', 8], ['10.0.0.0', 8], ['172.16.0.0', 12], ['192.168.0.0', 16]];
    foreach ($ranges as [$network, $prefix]) {
        $networkPacked = inet_pton($network);
        if ($networkPacked === false || strlen($networkPacked) !== strlen($packed)) {
            continue;
        }
        $bytes = intdiv($prefix, 8);
        $remainingBits = $prefix % 8;
        if (substr($packed, 0, $bytes) !== substr($networkPacked, 0, $bytes)) {
            continue;
        }
        if ($remainingBits === 0 || (ord($packed[$bytes]) >> (8 - $remainingBits)) === (ord($networkPacked[$bytes]) >> (8 - $remainingBits))) {
            return true;
        }
    }
    return false;
}

function enforce_rate_limit(string $ip, string $bucket, float $capacity, float $refillPerSecond): void
{
    $directory = sys_get_temp_dir() . '/vokabelbox-rate-limits';
    if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
        respond(503, ['error' => 'Request limiter is unavailable.']);
    }
    $file = fopen($directory . '/' . hash('sha256', $ip) . '.json', 'c+');
    if ($file === false || !flock($file, LOCK_EX)) {
        if (is_resource($file)) {
            fclose($file);
        }
        respond(503, ['error' => 'Request limiter is unavailable.']);
    }

    $state = json_decode(stream_get_contents($file) ?: '', true);
    $state = is_array($state) ? $state : [];
    $now = microtime(true);
    $bucketState = is_array($state) ? ($state[$bucket] ?? null) : null;
    $tokens = is_array($bucketState) && is_numeric($bucketState['tokens'] ?? null)
        ? min($capacity, (float)$bucketState['tokens'] + max(0.0, $now - (float)($bucketState['updated'] ?? $now)) * $refillPerSecond)
        : $capacity;
    $allowed = $tokens >= 1.0;
    if ($allowed) {
        $tokens -= 1.0;
    }
    $state[$bucket] = ['tokens' => $tokens, 'updated' => $now];
    rewind($file);
    ftruncate($file, 0);
    fwrite($file, json_encode($state, JSON_THROW_ON_ERROR));
    fflush($file);
    flock($file, LOCK_UN);
    fclose($file);

    if (!$allowed) {
        $retryAfter = max(1, (int)ceil((1.0 - $tokens) / $refillPerSecond));
        header('Retry-After: ' . $retryAfter);
        respond(429, ['error' => 'Too many requests. Please try again later.']);
    }
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
if ($path === '/api.php') {
    $route = (string)($_GET['route'] ?? '/');
    $path = '/api/v1' . (str_starts_with($route, '/') ? $route : '/' . $route);
}

$clientIp = (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown');
enforce_rate_limit($clientIp, 'all', 120.0, 2.0);
if ($method === 'POST' && $path === '/api/v1/auth/login') {
    enforce_rate_limit($clientIp, 'login', 5.0, 1.0 / 180.0);
}

if ($method === 'GET' && $path === '/api/v1/health') {
    if (!is_local_ip($clientIp)) {
        respond(403, ['error' => 'Health endpoint is available only from local networks.']);
    }
    database()->query('SELECT 1');
    respond(200, ['status' => 'ok']);
}

if (in_array($path, ['/api/v1/setup', '/api/v1/setup.php'], true)) {
    require __DIR__ . '/../bin/init.php';
    exit;
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
    $_SESSION['user_id'] = $user['id'];
    respond(200, ['id' => $user['id'], 'username' => $user['username']]);
}

if ($method === 'GET' && $path === '/api/v1/auth/me') {
    $user = authenticated_user();
    respond(200, ['id' => $user['id'], 'username' => $user['username']]);
}

if (in_array($path, ['/api/v1/motivation', '/api/v1/motivation/'], true)) {
    $user = authenticated_user();
    if ($method === 'GET') {
        $query = database()->prepare(
            "SELECT u.daily_review_goal AS dailyGoal,
                    (SELECT COUNT(*) FROM learning_review_events e
                     WHERE e.user_id = u.id AND e.reviewed_at >= UTC_DATE()) AS reviewsToday
             FROM users u WHERE u.id = :user_id"
        );
        $query->execute(['user_id' => $user['id']]);
        $progress = $query->fetch();
        respond(200, ['dailyGoal' => (int)$progress['dailyGoal'], 'reviewsToday' => (int)$progress['reviewsToday']]);
    }
    if ($method === 'PUT') {
        $goal = filter_var(request_body()['dailyGoal'] ?? null, FILTER_VALIDATE_INT);
        if ($goal === false || $goal < 1 || $goal > 100) {
            respond(422, ['error' => 'Daily goal must be between 1 and 100 cards.']);
        }
        $update = database()->prepare('UPDATE users SET daily_review_goal = :goal WHERE id = :user_id');
        $update->execute(['goal' => $goal, 'user_id' => $user['id']]);
        respond(200, ['dailyGoal' => $goal]);
    }
}

$user = authenticated_user();
$userId = $user['id'];

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

if ($method === 'GET' && $path === '/api/v1/sets') {
    $query = database()->prepare(
        'SELECT s.id, s.name, s.description, COUNT(v.id) AS word_count
         FROM vocabulary_sets s
         LEFT JOIN vocabularies v ON v.vocabulary_set_id = s.id
         WHERE s.owner_user_id = :owner_user_id
         GROUP BY s.id, s.name, s.description
         ORDER BY s.created_at DESC'
    );
    $query->execute(['owner_user_id' => $userId]);
    respond(200, ['sets' => array_map(static fn(array $row): array => [
        'id' => $row['id'],
        'name' => $row['name'],
        'description' => $row['description'],
        'wordCount' => (int)$row['word_count'],
    ], $query->fetchAll())]);
}

if ($method === 'POST' && $path === '/api/v1/sets') {
    $body = request_body();
    $name = trim((string)($body['name'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    if ($name === '' || mb_strlen($name) > 120) {
        respond(422, ['error' => 'List name must contain between 1 and 120 characters.']);
    }
    if (mb_strlen($description) > 500) {
        respond(422, ['error' => 'List description must not exceed 500 characters.']);
    }
    $id = uuid_v4();
    $insert = database()->prepare('INSERT INTO vocabulary_sets (id, owner_user_id, name, description) VALUES (:id, :owner, :name, :description)');
    $insert->execute(['id' => $id, 'owner' => $userId, 'name' => $name, 'description' => $description]);
    respond(201, ['id' => $id, 'name' => $name, 'description' => $description, 'wordCount' => 0]);
}

if ($method === 'PUT' && preg_match('#^/api/v1/sets/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$#', $path, $matches) === 1) {
    $setId = strtolower($matches[1]);
    $body = request_body();
    $name = trim((string)($body['name'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    if ($name === '' || mb_strlen($name) > 120) {
        respond(422, ['error' => 'List name must contain between 1 and 120 characters.']);
    }
    if (mb_strlen($description) > 500) {
        respond(422, ['error' => 'List description must not exceed 500 characters.']);
    }
    $update = database()->prepare('UPDATE vocabulary_sets SET name = :name, description = :description WHERE id = :id AND owner_user_id = :owner');
    $update->execute(['name' => $name, 'description' => $description, 'id' => $setId, 'owner' => $userId]);
    if ($update->rowCount() === 0) {
        $exists = database()->prepare('SELECT 1 FROM vocabulary_sets WHERE id = :id AND owner_user_id = :owner');
        $exists->execute(['id' => $setId, 'owner' => $userId]);
        if ($exists->fetchColumn() === false) {
            respond(404, ['error' => 'List not found.']);
        }
    }
    respond(200, ['id' => $setId, 'name' => $name, 'description' => $description]);
}

if ($method === 'POST' && preg_match('#^/api/v1/sets/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/imports$#', $path, $matches) === 1) {
    $setId = strtolower($matches[1]);
    $setQuery = database()->prepare('SELECT id FROM vocabulary_sets WHERE id = :id AND owner_user_id = :owner');
    $setQuery->execute(['id' => $setId, 'owner' => $userId]);
    if ($setQuery->fetchColumn() === false) {
        respond(404, ['error' => 'List not found.']);
    }

    $rows = request_body()['rows'] ?? null;
    if (!is_array($rows) || !array_is_list($rows) || count($rows) < 1 || count($rows) > 500) {
        respond(422, ['error' => 'Import must contain between 1 and 500 rows.']);
    }

    $validRows = [];
    $invalidRows = [];
    foreach ($rows as $index => $row) {
        if (!is_array($row) || !is_string($row['prompt'] ?? null) || !is_string($row['answer'] ?? null)) {
            $invalidRows[] = $index + 1;
            continue;
        }
        $prompt = trim($row['prompt']);
        $answer = trim($row['answer']);
        if ($prompt === '' || $answer === '' || mb_strlen($prompt) > 255 || mb_strlen($answer) > 500) {
            $invalidRows[] = $index + 1;
            continue;
        }
        $validRows[] = ['prompt' => $prompt, 'answer' => $answer];
    }
    if ($invalidRows !== []) {
        respond(422, ['error' => 'Some import rows are invalid; no rows were imported.', 'invalidRows' => $invalidRows]);
    }

    $pdo = database();
    try {
        $pdo->beginTransaction();
        $existingQuery = $pdo->prepare('SELECT prompt, answer FROM vocabularies WHERE vocabulary_set_id = :set_id');
        $existingQuery->execute(['set_id' => $setId]);
        $seen = [];
        foreach ($existingQuery->fetchAll() as $existing) {
            $key = mb_strtolower($existing['prompt'], 'UTF-8') . "\0" . mb_strtolower($existing['answer'], 'UTF-8');
            $seen[$key] = true;
        }

        $insert = $pdo->prepare(
            'INSERT INTO vocabularies (id, vocabulary_set_id, prompt, answer) VALUES (:id, :set_id, :prompt, :answer)'
        );
        $created = 0;
        $skippedDuplicates = 0;
        foreach ($validRows as $row) {
            $key = mb_strtolower($row['prompt'], 'UTF-8') . "\0" . mb_strtolower($row['answer'], 'UTF-8');
            if (isset($seen[$key])) {
                $skippedDuplicates++;
                continue;
            }
            $insert->execute([
                'id' => uuid_v4(),
                'set_id' => $setId,
                'prompt' => $row['prompt'],
                'answer' => $row['answer'],
            ]);
            $seen[$key] = true;
            $created++;
        }
        $pdo->commit();
        respond(201, ['created' => $created, 'skippedDuplicates' => $skippedDuplicates]);
    } catch (Throwable $exception) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        error_log('Vocabulary import failed; the transaction was rolled back.');
        respond(500, ['error' => 'Import failed. No rows were imported.']);
    }
}

if (preg_match('#^/api/v1/sets/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/study(?:/reviews)?$#', $path, $matches) === 1) {
    $setId = strtolower($matches[1]);
    $direction = (string)($_GET['direction'] ?? request_body()['direction'] ?? '');
    $methodName = (string)($_GET['method'] ?? request_body()['method'] ?? 'fsrs');
    if (!in_array($direction, ['foreign_to_local', 'local_to_foreign'], true) || $methodName !== 'fsrs') {
        respond(422, ['error' => 'Choose FSRS and a valid study direction.']);
    }
    $setQuery = database()->prepare('SELECT id FROM vocabulary_sets WHERE id = :id AND owner_user_id = :owner');
    $setQuery->execute(['id' => $setId, 'owner' => $userId]);
    if ($setQuery->fetchColumn() === false) {
        respond(404, ['error' => 'List not found.']);
    }

    if ($method === 'GET' && str_ends_with($path, '/study')) {
        $limit = filter_var($_GET['limit'] ?? 20, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 50]]);
        if ($limit === false) {
            respond(422, ['error' => 'Study session limit must be between 1 and 50.']);
        }
        $stats = database()->prepare(
            "SELECT COUNT(*) AS total,
                    SUM(p.vocabulary_id IS NULL) AS new_count,
                    SUM(p.vocabulary_id IS NOT NULL AND p.due_at <= UTC_TIMESTAMP()) AS due_count,
                    SUM(p.repetitions > 0) AS reviewed_count,
                    COALESCE(SUM(p.repetitions), 0) AS repetitions,
                    COALESCE(SUM(p.lapses), 0) AS lapses
             FROM vocabularies v
             LEFT JOIN learning_progress p ON p.vocabulary_id = v.id AND p.user_id = :user_id
                AND p.learning_method = 'fsrs' AND p.direction = :direction
             WHERE v.vocabulary_set_id = :set_id"
        );
        $stats->execute(['user_id' => $userId, 'direction' => $direction, 'set_id' => $setId]);
        $queue = database()->prepare(
            "SELECT v.id, v.prompt, v.answer, p.state, p.repetitions, p.lapses, p.due_at
             FROM vocabularies v
             LEFT JOIN learning_progress p ON p.vocabulary_id = v.id AND p.user_id = :user_id
                AND p.learning_method = 'fsrs' AND p.direction = :direction
             WHERE v.vocabulary_set_id = :set_id
               AND (p.vocabulary_id IS NULL OR p.due_at <= UTC_TIMESTAMP())
             ORDER BY (p.vocabulary_id IS NOT NULL) DESC, p.due_at ASC, v.created_at ASC
             LIMIT {$limit}"
        );
        $queue->execute(['user_id' => $userId, 'direction' => $direction, 'set_id' => $setId]);
        $cards = array_map(static function (array $row) use ($direction): array {
            $forward = $direction === 'foreign_to_local';
            return [
                'id' => $row['id'],
                'front' => $forward ? $row['prompt'] : $row['answer'],
                'back' => $forward ? $row['answer'] : $row['prompt'],
                'state' => $row['state'] ?? 'new',
                'repetitions' => (int)($row['repetitions'] ?? 0),
                'lapses' => (int)($row['lapses'] ?? 0),
                'dueAt' => $row['due_at'],
            ];
        }, $queue->fetchAll());
        respond(200, [
            'method' => 'fsrs',
            'direction' => $direction,
            'stats' => array_map(static fn($value) => (int)$value, $stats->fetch()),
            'cards' => $cards,
        ]);
    }

    if ($method === 'POST' && str_ends_with($path, '/study/reviews')) {
        $body = request_body();
        $vocabularyId = (string)($body['vocabularyId'] ?? '');
        $rating = filter_var($body['rating'] ?? null, FILTER_VALIDATE_INT);
        if (preg_match('/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/', $vocabularyId) !== 1 || $rating === false || $rating < 1 || $rating > 4) {
            respond(422, ['error' => 'Vocabulary ID and an FSRS rating from 1 to 4 are required.']);
        }
        $pdo = database();
        $pdo->beginTransaction();
        try {
            $word = $pdo->prepare('SELECT id FROM vocabularies WHERE id = :word AND vocabulary_set_id = :set_id');
            $word->execute(['word' => strtolower($vocabularyId), 'set_id' => $setId]);
            if ($word->fetchColumn() === false) {
                $pdo->rollBack();
                respond(404, ['error' => 'Vocabulary not found.']);
            }
            $createProgress = $pdo->prepare(
                "INSERT IGNORE INTO learning_progress
                    (user_id, vocabulary_id, learning_method, direction, algorithm_version)
                 VALUES (:user_id, :vocabulary_id, 'fsrs', :direction, 'fsrs-4.5')"
            );
            $createProgress->execute(['user_id' => $userId, 'vocabulary_id' => strtolower($vocabularyId), 'direction' => $direction]);
            $lock = $pdo->prepare(
                "SELECT stability, difficulty, last_review_at, repetitions, lapses
                 FROM learning_progress WHERE user_id = :user_id AND vocabulary_id = :vocabulary_id
                   AND learning_method = 'fsrs' AND direction = :direction FOR UPDATE"
            );
            $lock->execute(['user_id' => $userId, 'vocabulary_id' => strtolower($vocabularyId), 'direction' => $direction]);
            $previous = $lock->fetch();
            $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
            $beforeStability = $previous['stability'] === null ? null : (float)$previous['stability'];
            $beforeDifficulty = $previous['difficulty'] === null ? null : (float)$previous['difficulty'];
            $schedule = fsrs_review($beforeStability, $beforeDifficulty, $previous['last_review_at'], $rating, $now);
            $reviewedAt = $now->format('Y-m-d H:i:s');
            $dueAt = $schedule['dueAt']->format('Y-m-d H:i:s');
            $update = $pdo->prepare(
                "UPDATE learning_progress SET algorithm_version = 'fsrs-4.5', state = 'review', stability = :stability,
                    difficulty = :difficulty, repetitions = repetitions + 1, lapses = lapses + :lapse,
                    last_review_at = :reviewed_at, due_at = :due_at
                 WHERE user_id = :user_id AND vocabulary_id = :vocabulary_id AND learning_method = 'fsrs' AND direction = :direction"
            );
            $update->execute([
                'stability' => $schedule['stability'], 'difficulty' => $schedule['difficulty'],
                'lapse' => $rating === 1 ? 1 : 0, 'reviewed_at' => $reviewedAt, 'due_at' => $dueAt,
                'user_id' => $userId, 'vocabulary_id' => strtolower($vocabularyId), 'direction' => $direction,
            ]);
            $event = $pdo->prepare(
                "INSERT INTO learning_review_events
                    (id, user_id, vocabulary_id, learning_method, direction, algorithm_version, rating, reviewed_at,
                     stability_before, stability_after, difficulty_before, difficulty_after, due_at)
                 VALUES (:id, :user_id, :vocabulary_id, 'fsrs', :direction, 'fsrs-4.5', :rating, :reviewed_at,
                     :stability_before, :stability_after, :difficulty_before, :difficulty_after, :due_at)"
            );
            $event->execute([
                'id' => uuid_v4(), 'user_id' => $userId, 'vocabulary_id' => strtolower($vocabularyId),
                'direction' => $direction, 'rating' => $rating, 'reviewed_at' => $reviewedAt,
                'stability_before' => $beforeStability, 'stability_after' => $schedule['stability'],
                'difficulty_before' => $beforeDifficulty, 'difficulty_after' => $schedule['difficulty'], 'due_at' => $dueAt,
            ]);
            $pdo->commit();
            respond(200, ['rating' => $rating, 'dueAt' => $dueAt, 'intervalDays' => $schedule['intervalDays']]);
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            error_log('FSRS review failed; the transaction was rolled back.');
            respond(500, ['error' => 'Could not save this review.']);
        }
    }
}

if ($method === 'GET' && preg_match('#^/api/v1/sets/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/statistics$#', $path, $matches) === 1) {
    $setId = strtolower($matches[1]);
    $direction = (string)($_GET['direction'] ?? '');
    $methodName = (string)($_GET['method'] ?? 'fsrs');
    if (!in_array($direction, ['foreign_to_local', 'local_to_foreign'], true) || $methodName !== 'fsrs') {
        respond(422, ['error' => 'Choose FSRS and a valid study direction.']);
    }
    $setQuery = database()->prepare('SELECT id FROM vocabulary_sets WHERE id = :id AND owner_user_id = :owner');
    $setQuery->execute(['id' => $setId, 'owner' => $userId]);
    if ($setQuery->fetchColumn() === false) {
        respond(404, ['error' => 'List not found.']);
    }

    $progress = database()->prepare(
        "SELECT COUNT(v.id) AS total,
                COALESCE(SUM(p.vocabulary_id IS NULL), 0) AS new_count,
                COALESCE(SUM(p.vocabulary_id IS NOT NULL AND p.due_at <= UTC_TIMESTAMP()), 0) AS due_count,
                COALESCE(SUM(p.repetitions > 0), 0) AS reviewed_count,
                COALESCE(SUM(p.repetitions), 0) AS repetitions,
                COALESCE(SUM(p.lapses), 0) AS lapses
         FROM vocabularies v
         LEFT JOIN learning_progress p ON p.vocabulary_id = v.id AND p.user_id = :user_id
            AND p.learning_method = :method AND p.direction = :direction
         WHERE v.vocabulary_set_id = :set_id"
    );
    $progress->execute(['user_id' => $userId, 'method' => $methodName, 'direction' => $direction, 'set_id' => $setId]);

    $reviews = database()->prepare(
        "SELECT COUNT(*) AS total,
                COALESCE(SUM(e.rating = 1), 0) AS again_count,
                COALESCE(SUM(e.rating = 2), 0) AS hard_count,
                COALESCE(SUM(e.rating = 3), 0) AS good_count,
                COALESCE(SUM(e.rating = 4), 0) AS easy_count,
                MIN(e.reviewed_at) AS first_review_at,
                MAX(e.reviewed_at) AS last_review_at
         FROM learning_review_events e
         JOIN vocabularies v ON v.id = e.vocabulary_id
         WHERE e.user_id = :user_id AND e.learning_method = :method AND e.direction = :direction
           AND v.vocabulary_set_id = :set_id"
    );
    $reviews->execute(['user_id' => $userId, 'method' => $methodName, 'direction' => $direction, 'set_id' => $setId]);

    $activity = database()->prepare(
        "SELECT DATE_FORMAT(e.reviewed_at, '%Y-%m-%d') AS day, COUNT(*) AS reviews,
                COALESCE(SUM(e.rating = 1), 0) AS again_count
         FROM learning_review_events e
         JOIN vocabularies v ON v.id = e.vocabulary_id
         WHERE e.user_id = :user_id AND e.learning_method = :method AND e.direction = :direction
           AND v.vocabulary_set_id = :set_id
           AND e.reviewed_at >= UTC_DATE() - INTERVAL 13 DAY
         GROUP BY DATE_FORMAT(e.reviewed_at, '%Y-%m-%d')
         ORDER BY day"
    );
    $activity->execute(['user_id' => $userId, 'method' => $methodName, 'direction' => $direction, 'set_id' => $setId]);

    respond(200, [
        'method' => $methodName,
        'direction' => $direction,
        'progress' => array_map(static fn($value) => is_numeric($value) ? (int)$value : $value, $progress->fetch()),
        'reviews' => array_map(static fn($value) => is_numeric($value) ? (int)$value : $value, $reviews->fetch()),
        'dailyActivity' => array_map(static fn(array $row): array => [
            'day' => $row['day'],
            'reviews' => (int)$row['reviews'],
            'againCount' => (int)$row['again_count'],
        ], $activity->fetchAll()),
    ]);
}

if (preg_match('#^/api/v1/sets/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/words$#', $path, $matches) === 1) {
    $setId = strtolower($matches[1]);
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
            'id' => $row['id'],
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
        $id = uuid_v4();
        $insert = database()->prepare(
            'INSERT INTO vocabularies (id, vocabulary_set_id, prompt, answer) VALUES (:id, :set_id, :prompt, :answer)'
        );
        $insert->execute(['id' => $id, 'set_id' => $setId, 'prompt' => $prompt, 'answer' => $answer]);
        respond(201, ['id' => $id, 'prompt' => $prompt, 'answer' => $answer]);
    }
}

respond(404, ['error' => 'Endpoint not found.']);
