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
    [
        'domain_suffix' => ['archiveofourown.org'],
        'outbound' => 'direct',
    ],
    [
        'domain' => ['ajax.googleapis.com'],
        'outbound' => 'direct',
    ],
    [
        'domain_regex' => ['.*'],
        'outbound' => 'block',
    ],
    [
        'ip_cidr' => ['0.0.0.0/0', '::/0'],
        'outbound' => 'block',
    ],
];

foreach (Server::whereIn('id', [1, 2])->get() as $server) {
    $server->route_ids = [];
    $server->custom_routes = $customRoutes;
    $server->save();
    echo json_encode([
        'server_id' => $server->id,
        'name' => $server->name,
        'route_ids' => $server->route_ids,
        'custom_routes' => $server->custom_routes,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), PHP_EOL;
}
