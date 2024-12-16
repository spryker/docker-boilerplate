# Troubleshooting

This document contains solutions to the most common issues related to the Docker SDK.

## Troubleshooting installation
This section describes common issues related to installation.



### Docker daemon is not running

**when**
Running the `docker/sdk up` console command returns a similar error:
```bash
Error response from daemon: Bad response from Docker engine
```

**then**
1. Make sure Docker daemon is running.
2. Run `docker/sdk up` again.


### docker-sync cannot start

**when**
Running `docker-sync clean` returns an error similar to the following:
```bash
docker: Error response from daemon: Conflict. The container name "/data-sync" is already in use by container "47dd708a7a7f9550390432289bd85fe0e4491b080748fcbba7ddb3331de2c7e7". You have to remove (or rename) that container to be able to reuse that name.
```

**then**
1. Run `docker-sync clean`.
2. Run `docker/sdk up` again.
***

**when**
You get an error similar to the following:
```bash
Unable to find image "eugenmayer/unison:hostsync_@.2' Locally
docker: Error response from daemon: manifest for eugenmayer/unison:hostsync_@.2 not found: manifest unknown: manifest unknown.
```

**then**
Update docker-sync:
```bash
gem install docker-sync
```

### Setup of new indexes throws an exception

**when**
Running the command `setup-search-create-sources [vendor/bin/console search:setup:sources]` returns the exception:
```
Elastica\Exception\Connection\HttpException - Exception: Couldn't resolve host
in /data/vendor/ruflin/elastica/lib/Elastica/Transport/Http.php (190)
```

**then**
Increase RAM for Docker usage.


### Vendor folder synchronization error

**when**
You get an error similar to `vendor/bin/console: not found`.

**then**
Re-build basic images, assets, and codebase:
```bash
docker/sdk up --build --assets
```

### An error during front end setup

**when**
The `frontend:project:install-dependencies` command returns an error similar to the following:
```
-->  DEVELOPMENT MODE
Store: US | Environment: docker
Install Project dependencies
[info] npm
[info]  WARN prepare
[info]  removing existing node_modules/ before installation
[info]
> fsevents@1.2.11 install /data/node_modules/fsevents
> node-gyp rebuild
[info] gyp
[info]  ERR! find Python
gyp ERR! find Python
[info]  Python is not set from command line or npm configuration
gyp ERR!
[info] find Python Python is not set from environment variable PYTHON
gyp ERR!
[info]  find Python checking if "python" can be used
gyp ERR!
```

**then**

1. In `deploy.*.yaml`, change the base PHP image:
```yaml
image:
    tag: spryker/php:7.3-alpine3.10
```

2. Fetch the changes and start the instance:
```bash
docker/sdk boot && docker/sdk up
```

### Demo data was imported incorrectly

**when**
Demo data was imported incorrectly.

**then**
Re-load demo data:
```bash
docker/sdk clean-data && docker/sdk up --data && docker/sdk console q:w:s -v -s
```

## Troubleshooting running applications

This section describes common issues related to running applications.


### Port is already occupied on host

**when**
Running the `docker/sdk up` console command returns an error similar to the following:
```bash
ERROR: for nginx_frontend Cannot start service nginx_frontend: driver failed programming external connectivity on endpoint spryker_nginx_frontend_1 (e4fdb360f6c9a3243c0a88fa74f8d377325f65b8cd2340b2dacb51377519c1cf): Error starting userland proxy: Bind for 0.0.0.0:80: unexpected error (Failure EADDRINUSE)
```

**then**
1. Check what process occupies the port:
```bash
sudo lsof -nPi:80 | grep LISTEN
```
2. Stop the process or make it use a different port.
3. Run `docker/sdk up` again.


### 413 Request Entity Too Large

**when**
You get the `413 Request Entity Too Large` error.

**then**
1. Increase the maximum request body size for the related application. See [Deploy File Reference - 1.0](07-deploy-file/02-deploy.file.reference.v1.md#groups-applications) to learn how to do that.
2. Fetch the update:
```bash
docker/sdk bootstrap
```
3. Re-build applications:
```bash
docker/sdk up
```

### Nginx welcome page

**when**
You get the Nginx welcome page by opening an application in the browser.

**then**
1. Update the nginx:alpine image:

```bash
docker pull nginx:alpine
```

2. Re-build applications:

```bash
docker/sdk up
```

### An application is not reachable via http

**when**
An application like Yves, BackOffice(Zed), GlueStorefront(Glue), GlueBackend or MerchantPortal is not reachable after installation.

**then**
In `deploy.*.yml`, ensure that SSL encryption is disabled:
```yaml
docker:
    ssl:
        enabled: false
```

### Mutagen

**when**
You get the error:
```bash
unable to reconcile Mutagen sessions: unable to create synchronization session (spryker-dev-codebase): unable to connect to beta: unable to connect to endpoint: unable to dial agent endpoint: unable to create agent command: unable to probe container: container probing failed under POSIX hypothesis (signal: killed) and Windows hypothesis (signal: killed)
```

**then**
1. Restart your OS.
2. If the error persists: Check [Mutagen documentation](https://mutagen.io/documentation/introduction).


**when**
There is a synchronization issue.

**then**

* Restart your OS.
* Run the commands:
```
docker/sdk trouble
mutagen sync list
mutagen sync terminate <all sessions in the list>
docker/sdk up
```

**when**
Revert on specific Mutagen version.
E.G you are using Docker Compose V1 and you don't have the possibility to update to the docker compose v2 (mandatory requirement).

**then**

* Get commit hash from https://github.com/mutagen-io/homebrew-mutagen/commits/master
* Remove prev mutagen version:
```
brew uninstall --ignore-dependencies {{ mutagen || mutagen-beta }}
```

* Run the commands:
```
cd "$(brew --repo mutagen-io/homebrew-mutagen)" && \
git checkout {{ HASH COMMIT FROM mutagen-io/homebrew-mutagen }} && \
HOMEBREW_NO_AUTO_UPDATE=1 brew install mutagen-io/mutagen/{{ mutagen || mutagen-beta }} && \
mutagen daemon stop  && \
mutagen daemon start && \
cd -
```

**when**
Error:
```
unable to bring up Mutagen Compose sidecar service: unable to reconcile Mutagen sessions: unable to connect to Mutagen daemon: client/daemon version mismatch (daemon restart recommended)
```

**then**

* Run the commands:
```
mutagen daemon stop
docker/sdk prune
```


## Troubleshooting debugging

This section describes common issues related to debugging.



**when**
Xdebug does not work.

**then**
1. Ensure that Xdebug is enabled in `deploy.*.yml`:
```
```yaml
docker:
...
    debug:
      xdebug:
        enabled: true
```
When working on Windows with WSL2, ensure the debug configuration is set up as follows:
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
2. Ensure that IDE is listening to the port 9000.
3. Check if the host is accessible from the container:
```bash
docker/sdk cli -x bash -c 'nc -zv ${SPRYKER_XDEBUG_HOST_IP} 9000'
```

**when**
`nc` command does not give any output.

**then**
[Contact us](https://support.spryker.com/hc/en-us).

**when**
`nc` command tells that the port is opened.

**then**
1. Check what process occupies the port 9000 by running the command on the host:
```bash
sudo lsof -nPi:9000 | grep LISTEN
```
2. If it's not your IDE, free up the port to be used by the IDE.

**when**
PHP `xdebug` extension is not active in CLI.

**then**
Exit the CLI session and enter it with the `-x` argument:
* `docker/sdk cli -x`
* `docker/sdk testing -x`

**when**
PHP `xdebug` extension is not active when accessing the website via a browser or curl.

**then**

Try the following:
* Set the `XDEBUG_SESSION=spryker` cookie for the request. You can use a browser extension like [Xdebug helper](https://chrome.google.com/webstore/detail/xdebug-helper/eadndfjplgieldjbigjakmdgkmoaaaoc).
* Run the following command to switch all applications to debug mode:
    ```bash
    docker/sdk run -x
    ```

**when**
It's not possible to establish the database connection from the host machine.

**then**
1. Check that the deploy yml file is used and make sure the port is exposed.
2. Check that port is not occupied by the local process by running `sudo lsof -nP -i4TCP:3306 | grep LISTEN` (with port declared in the deploy.yml file).
3. Check if the proper credentials and database name are used. You can find all the required information in the deploy yml file.


**when**
You get an error after running `docker/sdk cli {ARGUMENT_1}`.

**then**
Wrap the command arguments into single quotes. For example, `docker/sdk cli 'composer require spryker/*'`

**when**
`Node Sass does not yet support your current environment: Linux Unsupported architecture (arm64) with Node.js`

**then**
1. remove `node-sass` dependencies in `package.json`
2. add `sass` and `sass-loader`
```
...
"sass": "~1.32.13",
"sass-loader": "~10.2.0",
...
```
3. update `@spryker/oryx-for-zed`
```
...
"@spryker/oryx-for-zed": "~2.11.5",
...
```
4. add option to sass-loader (`frontend/configs/development.js`)
```
loader: 'sass-loader',
options: {
   implementation: require('sass'),
}
```
5. run `docker/sdk cli`
6. run `npm install` to update `package-lock.json` and install dependencies
7. (if yarn usage) run `yarn install` to update `package-lock.json` and install dependencies
8. run `npm run yves` to rebuild yves
9. run `npm run zed` to rebuild zed

**when**
Error 403 No valid crumb was included in the request

**then**
Check your project configuration. Jenkins CSRF protection should be enabled.
```php
...
$config[SchedulerJenkinsConstants::JENKINS_CONFIGURATION] = [
    SchedulerConfig::SCHEDULER_JENKINS => [
        SchedulerJenkinsConfig::SCHEDULER_JENKINS_CSRF_ENABLED => true,
    ],
];
...
```
You can use `SPRYKER_JENKINS_CSRF_PROTECTION_ENABLED` env variable. This variable depends on deploy file parameter from `scheduler`
```yaml
services:
  scheduler:
    csrf-protection-enabled: { true | false }

```
```php
...
$config[SchedulerJenkinsConstants::JENKINS_CONFIGURATION] = [
    SchedulerConfig::SCHEDULER_JENKINS => [
        SchedulerJenkinsConfig::SCHEDULER_JENKINS_CSRF_ENABLED => (bool)getenv('SPRYKER_JENKINS_CSRF_PROTECTION_ENABLED'),
    ],
];
...
```

**when**
Assets install error
```bash
line 1: run-s: not found
```

**then**
1. ensure you are using latest docker-sdk and spryker/php image.
2. run `docker/sdk pull`
3. run `docker/sdk boot {{your deploy file}} && docker/sdk up --build`


**when**
Installation error with Mutagen v0.18.*
```bash
unable to bring up Mutagen Compose sidecar service: Error response from daemon: network  is ambiguous (5 matches found based on ID prefix)
```

**then**
brew unlink mutagen && brew unlink mutagen-compose && brew install mutagen-io/mutagen/mutagen@0.17 mutagen-io/mutagen/mutagen-compose@0.17
