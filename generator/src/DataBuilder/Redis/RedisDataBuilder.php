<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\Redis;

use DockerSdk\DataBuilder\AbstractBuilder;
use DockerSdk\DockerSdkConstants;
use Exception;
use Illuminate\Support\Arr;

class RedisDataBuilder extends AbstractBuilder
{
    public function build(array $projectData): array
    {
        $redisData = $this->reader->read(
            $this->config->getRedisDataFilePath()
        );

        $projectRedisData = $this->getProjectRedisData($projectData);

        $this->validate($projectRedisData, $redisData);

        $redisData[$this->config->getSprykerProjectName()] = $projectRedisData;

        $this->writer->write(
            $this->config->getRedisDataFilePath(),
            $redisData
        );

        return $projectData;
    }

    private function getProjectRedisData(array $projectData): array
    {
//        todo: constants
        $regions = $projectData[DockerSdkConstants::PROJECT_DATA_REGIONS_KEY];
        $groups = $projectData[DockerSdkConstants::PROJECT_DATA_GROUPS_KEY];

        $regionsData = data_get(
            $regions,
            '*.'
            . DockerSdkConstants::PROJECT_DATA_REGIONS_STORES_KEY
            . '.*.'
            . DockerSdkConstants::SERVICES_KEY
            . '.key_value_store.namespace'
        );

        $groupsData = data_get(
            $groups,
            '*.'
            . DockerSdkConstants::PROJECT_DATA_GROUPS_APPLICATIONS_KEY
            . '.*.endpoints.*.services.session.namespace'
        );

        return array_unique(array_merge($regionsData, array_filter($groupsData)));
    }

    private function validate(array $projectRedisData, array $redisData): void
    {
        $errorTemplate = 'Redis db should be unique.'
            . PHP_EOL
            .'Please change next indexes: %s'
            . PHP_EOL
            . 'List of defined indexes: %s'
            . PHP_EOL;

        unset($redisData[$this->config->getSprykerProjectName()]);

        $regionsData = data_get($redisData, '*');
        $regionsData = Arr::collapse($regionsData);

        $result = array_intersect(
            $projectRedisData,
            $regionsData,
        );

        sort($result);
        sort($regionsData);

        if ($result !== []) {
            throw new Exception(
                sprintf($errorTemplate, implode(', ', $result), implode(', ', $regionsData))
            );
        }

    }
}
