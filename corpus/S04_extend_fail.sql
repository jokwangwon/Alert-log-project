-- S04 : 테이블스페이스 확장 실패
-- autoextend 를 끈 작은 테이블스페이스를 데이터로 채워 ORA-01653 을 낸다.
-- 노리는 것: 공간 부족 계열 에러
--
-- ※ 검증 대상: ORA-01653 이 alert log 에 기록되는지 자체가 불확실하다.
--    세션 에러로만 끝나고 alert log 에는 안 남을 수도 있다.
--    "기록되지 않는다"도 유효한 발견이므로 manifest 에 예측을 적어두고 대조한다.

SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE

EXEC DBMS_SYSTEM.KSDWRT(2, '### S04 BEGIN tablespace-extend-fail');

-- 10M 짜리, 자동확장 없음
CREATE TABLESPACE ts_small DATAFILE SIZE 10M AUTOEXTEND OFF;
ALTER USER alertlab QUOTA UNLIMITED ON ts_small;

CREATE TABLE alertlab.fill_t (id NUMBER, pad CHAR(2000)) TABLESPACE ts_small;

-- 10M 를 넘길 때까지 넣는다. 중간에 ORA-01653 으로 끊긴다.
BEGIN
  FOR i IN 1 .. 20000 LOOP
    INSERT INTO alertlab.fill_t VALUES (i, 'x');
  END LOOP;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('예상된 실패: ' || SQLERRM);
    ROLLBACK;
END;
/

-- 데이터파일을 키워서 해소되는 것까지 한 세트로 기록한다 (실패 → 복구 스토리)
-- ALTER DATABASE DATAFILE 은 서브쿼리를 받지 않는다. 치환 변수로 경로를 넣는다.
EXEC DBMS_SESSION.SLEEP(5);

COLUMN dfile NEW_VALUE v_dfile
SELECT file_name AS dfile FROM dba_data_files WHERE tablespace_name = 'TS_SMALL' AND ROWNUM = 1;

ALTER DATABASE DATAFILE '&v_dfile' RESIZE 30M;

EXEC DBMS_SYSTEM.KSDWRT(2, '### S04 END');

SET ECHO OFF
PROMPT >>> 30초 쉬고 S05 로
