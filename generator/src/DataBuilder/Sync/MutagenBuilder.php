<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder\Sync;

use DockerSdk\DataBuilder\AbstractBuilder;
use DockerSdk\DockerSdkConstants;

class MutagenBuilder extends AbstractBuilder
{
    private const MUTAGEN_KEY = 'mutagen';

    public function build(array $projectData): array
    {
        $mutagenData = $this->buildMutagenData($projectData);

        $this->writer->write(
            $this->config->getDockerComposeSyncDataFilePath(),
            $mutagenData
        );

        return $projectData;
    }

    private function buildMutagenData(array $projectData): array
    {
        $projectName = $this->config->getSprykerProjectName();
        $projectPath = $this->config->getSprykerProjectPath();

        $mutagenData = $this->reader->read($this->config->getDockerComposeSyncDataFilePath());
        $mutagenSyncIgnore = $mutagenData[DockerSdkConstants::MUTAGEN_DATA_SYNC_IGNORE_KEY] ?? [];
        $mutagenSyncIgnore = array_merge($mutagenSyncIgnore, $projectData[DockerSdkConstants::PROJECT_DATA_SYNC_IGNORE_KEY] ?? []);

        $mutagenProjectsData = $mutagenData[DockerSdkConstants::MUTAGEN_DATA_PROJECTS_KEY] ?? [];

        if (!array_key_exists($projectName, $mutagenProjectsData)) {
            $mutagenProjectsData[$projectName] = [
                DockerSdkConstants::PROJECT_NAME_KEY => $projectName,
                DockerSdkConstants::MUTAGEN_DATA_PROJECT_PATH_KEY => $projectPath,
            ];
        }

        if ($projectData[DockerSdkConstants::PROJECT_DATA_MOUNT_MODE_KEY] != self::MUTAGEN_KEY) {
            unset($mutagenProjectsData[$projectName]);
        }

        $mutagenData[DockerSdkConstants::MUTAGEN_DATA_PROJECTS_KEY] = $mutagenProjectsData;
        $mutagenData[DockerSdkConstants::MUTAGEN_DATA_SYNC_IGNORE_KEY] = $mutagenSyncIgnore;

        return $mutagenData;
    }
}
