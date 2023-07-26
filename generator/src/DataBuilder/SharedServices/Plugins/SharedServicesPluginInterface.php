<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\SharedServices\Plugins;

use DockerSdk\DataBuilder\PluginInterface;

interface SharedServicesPluginInterface
{
    public function buildProjectSharedServiceData(
        string $serviceName,
        array $projectServiceData,
        array $sharedServiceData
    ): array;

    public function buildSharedServicesData(
        string $serviceName,
        array $projectServiceData,
        array $sharedServiceData
    ): array;
}
