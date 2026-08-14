-- S08 : abort 후 재기동 (crash recovery)
-- 노리는 것: recovery.crash_begin / redo_scan / redo_application / crash_end
--
-- shutdown abort 는 체크포인트 없이 프로세스를 죽인다.
-- 그래서 다음 기동 때 Oracle 이 redo 로그를 읽어 스스로 복구하고,
-- 그 과정이 alert log 에 통째로 남는다. S07 로그와 나란히 놓고 비교할 것.
--
-- 커밋된 데이터는 redo 에 있으므로 손실되지 않는다. 테스트 인스턴스에서는 안전하다.

SET ECHO ON
WHENEVER SQLERROR CONTINUE

-- 복구할 거리를 만든다: 커밋 안 된 트랜잭션을 남긴 채 죽인다
CREATE TABLE alertlab.crash_t (id NUMBER, pad CHAR(500));
BEGIN
  FOR i IN 1 .. 5000 LOOP
    INSERT INTO alertlab.crash_t VALUES (i, 'x');
  END LOOP;
END;
/
-- COMMIT 하지 않는다

EXEC DBMS_SYSTEM.KSDWRT(2, '### S08 BEGIN restart-abort');

SHUTDOWN ABORT
STARTUP

EXEC DBMS_SYSTEM.KSDWRT(2, '### S08 END');

SELECT status, startup_time FROM v$instance;
-- 롤백되어 0건이어야 한다
SELECT COUNT(*) AS rows_left FROM alertlab.crash_t;

SET ECHO OFF
PROMPT >>> 코퍼스 수집 완료. README 의 "끝나고" 절차로.
