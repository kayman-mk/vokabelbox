<?php
declare(strict_types=1);

$config = require __DIR__ . '/config.php';
$database = $config['database'];

return [
    'paths' => [
        'migrations' => __DIR__ . '/db/migrations',
    ],
    'environments' => [
        'default_migration_table' => 'phinxlog',
        'default_environment' => 'development',
        'development' => [
            'adapter' => 'mysql',
            'host' => $database['host'],
            'name' => $database['name'],
            'user' => $database['user'],
            'pass' => $database['password'],
            'port' => $database['port'],
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_0900_ai_ci',
        ],
    ],
    'version_order' => 'creation',
];
