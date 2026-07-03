<?php

use Castor\Attribute\AsContext;
use Castor\Attribute\AsTask;
use Castor\Context;

use function Castor\context;
use function Castor\import;
use function Castor\io;
use function Castor\wait_for_docker_container;

#[AsContext(name: 'my_context', default: true)]
function my_context(): Context
{
    return new Context(environment: ['STACK_NAME' => 'starter']);
}

#[AsTask('wait-php-container')]
function waitPhpContainer(): void
{
    $stackName = context()->environment['STACK_NAME'];
    $containerName = "{$stackName}_php";

    wait_for_docker_container(
        containerName: $containerName,
        message: "Waiting for {$containerName} to be ready...",
    );

    io()->success('PHP container is ready!');
}

#[AsTask('wait-db-container')]
function waitDbContainer(): void
{
    $stackName = context()->environment['STACK_NAME'];
    $containerName = "{$stackName}_db";

    wait_for_docker_container(
        containerName: $containerName,
        message: "Waiting for {$containerName} to be ready...",
    );

    io()->success('DB container is ready!');
}

import('make/castor_entrypoint.php');
