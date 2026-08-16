-- 00_setup.sql : 상태 점검 + 설정 스냅샷 + 테스트 스키마
-- 실행: sqlplus / as sysdba  →  @00_setup.sql
-- 이 스크립트는 alert log에 마커를 남기지 않는다 (시나리오가 아니라 준비 단계)

SET ECHO ON
SET LINESIZE 200
SET PAGESIZE 100
WHENEVER SQLERROR CONTINUE

SPOOL 00_setup.out

-- ── 1. 건강 상태 점검 ─────────────────────────────────
-- 아래 4개가 전부 "no rows selected" 여야 깨끗한 출발점이다

PROMPT === 복구가 필요한 파일 (비어야 정상) ===
SELECT * FROM v$recover_file;

PROMPT === redo 멤버 이상 (INVALID 없어야 정상) ===
SELECT group#, status, member FROM v$logfile WHERE status IS NOT NULL;

PROMPT === 데이터파일 이상 ===
SELECT file#, status, name FROM v$datafile WHERE status NOT IN ('ONLINE','SYSTEM');

PROMPT === 테이블스페이스 이상 ===
SELECT tablespace_name, status FROM dba_tablespaces WHERE status <> 'ONLINE';

-- ── 2. 설정 스냅샷 ────────────────────────────────────
-- 코퍼스가 "어떤 설정 아래서 만들어졌는지"의 기록.
-- isdefault='FALSE' = 기본값이 아닌 것 = 누군가 의도적으로 설정한 것

PROMPT === 인스턴스 ===
SELECT instance_name, version, status, startup_time FROM v$instance;

PROMPT === 데이터베이스 ===
SELECT name, log_mode, open_mode, platform_name FROM v$database;

PROMPT === 비기본값 파라미터 ===
SELECT name, value FROM v$parameter WHERE isdefault='FALSE' ORDER BY name;

PROMPT === FRA 사용량 (S06 에서 원복할 값) ===
SELECT name,
       space_limit/1024/1024 AS limit_mb,
       space_used /1024/1024 AS used_mb
FROM   v$recovery_file_dest;

PROMPT === redo 그룹 구성 (S01 log switch 규모 가늠) ===
SELECT group#, thread#, bytes/1024/1024 AS mb, members, status FROM v$log;

-- ── 3. 지난 실습 잔재 정리 ────────────────────────────
-- 2026-07-27 실습에서 만든 test_ts 가 남아 있으면 치운다

DROP TABLESPACE test_ts INCLUDING CONTENTS AND DATAFILES;

-- ── 4. 테스트 스키마 ──────────────────────────────────
-- SYS 스키마를 더럽히지 않기 위해 전용 계정을 만든다

DROP USER alertlab CASCADE;
CREATE USER alertlab IDENTIFIED BY alertlab;
GRANT CONNECT, RESOURCE TO alertlab;
ALTER USER alertlab QUOTA UNLIMITED ON users;

PROMPT === 준비 완료 ===
SELECT 'setup done' AS status FROM dual;

SPOOL OFF
SET ECHO OFF
