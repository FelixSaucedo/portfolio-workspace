<?php
$path = '.env';
$env = file_get_contents($path);
if ($env === false) { throw new RuntimeException('No se pudo leer .env'); }
if (preg_match('/^APP_KEY=([^\r\n]*)/m', $env, $match) && trim($match[1], " \t\"'") !== '') {
    echo "APP_KEY existente conservada.\n";
    exit(0);
}
$key = 'APP_KEY=base64:' . base64_encode(random_bytes(32));
$env = preg_match('/^APP_KEY=.*$/m', $env)
    ? preg_replace('/^APP_KEY=.*$/m', $key, $env)
    : $env . "\n" . $key . "\n";
if (file_put_contents($path, $env) === false) { throw new RuntimeException('No se pudo escribir .env'); }
echo "APP_KEY generada.\n";
