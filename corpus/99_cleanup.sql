-- 99_cleanup.sql : 테스트 객체 정리 · 파라미터 원복
-- 코퍼스 파일을 복사해둔 뒤에 실행할 것.
-- 마커를 남기지 않는다 (시나리오가 아니라 뒷정리)

SET ECHO ON
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE

-- 파라미터 원복 확인 (00_setup.out 의 값과 대조)
SELECT space_limit/1024/1024 AS limit_mb, space_used/1024/1024 AS used_mb
FROM   v$recovery_file_dest;

DROP TABLESPACE ts_small INCLUDING CONTENTS AND DATAFILES;
DROP USER alertlab CASCADE;

-- 최종 건강 상태 — 시작할 때와 같아야 한다
SELECT * FROM v$recover_file;
SELECT tablespace_name, status FROM dba_tablespaces WHERE status <> 'ONLINE';
SELECT file#, status, name FROM v$datafile WHERE status NOT IN ('ONLINE','SYSTEM');

PROMPT === 정리 완료 ===
