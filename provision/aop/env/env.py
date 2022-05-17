from auth0.auth0 import Auth0
from common.aws.ssm.ssm import AwsSsm
from atrs.atrs import Atrs

import logging
import os

class Env:

    @classmethod
    def define_tenant_environment_vars(self, tenants, configs):
        logging.info('[ENV] Defining tenant environment variables')

        aws_region = os.environ['AWS_REGION']

        store_map = {}
        sqs_receivers = {}
        for tenant, tenant_data in tenants['tenants'].items():
            store_map.update({tenant: tenant_data['storeReference']})
            sqs_receivers.update({tenant: {"queue_name": tenant_data['storeReference']}})

        logging.info('[ENV] Store map: {}'.format(store_map))
        logging.info('[ENV] Sqs receivers: {}'.format(sqs_receivers))

        env_vars = {
            "SPRYKER_AOP_INFRASTRUCTURE": {
                "SPRYKER_MESSAGE_BROKER_HTTP_SENDER_CONFIG": {
                    "endpoint" : "https://{}/event-tenant".format('NOT_DEFINED' if Atrs.ATRS_HOST_KEY not in configs else configs[Atrs.ATRS_HOST_KEY])
                },
                "SPRYKER_MESSAGE_BROKER_SQS_RECEIVER_CONFIG": {
                      "default": {
                        "endpoint": "https://sqs.{}.amazonaws.com".format(aws_region),
                        "auto_setup": "false",
                        "buffer_size": 1
                      } | sqs_receivers
                },
            },
            "SPRYKER_AOP_APPLICATION": {
                "APP_CATALOG_SCRIPT_URL": "https://www.trs-staging.demo-spryker.com/loader",
                "STORE_NAME_REFERENCE_MAP": store_map
            },
            'SPRYKER_AOP_AUTHENTICATION': {
                'AUTH0_CUSTOM_DOMAIN': 'NOT_DEFINED' if Auth0.AUTH0_CONFIG_HOST_KEY not in configs else configs[Auth0.AUTH0_CONFIG_HOST_KEY],
                'AUTH0_CLIENT_ID': tenants['client_id'],
                'AUTH0_CLIENT_SECRET': tenants['client_secret'],
            },
        }

        logging.info('[ENV] Tenant environment variables {}'.format(env_vars))

        AwsSsm.update_environment_variables(env_vars, AwsSsm.PARAM_STORE_SECRET)

        return None

    @classmethod
    def define_app_environment_vars(self, apps, configs):
        aws_region = os.environ['AWS_REGION']

        app_pattern = '{}_APP_IDENTIFIER'
        registered_apps = {
            'SPRYKER_AOP_APPLICATION': {}
        }

        for app_key, app_data in apps['apps'].items():
            registered_apps['SPRYKER_AOP_APPLICATION'].update({app_pattern.format(app_key.upper()): app_data['appId']})

        env_vars = {
            'SPRYKER_AOP_INFRASTRUCTURE': {
                'SPRYKER_MESSAGE_BROKER_HTTP_SENDER_CONFIG': {
                    'endpoint': 'https://{}/event-app'.format('NOT_DEFINED' if Atrs.ATRS_HOST_KEY not in configs else configs[Atrs.ATRS_HOST_KEY])
                },
                'SPRYKER_MESSAGE_BROKER_SQS_RECEIVER_CONFIG': {
                    'default': {
                        'endpoint': 'https://sqs.{}.amazonaws.com'.format(aws_region),
                        'auto_setup': 'false',
                        'buffer_size': 1,
                        'queue_name': '' if 'payone' not in apps['apps'] else apps['apps']['payone']['appId']
                    }
                },
                'AWS_SECRETS_MANAGER_ENDPOINT': 'https://secretsmanager.{}.amazonaws.com'.format(aws_region),
            },
            'SPRYKER_AOP_AUTHENTICATION': {
                'AUTH0_CUSTOM_DOMAIN': 'NOT_DEFINED' if Auth0.AUTH0_CONFIG_HOST_KEY not in configs else configs[Auth0.AUTH0_CONFIG_HOST_KEY],
                'AUTH0_CLIENT_ID': apps['client_id'],
                'AUTH0_CLIENT_SECRET': apps['client_secret'],
            },
        } | registered_apps

        AwsSsm.update_environment_variables(env_vars, AwsSsm.PARAM_STORE_SECRET)

        logging.info('[ENV] App environment variables {}'.format(env_vars))

        return None