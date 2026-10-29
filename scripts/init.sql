-- scripts/init.sql
-- 用 postgres 超级管理员执行
--
-- 两个口令没有默认值，必须由调用方传入：
--   psql -v erp_app_password=<口令> -v erp_migrate_password=<口令> -f scripts/init.sql

-- 脚本里任何 SQL 出错都立即中止并以非零码退出。psql 默认是 ON_ERROR_STOP=off，表现为
-- 「每句都报错、最后仍以 0 退出」—— 下面任何一条 GRANT 一旦失败，调用方拿不到失败信号。
\set ON_ERROR_STOP on

-- 必需变量检查。
--
-- 为什么必须显式检查：psql 对未定义变量不做替换，:'erp_app_password' 会被原样送到服务端，
-- 报一句与「忘传变量」毫无关系的语法错误；而那时 CREATE DATABASE 已经成功，调用方却以为
-- 整个初始化成功了。
--
-- 为什么排在「库已存在就跳过」之前：否则重跑一次会先被那个守卫 \quit 掉，变量缺失永远
-- 暴露不出来。
\if :{?erp_app_password}
\else
\warn '错误：未定义变量 erp_app_password'
\warn '     用法：psql -v erp_app_password=<口令> -v erp_migrate_password=<口令> -f scripts/init.sql'
DO $$ BEGIN RAISE EXCEPTION 'init.sql: 缺少必需变量 erp_app_password'; END $$;
\endif

\if :{?erp_migrate_password}
\else
\warn '错误：未定义变量 erp_migrate_password'
\warn '     用法：psql -v erp_app_password=<口令> -v erp_migrate_password=<口令> -f scripts/init.sql'
DO $$ BEGIN RAISE EXCEPTION 'init.sql: 缺少必需变量 erp_migrate_password'; END $$;
\endif

SELECT (EXISTS(SELECT FROM pg_database WHERE datname = 'erp_db'))::int AS db_exists \gset

\if :db_exists
\echo '数据库 erp_db 已存在，跳过初始化'
\quit
\endif

CREATE DATABASE erp_db;

CREATE USER erp_app     LOGIN PASSWORD :'erp_app_password';
CREATE USER erp_migrate LOGIN PASSWORD :'erp_migrate_password';

\c erp_db

-- ============ erp_migrate 权限 ============
-- 只需要 schema 级别的建表权限
-- ALTER/DROP 由 owner 身份保证，不需要额外 GRANT
GRANT USAGE, CREATE ON SCHEMA public TO erp_migrate;

-- erp_migrate 建的表/sequence，自动授权给 erp_app
ALTER DEFAULT PRIVILEGES FOR ROLE erp_migrate IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO erp_app;

ALTER DEFAULT PRIVILEGES FOR ROLE erp_migrate IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO erp_app;

-- ============ erp_app 权限 ============
GRANT CONNECT ON DATABASE erp_db TO erp_app;
GRANT USAGE ON SCHEMA public TO erp_app;
-- 表级权限由 DEFAULT PRIVILEGES 在建表时自动赋予，无需迁移文件手动处理