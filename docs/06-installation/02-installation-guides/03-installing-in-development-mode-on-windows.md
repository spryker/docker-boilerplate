# Installing in Development mode on Windows


This document describes how to install Spryker in [Development Mode](01-choosing-an-installation-mode.md#development-mode) on Windows.

## Installing Docker prerequisites on Windows

To install Docker prerequisites for Windows, follow [Installing Docker prerequisites on Windows](../01-installation-prerequisites/03-installing-docker-prerequisites-on-windows.md).




## Installing Spryker in Development mode on Windows
Follow the steps to install Spryker in Development mode:

1. Open Ubuntu.
2. Open a terminal.
3. Create a new folder and navigate into it.
4. Depending on the desired [Demo Shop](https://documentation.spryker.com/docs/en/about-spryker#spryker-b2b-b2c-demo-shops):

    a. Clone the B2C repository:

    ```bash
    git clone https://github.com/spryker-shop/b2c-demo-shop.git -b 202009.0-p1 --single-branch ./b2c-demo-shop
    ```

    b. Clone the B2B repository:

    ```bash
    git clone https://github.com/spryker-shop/b2b-demo-shop.git -b 202009.0-p1 --single-branch ./b2b-demo-shop
    ```

5. Depending on the repository you've cloned, navigate into the cloned folder:
    * B2C repository:
    ```bash
    cd b2c-demo-shop
    ```
    * B2B repository:
    ```bash
    cd b2b-demo-shop
    ```
:::(Warning) (Verification)
Make sure that you are in the correct folder by running the `pwd` command.
:::

6. In `deploy.dev.yml`, define `image:` with the PHP image compatible with the current release of the Demo Shop:

```yaml
image: spryker/php:7.4-alpine3.16
```

7. Clone the Docker SDK repository:
```bash
git clone https://github.com/spryker/docker-sdk.git --single-branch docker
```

:::(Warning) (Verification)
Make sure `docker 18.09.1+` and `docker compose 2+` are installed:

```bash
$ docker version
$ docker compose version
```
:::

8. In `deploy.dev.yml`, set the debug configuration as follows:

```yaml
docker:
  ...
  debug:
    enabled: true
    xdebug:
      enabled: true
      custom_host_ip: host.docker.internal
  ...
```

9. Add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
```

10. Bootstrap local docker setup:
```bash
docker/sdk bootstrap deploy.dev.yml
```
:::(Warning) (Bootstrap)
Once you finish the setup, you don't need to run `bootstrap` to start the instance. You only need to run it after you update the Docker SDK or the deploy file.
:::

11. Update the `hosts` file:
    1. Open the Start menu.
    2. In the search field, enter `Notepad`.
    3. Right-click *Notepad* and select **Run as administrator**.
    4. In the *User Account Control* window, select **Yes** to confirm the action.
    5. In the upper navigation panel, select **File** > **Open**.
    6. Put the following path into the address line: `C:\Windows\System32\drivers\etc`.
    7. In the **File name** line, enter `hosts` and select **Open**.
    The hosts file opens in the drop-down.
    8. Follow the installation instructions in the white box from the `docker/sdk bootstrap` command execution results to prepare the environment.
    :::(Info) ()
    You can run `docker/sdk install` after `bootstrap` to get the list of the instructions.
    :::
    9. Select **File** > **Save**.
    10. Close the file.

12. Once the job finishes, build and start the instance:

```bash
docker/sdk up
```

:::(Warning) ()
Depending on the hardware performance, the first project launch can take up to 20 minutes.
:::

## Endpoints

To ensure that the installation is successful, make sure you can access the configured endpoints from the Deploy file. See [Deploy file reference - 1.0](../../07-deploy-file/02-deploy.file.reference.v1.md) to learn about the Deploy file.

:::(Info) (RabbitMQ UI credentials)
To access RabbitMQ UI, use `spryker` as a username and `secret` as a password. You can adjust the credentials in `deploy.yml`.
:::

## Getting the list of useful commands

To get the full and up-to-date list of commands, run `docker/sdk help`.

## Next steps

* [Troubleshooting](../../09-troubleshooting.md)
* [Configuring debugging](../../02-development/05-configuring-debugging.md)
* [Deploy file reference - 1.0](../../07-deploy-file/02-deploy.file.reference.v1.md)
* [Configuring services](../../06-configuring-services.md)
* [Setting up a self-signed SSL certificate](https://documentation.spryker.com/docs/setting-up-a-self-signed-ssl-certificate)
* [Additional DevOPS guidelines](https://documentation.spryker.com/docs/additional-devops-guidelines)
