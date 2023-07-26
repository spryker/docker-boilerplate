<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\Gateway\Plugins;

use DockerSdk\DataBuilder\AbstractPlugin;
use DockerSdk\DockerSdkConstants;

class LocalhostFilterPlugin extends AbstractPlugin implements GatewayPluginInterface
{
    public function build(array $gatewayData): array
    {
        $hosts = $gatewayData[DockerSdkConstants::HOSTS_KEY] ?? [];
        // todo: plugin
        $hosts = array_filter($hosts, function ($host) {
            return $host !== 'localhost';
        });

        $gatewayData[DockerSdkConstants::HOSTS_KEY] = $hosts;

        return $gatewayData;
    }
}
