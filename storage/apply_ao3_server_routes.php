<?php

require '/www/vendor/autoload.php';

$app = require '/www/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\Server;
use App\Models\ServerRoute;

$defs = [
    [
        'remarks' => 'AO3 allow suffix',
        'match' => ['archiveofourown.org'],
        'action' => 'direct',
        'action_value' => null,
    ],
    [
        'remarks' => 'AO3 allow ajax googleapis',
        'match' => ['ajax.googleapis.com'],
        'action' => 'direct',
        'action_value' => null,
    ],
    [
        'remarks' => 'AO3 block all ipv4',
        'match' => ['0.0.0.0/0'],
        'action' => 'block',
        'action_value' => null,
    ],
    [
        'remarks' => 'AO3 block all ipv6',
        'match' => ['::/0'],
        'action' => 'block',
        'action_value' => null,
    ],
];

$routeIds = [];

foreach ($defs as $def) {
    $route = ServerRoute::firstOrNew(['remarks' => $def['remarks']]);
    $route->match = $def['match'];
    $route->action = $def['action'];
    $route->action_value = $def['action_value'];
    $route->save();
    $routeIds[] = $route->id;
}

foreach (Server::whereIn('id', [1, 2])->get() as $server) {
    $server->route_ids = $routeIds;
    $server->save();
    echo json_encode([
        'server_id' => $server->id,
        'name' => $server->name,
        'route_ids' => $server->route_ids,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), PHP_EOL;
}

foreach (ServerRoute::whereIn('id', $routeIds)->orderBy('id')->get() as $route) {
    echo json_encode($route->toArray(), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), PHP_EOL;
}
