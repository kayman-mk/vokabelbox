<?php
declare(strict_types=1);

$configPath = dirname(__DIR__, 2) . '/config.php';
if (!is_file($configPath)) {
    $configPath = dirname(__DIR__, 3) . '/config.php';
}
$config = require $configPath;
$database = $config['database'];
$admin = $config['development_account'];
$adminUsername = $admin['username'];
$adminPassword = $admin['password'];

if ($adminPassword === '') {
    fwrite(STDERR, "DEV_ADMIN_PASSWORD must not be empty.\n");
    exit(1);
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
    fwrite(STDOUT, "Created local development account '{$adminUsername}'.\n");
}
