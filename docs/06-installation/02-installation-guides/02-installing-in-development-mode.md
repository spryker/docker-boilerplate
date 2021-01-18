This document describes how to install Spryker in [Development Mode](01-choosing-an-installation-mode.md#development-mode).

## Installing Docker prerequisites

To install Docker prerequisites, follow one of the guides:
* [Installing Docker prerequisites on MacOS](../01-installation-prerequisites/01-installing-docker-prerequisites-on-macos.md)
* [Installing Docker prerequisites on Linux](../01-installation-prerequisites/01-installing-docker-prerequisites-on-linux.md)
* [Installing Docker prerequisites on Windows](../01-installation-prerequisites/01-installing-docker-prerequisites-on-windows.md)




## Installing Spryker in Development mode
Follow the steps to install Spryker in Development mode:

1. Windows: Open Ubuntu.
2. Open a terminal.
3. Create a new folder and navigate into it.
4. Depending on the desired [Demo Shop](https://documentation.spryker.com/docs/en/about-spryker#spryker-b2b-b2c-demo-shops):

    a. Clone the B2C repository:

    ```bash
    git clone https://github.com/spryker-shop/b2c-demo-shop.git -b 202009.0 --single-branch ./
    ```

    b. Clone the B2B repository:

    ```bash
    git clone https://github.com/spryker-shop/b2b-demo-shop.git -b 202009.0 --single-branch ./
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
image: spryker/php:7.3-alpine3.12
```

7. Clone the Docker SDK repository:
```bash
git clone https://github.com/spryker/docker-sdk.git --single-branch docker
```

:::(Warning) (Verification)
Make sure `docker 18.09.1+` and `docker-compose 1.23+` are installed:

```bash
$ docker version
$ docker-compose --version
```
:::

8. Windows: In Ubuntu, change line 7 of `{shop_name}/docker/context/php/debug/etc/php/debug.conf.d/69-xdebug.ini` to the following:

```text
xdebug.remote_host=host.docker.internal
```

9. Windows: Add your user to the `docker` group:

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

11. Once the job finishes, build and start the instance:
```bash
docker/sdk up
```

12. Update the `hosts` file:

  - Linux/MacOS:				
```bash
echo "127.0.0.1 zed.de.spryker.local yves.de.spryker.local glue.de.spryker.local zed.at.spryker.local yves.at.spryker.local glue.at.spryker.local zed.us.spryker.local yves.us.spryker.local glue.us.spryker.local mail.spryker.local scheduler.spryker.local queue.spryker.local" | sudo tee -a /etc/hosts
```
@(Info)()(If needed, add corresponding entries for other stores. For example, if you are going to have a US store, add the following entries: `zed.us.spryker.local glue.us.spryker.local yves.us.spryker.local`)
  - Windows:
    1. Open the Start menu.
    2. In the search field, enter `Notepad`.
    3. Right-click *Notepad* and select **Run as administrator**.
    4. In the *User Account Control* window, select **Yes** to confirm the action.
    5. In the upper navigation panel, select **File** > **Open**.
    6. Put the following path into the address line: `C:\Windows\System32\drivers\etc`.
    7. In the **File name** line, enter `hosts` and select **Open**.
    The hosts file opens in the drop-down.
    8. Add the following line into the file:
    ```text
    127.0.0.1   zed.de.spryker.local glue.de.spryker.local yves.de.spryker.local scheduler.spryker.local mail.spryker.local queue.spryker.local
    ```
    @(Info)()(If needed, add corresponding entries for other stores. For example, if you are going to have a US store, add the following entries: `zed.us.spryker.local glue.us.spryker.local yves.us.spryker.local`)
    9. Select **File** > **Save**.
    10. Close the file.


@(Warning)()(Depending on the hardware performance, the first project launch can take up to 20 minutes.)

## Endpoints

To ensure that the installation is successful, make sure you can access the following endpoints.

| Application | Endpoints |
| --- | --- |
| The Storefront |  yves.de.spryker.local, yves.at.spryker.local, yves.us.spryker.local |
| the Back Office | zed.de.spryker.local, zed.at.spryker.local, zed.us.spryker.local |
| Glue API | glue.de.spryker.local, glue.at.spryker.local, glue.us.spryker.local |
| Jenkins (scheduler) | scheduler.spryker.local |
| RabbitMQ UI (queue manager) | queue.spryker.local |
| Mailhog UI (email catcher) | mail.spryker.local |

:::(Info) (RabbitMQ UI credentials)
To access RabbitMQ UI, use `spryker` as a username and `secret` as a password. You can adjust the credentials in `deploy.yml`. See [Deploy File Reference - 1.0](../../99-deploy.file.reference.v1.md) to learn about the Deploy file.
:::

## Getting the list of useful commands

To get the full and up-to-date list of commands, run `docker/sdk help`.

## Next steps

* [Troubleshooting](../../troubleshooting.md)
* [Configuring debugging](../../02-development-usage/05-configuring-debugging.md)
* [Deploy File Reference - 1.0](../../99-deploy.file.reference.v1.md)
* [Configuring services](../../06-configuring-services.md)
* [Setting up a self-signed SSL certificate](https://documentation.spryker.com/docs/setting-up-a-self-signed-ssl-certificate)
* [Additional DevOPS guidelines](https://documentation.spryker.com/docs/additional-devops-guidelines)
