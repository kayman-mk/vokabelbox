<?php
declare(strict_types=1);

$host = getenv('DB_HOST') ?: 'db';
$database = getenv('DB_NAME') ?: 'vokabelbox';
$username = getenv('DB_USER') ?: 'vokabelbox';
$password = getenv('DB_PASSWORD') ?: '';
$adminUsername = getenv('DEV_ADMIN_USERNAME') ?: 'admin';
$adminPassword = getenv('DEV_ADMIN_PASSWORD') ?: '';

if ($adminPassword === '') {
    fwrite(STDERR, "DEV_ADMIN_PASSWORD must not be empty.\n");
    exit(1);
}

$pdo = null;
for ($attempt = 1; $attempt <= 30; $attempt++) {
    try {
        $pdo = new PDO(
            "mysql:host={$host};dbname={$database};charset=utf8mb4",
            $username,
            $password,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
        );
        break;
    } catch (PDOException $exception) {
        if ($attempt === 30) {
            fwrite(STDERR, "Could not connect to the database after 30 attempts. Check the Compose environment.\n");
            exit(1);
        }
        sleep(2);
    }
}

$schema = file_get_contents(__DIR__ . '/../schema.sql');
if ($schema === false) {
    fwrite(STDERR, "Could not read the database schema.\n");
    exit(1);
}
foreach (array_filter(array_map('trim', explode(';', $schema))) as $statement) {
    $pdo->exec($statement);
}

$query = $pdo->prepare('SELECT id FROM users WHERE username = :username');
$query->execute(['username' => $adminUsername]);
if ($query->fetchColumn() === false) {
    $insert = $pdo->prepare('INSERT INTO users (username, password_hash) VALUES (:username, :password_hash)');
    $insert->execute([
        'username' => $adminUsername,
        'password_hash' => password_hash($adminPassword, PASSWORD_DEFAULT),
    ]);
    fwrite(STDOUT, "Created local development account '{$adminUsername}'.\n");
}
