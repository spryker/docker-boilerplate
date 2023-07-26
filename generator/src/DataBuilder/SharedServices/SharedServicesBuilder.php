<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\SharedServices;

use DockerSdk\DataBuilder\AbstractBuilder;
use DockerSdk\DataBuilder\SharedServices\Plugins\SharedServicesPluginInterface;
use DockerSdk\DockerSdkConstants;
use DockerSdk\Helpers\ContainerNameBuilder;

class SharedServicesBuilder extends AbstractBuilder
{
    public function build(array $projectData): array
    {
        $projectSharedServiceData = $this->buildProjectSharedServiceData($projectData);
        $sharedServiceData = $this->buildSharedServicesData($projectSharedServiceData);

        $this->writer->write(
            $this->config->getDockerComposeSharedServiceDataFilePath(),
            $sharedServiceData
        );

        return $projectData;
    }

    private function buildProjectSharedServiceData(array $projectData): array
    {
        $result = [];

        $sharedServicesList = $this->config->getSharedServiceList();
        $projectServices = $projectData[DockerSdkConstants::SERVICES_KEY];

        foreach ($sharedServicesList as $sharedServiceName) {
            if (!array_key_exists($sharedServiceName, $projectServices)) {
                continue;
            }

            $sharedServiceData = $projectServices[$sharedServiceName];

            $sharedServiceData[DockerSdkConstants::DEPLOYMENT_PATH_KEY] = $this->config->getProjectDeploymentDir();
            $sharedServiceData[DockerSdkConstants::PROJECT_NAME_KEY] = $this->config->getInternalProjectName();

            foreach ($this->plugins as $plugin) {
                $sharedServiceData = $plugin->run(
                    $sharedServiceName,
                    $projectData,
                    $sharedServiceData
                );
            }
            $result[$sharedServiceName] = $sharedServiceData;
        }

        return $result;
    }

    private function buildSharedServicesData(array $projectSharedServicesData): array
    {
        $sharedServices = $this->reader->read(
            $this->config->getDockerComposeSharedServiceDataFilePath()
        );

        foreach ($projectSharedServicesData as $sharedServiceName => $projectSharedServiceData) {
            if (!array_key_exists($sharedServiceName, $sharedServices)) {
                $sharedServices[$sharedServiceName] = $projectSharedServiceData;

                continue;
            }

            $sharedServiceData = $sharedServices[$sharedServiceName];

            $endpoints = $this->buildEndpoints(
                $sharedServiceData,
                $projectSharedServiceData
            );

            foreach ($this->plugins as $plugin) {
                $sharedServiceData = $plugin->run(
                    $sharedServiceName,
                    $projectSharedServiceData,
                    $sharedServiceData
                );
            }

            if ($endpoints !== []) {
                $sharedServiceData[DockerSdkConstants::PROJECT_DATA_SERVICES_ENDPOINTS_KEY] = $endpoints;
            }

            $sharedServices[$sharedServiceName] = $sharedServiceData;
        }

        return $sharedServices;
    }

    private function buildEndpoints($externalSharedServiceData, $projectSharedServiceData): array
    {
//        todo: check tcp udp ports merge
        $externalServiceEndpoint = $externalSharedServiceData[DockerSdkConstants::PROJECT_DATA_SERVICES_ENDPOINTS_KEY] ?? [];
        $projectServiceEndpoint = $projectSharedServiceData[DockerSdkConstants::PROJECT_DATA_SERVICES_ENDPOINTS_KEY] ?? [];

        $endpoints = array_merge($externalServiceEndpoint, $projectServiceEndpoint);
        ksort($endpoints);

        return $endpoints;
    }

    /**
     *
     * @param SharedServicesPluginInterface[] $plugins
     *
     * @return $this
     */
    public function setPlugins(array $plugins): self
    {
        $this->plugins = $plugins;

        return $this;
    }
}
