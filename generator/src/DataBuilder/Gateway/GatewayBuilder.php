<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\Gateway;

use DockerSdk\DataBuilder\AbstractBuilder;
use DockerSdk\DockerSdkConstants;

class GatewayBuilder extends AbstractBuilder
{
    public function build(array $projectData): array
    {
        $gatewayData = $this->buildGatewayData($projectData);

        $this->writer->write(
            $this->config->getGatewayDataFilePath(),
            $gatewayData
        );

        return $projectData;
    }

    private function buildGatewayData(array $projectData): array
    {
        $projectHosts = $projectData[DockerSdkConstants::PROJECT_DATA_HOSTS_KEY] ?? [];
        $projectPorts = $projectData[DockerSdkConstants::PROJECT_DATA_PORTS_KEY] ?? [];

        $gatewayData = $this->reader->read($this->config->getGatewayDataFilePath());

        $hosts = array_merge($projectHosts, $gatewayData[DockerSdkConstants::HOSTS_KEY] ?? []);
        $ports = array_merge($projectPorts, $gatewayData[DockerSdkConstants::GATEWAY_PORTS_KEY] ?? []);
// todo: plugin
        $hosts = array_filter($hosts, function ($host) {
            return $host !== 'localhost';
        });

        $hosts = array_unique($hosts);
        $ports = array_unique($ports);
        sort($hosts);
        sort($ports);

        return [
            DockerSdkConstants::HOSTS_KEY => $hosts,
            DockerSdkConstants::GATEWAY_PORTS_KEY => $ports,
        ];
    }
}
