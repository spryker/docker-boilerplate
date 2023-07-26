<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\DataBuilder;

use DockerSdk\DockerSdkConfig;

class AbstractPlugin implements PluginInterface
{
    protected const FUNCTION_KEY = 'function';

    /**
     * @var DockerSdkConfig
     */
    protected $config;

    /**
     * @param DockerSdkConfig $config
     */
    public function __construct(DockerSdkConfig $config)
    {
        $this->config = $config;
    }

    public function run(...$args): array
    {
        $methodName = debug_backtrace()[1][self::FUNCTION_KEY];

        return $this->{$methodName}(...$args);
    }
}
