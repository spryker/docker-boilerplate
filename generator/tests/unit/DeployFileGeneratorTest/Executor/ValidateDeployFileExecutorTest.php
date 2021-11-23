<?php
/**
 * This file is part of the Spryker Suite.
 * For full license information, please view the LICENSE file that was distributed with this source code.
 */

namespace Unit\DeployFileGenerator\Executor;

use Codeception\Test\Unit;
use DeployFileGenerator\Executor\ExecutorInterface;
use DeployFileGenerator\Executor\ValidateDeployFileExecutor;
use DeployFileGenerator\Transfer\DeployFileTransfer;
use DeployFileGenerator\Validator\ValidatorInterface;

class ValidateDeployFileExecutorTest extends Unit
{
    /**
     * @var \UnitTester
     */
    protected $tester;

    /**
     * @return void
     */
    public function testExecute()
    {
        $data = [
            'third-key' => 'some data',
            'first-key' => 'some data',
            'some-key' => 'some data',
            'second-key' => 'some data',
        ];

        $transfer = new DeployFileTransfer();
        $transfer = $transfer->setResultData($data);

        $transfer = $this->createValidateDeployFileExecutor()->execute($transfer);

        $this->tester->assertEquals(['key' => 'after validation data'], $transfer->getResultData());
    }

    /**
     * @return \DeployFileGenerator\Executor\ExecutorInterface
     */
    protected function createValidateDeployFileExecutor(): ExecutorInterface
    {
        return new ValidateDeployFileExecutor($this->makeEmpty(ValidatorInterface::class, [
            'validate' => function (DeployFileTransfer $deployFileTransfer) {
                return $deployFileTransfer->setResultData([
                    'key' => 'after validation data',
                ]);
            },
        ]));
    }
}
