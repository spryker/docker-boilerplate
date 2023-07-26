<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\ConstantBuilder;

use Exception;
use Twig\Environment;
use Twig\Error\LoaderError;
use Twig\Error\RuntimeError;
use Twig\Error\SyntaxError;
use Twig\Loader\ChainLoader;
use Twig\Loader\FilesystemLoader;

class DockerSdkBashConstantBuilder
{
    private const DOCKER_SDK_CONSTANTS_FILE_PATH = 'bin/standalone/constants.sh';
    private const DOCKER_SDK_CONSTANTS_PHP_PATH = '/data/src/Generated/DockerSdkBashConstants.php';

    private const TEMPLATE_DIRECTORY_PATH = APPLICATION_SOURCE_DIR .'/ConstantBuilder/template';
    private const TEMPLATE_NAME = 'DockerSdkBashConstants.php.twig';

    private const VALUE_KEY = 'value';
    private const TYPE_KEY = 'type';
    private const DATA_KEY = 'data';

    /**
     * @var string
     */
    private $deploymentPath;
    /**
     * @var array
     */
    private $environmentVariables;
    /**
     * @var array
     */
    private $constantNameListForDelete = [
        'TRUE',
        'FALSE',
    ];

    /**
     * @param string $deploymentPath
     * @param array $environmentVariables
     */
    public function __construct(string $deploymentPath, array $environmentVariables = [])
    {
        $this->deploymentPath = $deploymentPath;
        $this->environmentVariables = $environmentVariables;
    }

    /**
     * @return array
     * @throws RuntimeError
     * @throws SyntaxError
     * @throws LoaderError
     */
    public function buildDockerSdkConstants(): void
    {
        $data = $this->getDockerSdkBashConstants();
        $data = $this->addRequiredEnvVariables($data);
        $data = $this->addMetaData($data);

        $renderData = $this->getTwig()->render(
            self::TEMPLATE_NAME, [
                self::DATA_KEY => $data
            ]);

        file_put_contents(self::DOCKER_SDK_CONSTANTS_PHP_PATH, $renderData);
    }

    private function getDockerSdkConstantsFilePath(): string
    {
        return $this->deploymentPath
            . DIRECTORY_SEPARATOR
            . self::DOCKER_SDK_CONSTANTS_FILE_PATH;
    }

    private function removeBashArtifacts(array $data): array
    {
        $data = array_filter($data);

        return array_filter($data, function ($value) {
            return $value[0] !== '#';
        });
    }

    private function normalizeArray(array $data): array
    {
        $result = [];

        foreach ($data as $value) {
            $key = $this->buildKey($value);
            $value = $this->buildValue($value);

            $result[$key] = $value;
        }

        return $result;
    }

    private function buildKey($value): string
    {
        $value = explode('=', $value);
        $key = explode(' ', $value[0]);

        return $key[1] ?? $key[0];
    }

    private function buildValue($value)
    {
        $value = explode('=', $value);
        $value = $this->trimBashQuotes($value[1]);

        if ($this->IsValueBashArray($value)) {
            $value = trim($value, '()');
            $value = explode(' ', $value);
            $value = array_map(function ($item) {
                return $this->trimBashQuotes($item);
            }, $value);
        }

        return $value;
    }

    private function IsValueBashArray(string $value): bool
    {
        return $value[0] == '(' && $value[strlen($value) - 1] == ')';
    }

    private function trimBashQuotes(string $value): string
    {
        return trim($value, '\'');
    }

    private function cleanUp(array $data): array
    {
        foreach ($this->constantNameListForDelete as $constantName) {
            if (!array_key_exists($constantName, $data)) {
                continue;
            }

            unset($data[$constantName]);
        }

        return $data;
    }

    private function addMetaData(array $data): array
    {
        $result = [];

        foreach ($data as $constantName => $constantValue) {
            $type = gettype($constantValue);

            if (is_string($constantValue)) {
                $constantValue = '\'' . $constantValue . '\'';
            }

            $result[$constantName] = [
                self::VALUE_KEY =>  $constantValue,
                self::TYPE_KEY => $type
            ];
        }

        ksort($result);

        return $result;
    }

    private function getTwig(): Environment
    {
        return new Environment(
            new ChainLoader([
                new FilesystemLoader(self::TEMPLATE_DIRECTORY_PATH)
            ]));
    }

    private function getDockerSdkBashConstants(): array
    {
        $data = file_get_contents($this->getDockerSdkConstantsFilePath());
        $data = explode(PHP_EOL, $data);
        $data = $this->removeBashArtifacts($data);
        $data = $this->normalizeArray($data);

        return $this->cleanUp($data);
    }

    private function addRequiredEnvVariables(array $data): array
    {
        foreach ($this->environmentVariables as $dockerSdkEnvVariableName) {
            $value = getenv($dockerSdkEnvVariableName);

            if ($value === false) {
                throw new Exception('Variable: `' . $dockerSdkEnvVariableName . '` should be init.');
            }

            $data[$dockerSdkEnvVariableName] = $value;
        }

        return $data;
    }
}
