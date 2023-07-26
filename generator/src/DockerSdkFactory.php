<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk;

use DockerSdk\DataBuilder\BuilderInterface;
use DockerSdk\DataBuilder\Gateway\GatewayBuilder;
use DockerSdk\DataBuilder\Gateway\Plugins\LocalhostFilterPlugin;
use DockerSdk\DataBuilder\ProjectData\ProjectBuilder;
use DockerSdk\DataBuilder\Redis\RedisDataBuilder;
use DockerSdk\DataBuilder\SharedServices\Plugins\RedisGuiPlugin;
use DockerSdk\DataBuilder\SharedServices\SharedServicesBuilder;
use DockerSdk\DataBuilder\Sync\MutagenBuilder;
use DockerSdk\ComposeRender\GatewayRender;
use DockerSdk\ComposeRender\MutagenRender;
use DockerSdk\ComposeRender\ProjectRender;
use DockerSdk\ComposeRender\SharedServicesRender;
use DockerSdk\Reader\JsonReader;
use DockerSdk\Reader\ReaderInterface;
use DockerSdk\Writer\JsonWriter;
use DockerSdk\Writer\WriterInterface;
use Twig\Environment;
use Twig\Loader\ChainLoader;
use Twig\Loader\FilesystemLoader;

class DockerSdkFactory
{
    /**
     * @var string
     */
    private $deploymentPath;

    /**
     * @param string $deploymentPath
     */
    public function __construct(string $deploymentPath)
    {
        $this->deploymentPath = $deploymentPath;
    }

    public function getDockerSdkConfig(): DockerSdkConfig
    {
        return new DockerSdkConfig();
    }

    public function createSharedServicesBuilder(): BuilderInterface
    {
        return new SharedServicesBuilder(
            $this->createJsonReader(),
            $this->createJsonWriter(),
            $this->getDockerSdkConfig(),
            [
                new RedisGuiPlugin($this->getDockerSdkConfig()),
            ]
        );
    }

    public function createMutagenBuilder(): BuilderInterface
    {
        return new MutagenBuilder(
            $this->createJsonReader(),
            $this->createJsonWriter(),
            $this->getDockerSdkConfig()
        );
    }

    public function createGatewayBuilder(): BuilderInterface
    {
        return new GatewayBuilder(
            $this->createJsonReader(),
            $this->createJsonWriter(),
            $this->getDockerSdkConfig(),
            [
                new LocalhostFilterPlugin($this->getDockerSdkConfig()),
            ]
        );
    }

    public function createProjectDataBuilder(): BuilderInterface
    {
        return new ProjectBuilder(
            $this->createJsonReader(),
            $this->createJsonWriter(),
            $this->getDockerSdkConfig()
        );
    }

    public function createRedisDataBuilderBuilder(): BuilderInterface
    {
        return new RedisDataBuilder(
            $this->createJsonReader(),
            $this->createJsonWriter(),
            $this->getDockerSdkConfig()
        );
    }

    public function createJsonReader(): ReaderInterface
    {
        return new JsonReader();
    }

    public function createJsonWriter(): WriterInterface
    {
        return new JsonWriter();
    }

    /**
     * @return Environment
     */
    public function getCreateTwig(): Environment
    {
        $loaders = new ChainLoader([
            new FilesystemLoader(APPLICATION_SOURCE_DIR . DS . 'templates'),
            new FilesystemLoader($this->deploymentPath),
        ]);

        return new Environment($loaders);
    }
}
