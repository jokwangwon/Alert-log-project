# 스터디 진행 기록

Oracle alert log 분석기를 만드는 4주 스터디 기록.

새 주차가 시작되면 `study_log/_template.md`를 복사해 `study_log/week-NN.md`로 만들고 채운다.

## 공통 규칙

- 목요일까지 그 주 작업을 PR로 올리기 → 금요일까지 지정된 상대 PR에 코멘트 1개 이상
- 모임에서 스탠드업 3문장: 하겠다고 한 것 / 실제 한 것 / 다음 주 할 것
- 막히면 `#질문` 채널에

## 진행 현황

| 주차 | 기간 | 주제 | 제출물 | 기록 |
| --- | --- | --- | --- | --- |
| 0 | ~ 07-31 | 사전 준비 | — | [week-00](study_log/week-00.md) |
| 1 | 08-01 ~ 08-08 | 계획 + 첫 실행 | 설계서 / `main.py` / PR | [week-01](study_log/week-01.md) |
| 2 | 08-08 ~ 08-15 | 구조화 | 집계 · JSON · 필터 중 택1 | [week-02](study_log/week-02.md) |
| 3 | 08-15 ~ 08-29 | 판단 한 겹 | 룰 or AI 분류 + README | |
| 4 | 08-29 | 마무리 · 발표 | 데모 5분 | |

## 구성

| 파일 | 내용 |
| --- | --- |
| `parse.py` | alert log 를 타임스탬프 단위 블록으로 나눈다 (0주차) |
| `event_dict.yaml` | 이벤트 사전. 줄 역할 6종 + 이벤트 타입 47종 |
| `classify.py` | 사전을 적용해 줄을 분류하고 커버리지를 집계한다 |
| `DESIGN.md` | 설계 노트. 각 결정의 근거 |
| `corpus/` | 코퍼스 생성 시나리오와 정답지(`manifest.yaml`) |
| `alert_corpus_20260806.log` | 라벨이 박힌 코퍼스 1,852줄 |

```
python3 classify.py alert_corpus_20260806.log             # 커버리지 요약
python3 classify.py alert_corpus_20260806.log --unknown   # 미분류 줄만
python3 classify.py alert_corpus_20260806.log --events    # 이벤트 타입별 집계
```

## 범위 (시즌 1)

- 프론트 · 웹 화면은 범위 밖. 시각화가 필요하면 CSV 또는 그래프 한 장
- DB · 서버 · 실시간 감시도 범위 밖

alert log 만으로는 답할 수 없는 것 (2주차까지 확인된 한계)

- 백업의 성공/실패 — 데이터파일 백업은 alert log 에 기록되지 않는다
- 시도했다가 실패한 명령 — 파싱 단계에서 거부되면 기록되지 않는다
