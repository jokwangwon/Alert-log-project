-- S06 : 아카이브 영역(FRA) 포화
-- 노리는 것: ORA-19809 / ORA-19804 / ORA-00257, ARCH 정지
--
-- ★★ 이 시나리오는 DB를 멈춘다. 터미널 2개를 미리 열어둘 것.
-- ★★ 이 창은 log switch 에서 응답 없이 멈춘다. 그게 정상이고, 그 순간이 목표다.
--     멈추면 터미널2에서 @S06_recover.sql 을 실행해 풀어준다.
--
-- FRA 를 채우는 대신 한도를 현재 사용량 바로 위로 낮춘다.
-- 8GB 를 redo 로 채우려면 몇 시간이 걸리지만, 이 방법은 몇 분이면 된다.

SET ECHO ON
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE

PROMPT === 원복할 현재 한도를 반드시 적어둘 것 ===
SELECT space_limit/1024/1024 AS limit_mb, space_used/1024/1024 AS used_mb
FROM   v$recovery_file_dest;

-- 현재 사용량 + 20MB 로 한도를 조인다
COLUMN newsize NEW_VALUE v_newsize
SELECT CEIL(space_used/1024/1024) + 20 AS newsize FROM v$recovery_file_dest;

EXEC DBMS_SYSTEM.KSDWRT(2, '### S06 BEGIN fra-full');

ALTER SYSTEM SET db_recovery_file_dest_size = &v_newsize.M;

-- 20MB 여유는 몇 번의 log switch 로 곧 소진된다
BEGIN
  FOR i IN 1 .. 30 LOOP
    EXECUTE IMMEDIATE 'ALTER SYSTEM SWITCH LOGFILE';
  END LOOP;
END;
/

PROMPT >>> 여기까지 왔다면 아직 안 막힌 것이다. 위 블록을 한 번 더 실행할 것.
PROMPT >>> 멈췄다면 터미널2에서 @S06_recover.sql
