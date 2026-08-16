-- S03 세션 B : 데드락 유발 (반대 순서로 잠근다)
-- 실행 순서는 S03_deadlock_a.sql 주석 참조. 이 파일은 터미널2에서 실행한다.

SET ECHO ON
WHENEVER SQLERROR CONTINUE

-- 1단계: 2번 행을 잠근다 (A가 1번을 잡은 상태여야 한다)
UPDATE alertlab.dl_test SET v = v + 1 WHERE id = 2;

PROMPT
PROMPT >>> 1단계 완료. 터미널1에서 2단계를 붙여넣어 대기 상태로 만든 뒤,
PROMPT >>> 아래를 이 창에 붙여넣을 것:
PROMPT
PROMPT     UPDATE alertlab.dl_test SET v = v + 1 WHERE id = 1;
PROMPT
PROMPT >>> 몇 초 뒤 ORA-00060 이 발생한다. alert log 에도 기록된다.
PROMPT >>> 확인 후 ROLLBACK; 하고 터미널1에서 END 마커를 남길 것.
PROMPT
