<?php

use Castor\Attribute\AsContext;
use Castor\Attribute\AsTask;
use Castor\Context;

use function Castor\import;
use function Castor\variable;
use function Castor\wait_for_docker_container;

#[AsContext(name: 'my_context', default: true)]
function my_context(): Context
{
    return new Context(environment: ['STACK_NAME' => 'starter']);
}

#[AsTask('wait-php-container')]
function waitPhpContainer(): void
{
    wait_for_docker_container(
        containerName: variable('STACK_NAME') . '_php',
        message: 'Waiting for PHP container to be ready...',
    );
}

#[AsTask('wait-db-container')]
function waitDbContainer(): void
{
    wait_for_docker_container(
        containerName: variable('STACK_NAME') . '_db',
        message: 'Waiting for DB container to be ready...',
    );
}

import('make/castor_entrypoint.php');