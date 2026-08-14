-- S03 세션 A : 데드락 유발
-- 노리는 것: ORA-00060 (Deadlock detected)
--
-- ★ 터미널 2개가 필요하다. 순서를 지켜야 데드락이 만들어진다.
--
--   터미널1: @S03_deadlock_a.sql   → 1단계까지 실행되고 멈춤 (프롬프트 반환)
--   터미널2: @S03_deadlock_b.sql   → 1단계까지 실행되고 멈춤
--   터미널1: 아래 "2단계" 블록을 직접 붙여넣기 → 대기 상태로 들어감
--   터미널2: 아래 "2단계" 블록을 직접 붙여넣기 → 여기서 ORA-00060 발생
--
-- 두 세션이 서로가 잡은 행을 기다리는 순환이 만들어져야 Oracle이 데드락으로 판정한다.

SET ECHO ON
WHENEVER SQLERROR CONTINUE

EXEC DBMS_SYSTEM.KSDWRT(2, '### S03 BEGIN deadlock');

-- 대상 테이블 (A 세션에서만 만든다)
DROP TABLE alertlab.dl_test PURGE;
CREATE TABLE alertlab.dl_test (id NUMBER PRIMARY KEY, v NUMBER);
INSERT INTO alertlab.dl_test VALUES (1, 100);
INSERT INTO alertlab.dl_test VALUES (2, 200);
COMMIT;

-- 1단계: 1번 행을 잠근다 (커밋하지 않는다)
UPDATE alertlab.dl_test SET v = v + 1 WHERE id = 1;

PROMPT
PROMPT >>> 1단계 완료. 터미널2에서 S03_deadlock_b.sql 을 실행하고,
PROMPT >>> 그쪽 1단계가 끝나면 아래를 이 창에 붙여넣을 것:
PROMPT
PROMPT     UPDATE alertlab.dl_test SET v = v + 1 WHERE id = 2;
PROMPT
PROMPT >>> 붙여넣으면 응답 없이 대기한다. 정상이다.
PROMPT >>> 그 다음 터미널2에서 2단계를 붙여넣으면 한쪽에 ORA-00060 이 뜬다.
PROMPT >>> 데드락 확인 후 양쪽에서 ROLLBACK; 하고 아래 마커를 남긴다:
PROMPT
PROMPT     EXEC DBMS_SYSTEM.KSDWRT(2, '### S03 END');
PROMPT
