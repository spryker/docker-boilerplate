<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\Writer;

class JsonWriter implements WriterInterface
{
    public function write(string $filepath, array $data): void
    {
        file_put_contents(
            $filepath,
            json_encode($data, JSON_PRETTY_PRINT)
        );
    }
}
