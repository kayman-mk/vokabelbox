<?php
declare(strict_types=1);

require __DIR__ . '/../src/uuid.php';

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

$generated = [];
for ($index = 0; $index < 256; $index++) {
    $uuid = uuid_v4();
    check(
        preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/', $uuid) === 1,
        "UUID does not match RFC 4122 version 4 format: {$uuid}"
    );
    $generated[$uuid] = true;
}
check(count($generated) === 256, 'UUID generator returned duplicate values.');

fwrite(STDOUT, "UUID unit tests passed (256 unique RFC 4122 v4 values).\n");
