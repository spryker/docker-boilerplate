<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\Gateway\Plugins;

interface GatewayPluginInterface
{
    public function build(array $gatewayData): array;
}
