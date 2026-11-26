<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/config_loader.php';
$config = load_app_config();
$database = $config['database'];
$admin = $config['development_account'];
$adminUsername = $admin['username'];
$adminPassword = $admin['password'];

if (PHP_SAPI !== 'cli') {
    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: no-store');
    $host = parse_url('http://' . ($_SERVER['HTTP_HOST'] ?? ''), PHP_URL_HOST);
    $isLocalhost = in_array($host, ['localhost', '127.0.0.1', '::1'], true);
    $isHttps = ($_SERVER['HTTPS'] ?? '') !== '' && $_SERVER['HTTPS'] !== 'off';
    if (!$isHttps && !$isLocalhost) {
        http_response_code(400);
        exit('Run database setup over HTTPS.');
    }
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'GET') {
        echo '<!doctype html><html lang="en"><meta charset="utf-8"><title>Database setup</title>';
        echo '<h1>Database setup</h1><form method="post">';
        echo '<label>Configured admin password <input type="password" name="setup_password" required></label> ';
        echo '<button type="submit">Run setup</button></form></html>';
        exit;
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        http_response_code(405);
        header('Allow: GET, POST');
        exit('Method not allowed.');
    }
    $providedPassword = (string)($_POST['setup_password'] ?? '');
    if ($adminPassword === '' || !hash_equals($adminPassword, $providedPassword)) {
        http_response_code(403);
        exit('The configured admin password is incorrect.');
    }
} elseif ($adminPassword === '') {
    fwrite(STDERR, "DEV_ADMIN_PASSWORD must not be empty.\n");
    exit(1);
}

require __DIR__ . '/../vendor/autoload.php';
$migrationOutput = new Symfony\Component\Console\Output\BufferedOutput();
$phinx = new Phinx\Migration\Manager(
    new Phinx\Config\Config(require __DIR__ . '/../phinx.php'),
    new Symfony\Component\Console\Input\ArrayInput([]),
    $migrationOutput
);
try {
    $phinx->migrate('development');
} catch (Throwable $exception) {
    error_log('Database migration failed during initialization.');
    if (PHP_SAPI === 'cli') {
        fwrite(STDERR, "Database migration failed. Check the server error log.\n");
    } else {
        http_response_code(500);
        echo 'Database migration failed. Check the server error log.';
    }
    exit(1);
}
if (PHP_SAPI === 'cli') {
    fwrite(STDOUT, $migrationOutput->fetch());
}

require __DIR__ . '/../src/uuid.php';
$pdo = new PDO(
    sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $database['host'], $database['port'], $database['name']),
    $database['user'],
    $database['password'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$query = $pdo->prepare('SELECT id FROM users WHERE username = :username');
$query->execute(['username' => $adminUsername]);
if ($query->fetchColumn() === false) {
    $insert = $pdo->prepare('INSERT INTO users (id, username, password_hash) VALUES (:id, :username, :password_hash)');
    $insert->execute([
        'id' => uuid_v4(),
        'username' => $adminUsername,
        'password_hash' => password_hash($adminPassword, PASSWORD_DEFAULT),
    ]);
    if (PHP_SAPI === 'cli') {
        fwrite(STDOUT, "Created local development account '{$adminUsername}'.\n");
    }
}

if (PHP_SAPI !== 'cli') {
    echo 'Database setup completed. You can now sign in to VokabelBox.';
}
