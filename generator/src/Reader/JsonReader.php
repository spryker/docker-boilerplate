<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\Reader;

class JsonReader implements ReaderInterface
{
    public function read(string $filepath): array
    {
        if (!file_exists($filepath)) {
            return [];
        }

        $data = file_get_contents($filepath);

        if ($data == '') {
            return [];
        }

        return json_decode($data, true);
    }
}
