<?php
declare(strict_types=1);

$initializer = __DIR__ . '/api/v1/bin/init.php';
if (!is_file($initializer)) {
    $initializer = __DIR__ . '/backend/bin/init.php';
}

require $initializer;
