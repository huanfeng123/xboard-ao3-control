<?php

require '/www/vendor/autoload.php';

$app = require '/www/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\Server;

$customRoutes = [
    [
        'port' => [53, 853],
        'outbound' => 'direct',
    ],
];

foreach (Server::whereIn('id', [1, 2])->get() as $server) {
    $server->custom_routes = $customRoutes;
    $server->save();
    echo json_encode([
        'server_id' => $server->id,
        'name' => $server->name,
        'custom_routes' => $server->custom_routes,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), PHP_EOL;
}
