<?php
declare(strict_types=1);

function load_app_config(): array
{
    $directory = __DIR__;
    while (true) {
        $configPath = $directory . '/config.php';
        if (is_file($configPath)) {
            return require $configPath;
        }

        $parent = dirname($directory);
        if ($parent === $directory) {
            break;
        }
        $directory = $parent;
    }

    throw new RuntimeException('Could not locate config.php in a parent directory.');
}
