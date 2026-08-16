-- S07 : 정상 재기동
-- 노리는 것: lifecycle 계열의 "정상판" 표본
--            shutdown immediate 는 체크포인트를 완료하고 내려가므로
--            재기동 시 crash recovery 가 일어나지 않는다. S08 과의 대조군이다.

SET ECHO ON
WHENEVER SQLERROR CONTINUE

EXEC DBMS_SYSTEM.KSDWRT(2, '### S07 BEGIN restart-clean');

SHUTDOWN IMMEDIATE
STARTUP

-- 기동이 끝난 뒤에야 마커를 남길 수 있다
EXEC DBMS_SYSTEM.KSDWRT(2, '### S07 END');

SELECT status, startup_time FROM v$instance;

SET ECHO OFF
PROMPT >>> 30초 쉬고 S08 로
