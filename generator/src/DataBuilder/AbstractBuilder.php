<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder;

use DockerSdk\DockerSdkConfig;
use DockerSdk\Reader\ReaderInterface;
use DockerSdk\Writer\WriterInterface;

abstract class AbstractBuilder implements BuilderInterface
{
    /**
     * @var ReaderInterface
     */
    protected $reader;
    /**
     * @var WriterInterface
     */
    protected $writer;
    /**
     * @var DockerSdkConfig
     */
    protected $config;
    /**
     * @var PluginInterface[]
     */
    protected $plugins;

    public function __construct(ReaderInterface $reader, WriterInterface $writer, DockerSdkConfig $config, array $plugins = [])
    {
        $this->reader = $reader;
        $this->writer = $writer;
        $this->config = $config;
        $this->plugins = $plugins;
    }
}
