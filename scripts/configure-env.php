<?php
$values = [
    'DB_CONNECTION' => 'mysql', 'DB_HOST' => 'db', 'DB_PORT' => '3306',
    'DB_DATABASE' => 'portfolio_db', 'DB_USERNAME' => 'portfolio_user',
    'DB_PASSWORD' => 'portfolio_secret',
];
foreach (['.env.example', '.env'] as $file) {
    if (!is_file($file)) {
        if ($file === '.env' && !copy('.env.example', '.env')) {
            throw new RuntimeException('No se pudo crear .env');
        }
        if (!is_file($file)) { throw new RuntimeException("Falta $file"); }
    }
    $env = file_get_contents($file);
    if ($env === false) { throw new RuntimeException("No se pudo leer $file"); }
    foreach ($values as $key => $value) {
        $pattern = '/^[ \t]*#?[ \t]*' . preg_quote($key, '/') . '=[^\r\n]*\r?$/m';
        $line = "$key=$value";
        $env = preg_match($pattern, $env)
            ? preg_replace($pattern, $line, $env)
            : rtrim($env) . "\n$line\n";
    }
    if (file_put_contents($file, $env) === false) {
        throw new RuntimeException("No se pudo escribir $file");
    }
}
echo "Configuracion MySQL aplicada.\n";
