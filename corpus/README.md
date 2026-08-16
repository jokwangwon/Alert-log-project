# 코퍼스 생성 절차

라벨이 확정된 alert log를 의도적으로 만들기 위한 시나리오 세트.

## 이렇게 하는 이유

alert log를 분석하는 도구를 만들려면 **정답을 아는 로그**가 필요하다.
"이 줄은 심각한 사건이 맞다/아니다"를 판정할 근거가 없으면 분류기의 정확도를 잴 수 없다.

그래서 로그를 주워오는 대신 **직접 만든다**. 무슨 명령을 언제 실행했는지 알고 있으니
그 결과로 나온 로그 구간의 정답도 안다.

## 전제

1. **VirtualBox 스냅샷을 먼저 찍는다.** S05·S06은 DB를 일부러 망가뜨린다.
2. alert log가 초기화되어 있어야 한다 (`mv alert_ora19c.log alert_ora19c.log.bak-YYYYMMDD`).
3. 모든 스크립트는 `sqlplus / as sysdba` 로 접속해 `@파일명` 으로 실행한다.

## 마커 규약

시나리오 경계를 alert log 안에 직접 써넣는다. 타임스탬프를 따로 기록해
나중에 조인할 필요가 없어진다.

```sql
EXEC DBMS_SYSTEM.KSDWRT(2, '### S01 BEGIN log-switch-x20');
EXEC DBMS_SYSTEM.KSDWRT(2, '### S01 END');
```

- 마커 줄은 `### ` 로 시작한다. 파서는 이 줄을 `_marker` 타입으로 잡아 라벨로 변환하고
  이벤트 집계에서는 제외한다.
- `S00`(최초 기동)만 예외다. DB가 꺼져 있어 BEGIN을 못 박으므로
  **로그 시작 ~ `### S00 END` 까지**가 S00 구간이다.

## 실행 순서

| 순서 | 파일 | 내용 | 위험 |
| --- | --- | --- | --- |
| 0 | `00_setup.sql` | 상태 점검 · 설정 스냅샷 · 테스트 스키마 생성 | 없음 |
| 1 | `S01_logswitch.sql` | log switch 20회 | 없음 |
| 2 | `S02_rman.sh` | RMAN 전체 백업 | 없음 |
| 3 | `S03_deadlock_a.sql` + `_b.sql` | 데드락 (**터미널 2개**) | 없음 |
| 4 | `S04_extend_fail.sql` | 테이블스페이스 확장 실패 | 정리 필요 |
| 5 | `S05_datafile_perm.sql` | 데이터파일 권한 박탈 → 원복 | **원복까지 한 세트** |
| 6 | `S06_fra_full.sql` + `S06_recover.sql` | 아카이브 영역 포화 | **DB 정지. 터미널 2개** |
| 7 | `S07_restart_clean.sql` | 정상 재기동 | 없음 |
| 8 | `S08_restart_abort.sql` | abort 후 재기동 (crash recovery) | 없음 |
| 9 | `99_cleanup.sql` | 테스트 객체 정리 · 파라미터 원복 | 없음 |

**시나리오 사이에 30초 이상 쉰다.** 붙여 실행하면 블록이 뒤엉켜
"어느 명령의 결과인지"를 로그만 보고 판정할 수 없게 된다.
그 판정 가능성이 곧 상관분석의 정답지다.

## 끝나고

```bash
cp /u01/app/oracle/diag/rdbms/ora19c/ora19c/trace/alert_ora19c.log \
   ~/alert_corpus_$(date +%Y%m%d).log
wc -l ~/alert_corpus_*.log
grep -c '^### ' ~/alert_corpus_*.log     # 마커 개수 = 시나리오 경계 수
```

이 파일을 리포지토리로 가져와 `manifest.yaml` 과 대조한다.

## manifest.yaml 의 의미

각 시나리오에 **기대하는 이벤트와 severity를 미리 적어둔 것**이다.
실행 후에 로그를 보고 채우면 그건 정답지가 아니라 관찰 기록이 된다.

기대와 실제가 어긋나는 지점이 가장 값진 발견이다. 예를 들어
`ALTER SYSTEM SET` 은 `Completed:` 를 남기지 않는데, 이런 건
예측을 먼저 적어봐야 드러난다.
