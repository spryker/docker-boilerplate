<?php

/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace DockerSdk\Reader;

interface ReaderInterface
{
    public function read(string $filepath): array;
}
