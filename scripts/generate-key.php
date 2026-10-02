<?php

declare(strict_types=1);

$environmentFile = '.env';
$environmentContents = file_get_contents($environmentFile);
if ($environmentContents === false) {
    throw new RuntimeException('No se pudo leer .env');
}
if (preg_match('/^APP_KEY=([^\r\n]*)/m', $environmentContents, $existingKey) && trim($existingKey[1], " \t\"'") !== '') {
    exit(0);
}
$applicationKeyAssignment = 'APP_KEY=base64:' . base64_encode(random_bytes(32));
$environmentContents = preg_match('/^APP_KEY=.*$/m', $environmentContents)
    ? preg_replace('/^APP_KEY=.*$/m', $applicationKeyAssignment, $environmentContents)
    : $environmentContents . "\n" . $applicationKeyAssignment . "\n";
if (file_put_contents($environmentFile, $environmentContents) === false) {
    throw new RuntimeException('No se pudo escribir .env');
}
