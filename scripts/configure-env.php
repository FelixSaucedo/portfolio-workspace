<?php

declare(strict_types=1);

$databaseSettings = [
    'DB_CONNECTION' => 'mysql', 'DB_HOST' => 'db', 'DB_PORT' => '3306',
    'DB_DATABASE' => 'portfolio_db', 'DB_USERNAME' => 'portfolio_user',
    'DB_PASSWORD' => 'portfolio_secret',
];
foreach (['.env.example', '.env'] as $environmentFile) {
    if (!is_file($environmentFile)) {
        if ($environmentFile === '.env.example') {
            throw new RuntimeException("Falta $environmentFile");
        }
        if (!copy('.env.example', '.env')) {
            throw new RuntimeException('No se pudo crear .env');
        }
    }
    $environmentContents = file_get_contents($environmentFile);
    if ($environmentContents === false) {
        throw new RuntimeException("No se pudo leer $environmentFile");
    }
    foreach ($databaseSettings as $variableName => $variableValue) {
        $assignmentPattern = '/^[ \t]*#?[ \t]*' . preg_quote($variableName, '/') . '=[^\r\n]*\r?$/m';
        $assignment = "$variableName=$variableValue";
        $environmentContents = preg_match($assignmentPattern, $environmentContents)
            ? preg_replace($assignmentPattern, $assignment, $environmentContents)
            : rtrim($environmentContents) . "\n$assignment\n";
    }
    if (file_put_contents($environmentFile, $environmentContents) === false) {
        throw new RuntimeException("No se pudo escribir $environmentFile");
    }
}
