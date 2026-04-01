<?php
// Zabbix 6.0 Web Configuration - POD2 Monitoring

$DB['TYPE']     = 'POSTGRESQL';
$DB['SERVER']   = getenv('DB_SERVER_HOST') ?: 'pod2-postgresql';
$DB['PORT']     = getenv('DB_PORT') ?: '5432';
$DB['DATABASE'] = getenv('DB_DATABASE') ?: 'zabbix60';
$DB['USER']     = getenv('DB_USER') ?: 'zabbix';
$DB['PASSWORD'] = getenv('DB_PASSWORD') ?: '';
$DB['SCHEMA']   = getenv('DB_SCHEMA') ?: 'public';

$ZBX_SERVER      = 'pod2-zabbix-6.0-server';
$ZBX_SERVER_PORT = getenv('ZBX_SERVER_PORT') ?: '10051';
$ZBX_SERVER_NAME = getenv('ZBX_SERVER_NAME') ?: 'Zabbix 6.0 LTS';

$IMAGE_FORMAT_DEFAULT = 'PNG';

$HISTORY['url'] = 'http://localhost/';
$HISTORY['types'] = ['uint', 'dbl', 'str', 'log', 'text'];

$IMAGE_TRUSTED_PATHS = ['/usr/share/zabbix/img/', '/usr/share/zabbix/assets/'];

session_name('zbx_sessionid');
$MEMORY_LIMIT = '256M';
$MAX_EXECUTION_TIME = '300';
$MAX_INPUT_TIME = '300';
$UPLOAD_MAX_FILESIZE = '16M';
?>