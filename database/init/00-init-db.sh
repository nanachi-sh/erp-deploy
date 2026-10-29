#!/bin/sh
set -eu

: "${ERP_APP_PASSWORD:?缺少 ERP_APP_PASSWORD}"
: "${ERP_MIGRATE_PASSWORD:?缺少 ERP_MIGRATE_PASSWORD}"

# 不用 exec：脚本若丢失执行位，entrypoint 会以 source 方式加载它，
# exec 会把 entrypoint 的 shell 整个替换掉，导致初始化流程半途退出
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v erp_app_password="$ERP_APP_PASSWORD" \
  -v erp_migrate_password="$ERP_MIGRATE_PASSWORD" \
  -f /opt/init/init.sql