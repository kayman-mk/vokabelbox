<?php
declare(strict_types=1);

return [
    'database' => [
        'host' => getenv('DB_HOST') ?: 'db',
        'name' => getenv('DB_NAME') ?: 'vokabelbox',
        'user' => getenv('DB_USER') ?: 'vokabelbox',
        'password' => getenv('DB_PASSWORD') ?: '',
        'port' => (int)(getenv('DB_PORT') ?: 3306),
    ],
    'development_account' => [
        'username' => getenv('DEV_ADMIN_USERNAME') ?: 'admin',
        'password' => getenv('DEV_ADMIN_PASSWORD') ?: '',
    ],
];
