-- S01 : log switch 20회
-- 정상 이벤트 표본을 싸고 안전하게 대량 확보한다.
-- 노리는 것: archive.log_switch / archive.archived / checkpoint.log_switch

SET ECHO ON
WHENEVER SQLERROR CONTINUE

EXEC DBMS_SYSTEM.KSDWRT(2, '### S01 BEGIN log-switch-x20');

BEGIN
  FOR i IN 1 .. 20 LOOP
    EXECUTE IMMEDIATE 'ALTER SYSTEM SWITCH LOGFILE';
  END LOOP;
END;
/

-- 아카이빙이 끝나야 Archived Log entry 줄이 남는다. 마커 전에 기다린다.
EXEC DBMS_SESSION.SLEEP(20);

EXEC DBMS_SYSTEM.KSDWRT(2, '### S01 END');

SET ECHO OFF
PROMPT >>> 30초 쉬고 S02 로 넘어갈 것
