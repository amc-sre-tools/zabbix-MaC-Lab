<?php
// Zabbix Web Configuration
// Auto-generated for POD2 Monitoring

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = getenv('DB_SERVER_HOST') ?: 'pod2-postgresql';
$DB['PORT']     = '3306';
$DB['DATABASE'] = getenv('MYSQL_DATABASE') ?: 'zabbix';
$DB['USER']     = getenv('MYSQL_USER') ?: 'zabbix';
$DB['PASSWORD'] = getenv('MYSQL_PASSWORD') ?: '';

$DB['SCHEMA'] = '';
$ZBX_SERVER      = getenv('ZBX_SERVER_HOST') ?: 'localhost';
$ZBX_SERVER_PORT = '10051';
$ZBX_SERVER_NAME = getenv('ZBX_SERVER_NAME') ?: 'Zabbix';

$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;

$HISTORY['url'] = 'http://localhost/';
$HISTORY['types'] = ['uint', 'dbl', 'str', 'log', 'text'];

$IMAGE_TRUSTED_PATHS = ['/usr/share/zabbix/img/', '/usr/share/zabbix/assets/'];
?>