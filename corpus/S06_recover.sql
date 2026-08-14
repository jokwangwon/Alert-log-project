-- S06 복구 : 포화된 FRA 를 풀어준다
-- 터미널2에서 실행. S06_fra_full.sql 이 멈춘 뒤에 쓴다.
--
-- 장애 → 해소 과정이 그대로 로그에 남는 것이 목적이다.
-- 사람이 어떻게 조치했는지가 기록에 어떤 모습으로 남는지 보는 것.

SET ECHO ON
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE

SELECT space_limit/1024/1024 AS limit_mb, space_used/1024/1024 AS used_mb
FROM   v$recovery_file_dest;

-- 조치 1: 한도를 원래대로 되돌린다 (00_setup.out 에 적어둔 값)
--         아래 8256M 은 예시다. 본인 환경의 원래 값으로 바꿔 쓸 것.
ALTER SYSTEM SET db_recovery_file_dest_size = 8256M;

EXEC DBMS_SESSION.SLEEP(15);

-- 막혔던 아카이빙이 재개되는지 확인
SELECT space_limit/1024/1024 AS limit_mb, space_used/1024/1024 AS used_mb
FROM   v$recovery_file_dest;

EXEC DBMS_SYSTEM.KSDWRT(2, '### S06 END');

SET ECHO OFF
PROMPT >>> 조치 2 (선택): 쌓인 아카이브 로그 정리
PROMPT >>>   rman target /
PROMPT >>>   DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1/24';
PROMPT
PROMPT >>> 30초 쉬고 S07 로
