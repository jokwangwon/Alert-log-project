-- S05 : 데이터파일 접근 불가 → 원복
-- 노리는 것: ORA-01157 / ORA-01110 / ORA-27041 (media failure 계열)
--
-- ★ 반드시 원복까지 실행할 것. 중간에 끊으면 테이블스페이스가 못 쓰는 상태로 남는다.
-- ★ 대상은 S04 에서 만든 ts_small 뿐이다. 시스템 파일은 건드리지 않는다.

SET ECHO ON
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE

-- 대상 데이터파일 경로를 변수로 잡는다
COLUMN dfile NEW_VALUE v_dfile
SELECT file_name AS dfile FROM dba_data_files WHERE tablespace_name = 'TS_SMALL' AND ROWNUM = 1;
PROMPT 대상 파일: &v_dfile

EXEC DBMS_SYSTEM.KSDWRT(2, '### S05 BEGIN datafile-permission-denied');

ALTER TABLESPACE ts_small OFFLINE;

-- 권한 박탈: oracle 소유자라도 000 이면 열 수 없다
!chmod 000 &v_dfile
!ls -l &v_dfile

-- 여기서 실패해야 한다
ALTER TABLESPACE ts_small ONLINE;

EXEC DBMS_SESSION.SLEEP(10);

-- ── 원복 ──────────────────────────────────────────────
!chmod 640 &v_dfile
!ls -l &v_dfile

ALTER TABLESPACE ts_small ONLINE;

-- 정상으로 돌아왔는지 확인
SELECT tablespace_name, status FROM dba_tablespaces WHERE tablespace_name = 'TS_SMALL';
SELECT * FROM v$recover_file;

EXEC DBMS_SYSTEM.KSDWRT(2, '### S05 END');

SET ECHO OFF
PROMPT >>> ts_small 이 ONLINE 인지 반드시 확인하고 S06 으로
