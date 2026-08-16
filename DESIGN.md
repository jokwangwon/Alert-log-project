# 이벤트 분류기 설계 노트

2026-08-06 코퍼스 수집 후 정리. 직접 구현하기 위한 설계 문서.

실제 관찰 기록은 `corpus/manifest.yaml`, 규칙은 `event_dict.yaml` 에 있다.
이 문서는 **왜 그렇게 만들었는지** 만 다룬다.

---

## 1. 파일 3개의 역할

```
event_dict.yaml        규칙   (데이터)
classify.py            엔진   (로직)
corpus/manifest.yaml   정답지 (검증)
```

핵심 설계는 **규칙을 코드에서 분리한 것**이다.
새 로그에서 미분류가 나오면 YAML 만 고치면 되고 코드는 안 건드린다.
사전이 코드 수정 없이 자란다.

실제로 0주차 로그(`alert_ora19c.log`)를 돌려 미분류 7줄이 나왔을 때
YAML 에 패턴 4개만 추가해서 100% 로 만들었다.

`parse.py` 는 버리지 않는다. `parse_blocks` 는 여전히 유효하다.
다만 **블록은 "이벤트"가 아니라 "시간 묶음"** 이라는 것으로 역할이 축소된다.
이벤트 분류는 그 위에 얹는 별개의 층이다.

---

## 2. 설계 결정 5개와 그 근거

각 결정마다 어떤 관찰이 그것을 강제했는지가 있다.
근거를 알아야 나중에 바꿀지 말지 판단할 수 있다.

### ① 분류 단위는 블록이 아니라 줄

- **S03**: 하나의 에러(`Errors in file` + `ORA-00060`)가 **두 블록**에 걸쳤다. 78ms 차이.
- **S04**: 한 블록에 **네 이벤트**가 들어갔다.
  (ORA-1653 / 별개 명령 / 결과 상세 / Completed:) — 그 블록 하나가 1.35초를 담았다.

블록 하나에 라벨 하나를 붙이는 것이 불가능하다.
→ `블록 : 이벤트 = 1 : N`

### ② 2단계로 나눈다 (role → event)

코퍼스 1,852줄 중 실제 signal 은 438줄(24%)뿐이다.
나머지 76% 는 타임스탬프·노이즈·연속줄이다.
**먼저 걷어내야 사전이 작아진다.**
한 단계로 하면 47종이 아니라 300종을 정의해야 한다.

### ③ 첫 매치가 이긴다. 순서가 곧 우선순위

구체적인 규칙이 일반적인 규칙보다 **앞**에 있어야 한다.

실제로 이걸 틀렸다. `fault.ora` (`^ORA-\d+:`) 를 목록 중간에 뒀더니
`space.extend_fail`, `space.fra_warning` 같은 구체적 규칙을 전부 먹었다.
커버리지는 100% 인데 오분류였다.
→ `fault.ora` 를 맨 뒤로 옮겨 "최후 수단" 으로 만들었다.

**커버리지 100% 가 정확도 100% 를 뜻하지 않는다.**

### ④ severity 는 사전에 박는다. 추론하지 않는다

- **ORA 코드로 못 정한다**: `Stuck archiver condition declared` (치명적) 에 코드가 없다.
  결정적인 줄에 코드가 없는 사례가 4건 나왔다.
- **키워드로 못 정한다**: `Archival stopped` 가 정상 종료 과정에 나온다 (S07).
  `Archiving is disabled`, `Process termination requested` 도 마찬가지다.
  키워드로 심각도를 매기면 모든 정상 종료가 오탐이 된다.

그래서 규칙마다 severity 를 사람이 직접 쓴다. 자동 판정 로직을 두지 않는다.

### ⑤ ORA 코드는 정규화하고, 줄 머리에서만 잡는다

- **정규화**: `ORA-1157` 과 `ORA-01157` 이 **같은 블록 안에** 공존한다 (S05).
  스택 안의 것은 패딩이 있고, `signalled during:` 쪽은 없다.
  정규화하지 않으면 같은 에러를 두 번 센다.
  → `f"ORA-{int(n):05d}"`
- **줄 머리 제한**: ORA-00060 본문에 `Troubleshooting ORA-60 Errors` 라는 문구가 있다.
  아무 데서나 잡으면 한 줄에서 코드 2개를 잡아 오탐이 난다.

---

## 3. 자료구조

### 사전

두 개의 **리스트**. dict 이 아니라 리스트인 이유는 **순서가 의미를 갖기** 때문이다.

```yaml
roles:
  - id: timestamp
    match: '정규식 하나'
  - id: noise
    any: ['정규식', '정규식', ...]    # 여러 개 중 하나라도 맞으면
events:
  - id: archive.stuck_declared
    severity: critical
    role: open                # open | close | atomic
    pair_key: stuck_archiver
    match: '...'
```

`role` / `pair_key` 는 **아직 쓰지 않는 필드**다.
2주차 상관분석(명령↔결과 짝짓기)에서 쓸 자리를 미리 잡아둔 것이다.

S08 의 crash recovery 가 3중 중첩이라 평평한 짝짓기로는 부족하다는 것도 확인해뒀다:

```
Beginning crash recovery of 1 threads      open
  Started redo scan                          open
  Completed redo scan                        close
  Started redo application at                open
  Completed redo application of 4.39MB       close
Completed crash recovery at                close
```

### 분류 결과

줄 하나당 튜플 하나:

```
(role, event_id, severity)

('noise',        None,                     'noise')
('continuation', None,                     None)
('signal',       'archive.stuck_declared', 'critical')
('signal',       None,                     None)      ← 미분류
```

---

## 4. 알고리즘

```
사전 로드:
    YAML 읽기
    각 항목의 match / any 를 정규식 리스트로 컴파일
    → [(id, 항목, [패턴...]), ...] 형태로 순서 유지

한 줄 분류(line):
    for (id, 항목, 패턴들) in roles:
        if 패턴 중 하나라도 매치:
            noise 면 severity='noise', 아니면 None
            return

    # roles 어디에도 안 걸렸다 = signal 이다
    for (id, 항목, 패턴들) in events:
        if 패턴 중 하나라도 매치:
            return ('signal', id, 항목의 severity)

    return ('signal', None, None)      # 미분류
```

**구조의 핵심**: `roles` 를 통과하면 자동으로 signal 이 된다.
signal 을 판정하는 규칙이 따로 없다 — "나머지 전부" 다.
그래서 1단계 커버리지는 항상 100% 이고, **미분류는 2단계에서만 생긴다.**

### 구간 라벨 (마커 파싱)

```
구간라벨(lines):
    현재 = None
    각 줄에 대해:
        '### Snn BEGIN' 이면 → 현재 = Snn
        '### Snn END'   이면 → 현재 = None
        아니면 → 그 줄의 라벨 = 현재

    S00 은 BEGIN 마커가 없다 (DB 가 꺼져 있어 못 박음)
    → 로그 시작부터 첫 마커까지를 S00 으로 따로 채운다
```

마커의 한계도 알고 있어야 한다. 마커는 이벤트 경계를 정확히 자르지 못한다.
`STARTUP` 이 반환된 뒤에도 Oracle 은 2분 가까이 기동 기록을 계속 쓴다.
그래서 전체의 20% 가 미라벨 구간으로 남았다.
(`corpus/manifest.yaml` 의 `labeling_limitation` 참조)

---

## 5. 구현 순서

단계마다 **확인할 수치**를 정해두는 것이 중요하다.
안 그러면 어디서 틀렸는지 모른다.

| 단계 | 만들 것 | 확인 |
| --- | --- | --- |
| 1 | YAML 로드 + 정규식 컴파일 | roles 6개, events 47개 출력 |
| 2 | `classify_line()` 하나 | 손으로 고른 10줄로 테스트 |
| 3 | 전체 순회 + role 집계 | **역할별 합계 == 총 줄 수** |
| 4 | `--unknown` 출력 | 0 이 될 때까지 YAML 보강 |
| 5 | 구간 라벨 + severity 집계 | manifest 예측 9개와 대조 |

3단계의 "합계 == 총 줄 수" 를 반드시 확인한다.
어떤 줄이 두 번 세지거나 빠지면 여기서 걸린다.

5단계까지 가면 정답지와 자동 대조가 되므로 그것이 진짜 완료 지점이다.

### 도달해야 할 결과

```
                    코퍼스(1,852줄)    0주차 로그(502줄)
timestamp              24.9%              24.5%
continuation           13.0%              10.8%
noise                  36.8%              46.0%
signal                 23.7%              17.3%
--------------------------------------------------
커버리지                100%               100%
```

시나리오별 최고 severity 가 manifest 예측과 전부 일치해야 한다:

| 구간 | 예측 | 산출 |
| --- | --- | --- |
| S00 | warn (정정됨) | warn |
| S01 | info, maybe warn | warn |
| S02 | info | info |
| S03 | error | error |
| S04 | error | error |
| S05 | critical | critical |
| S06 | critical | critical |
| S07 | notice, crash recovery 0건 | notice, 0건 |
| S08 | warn | warn |

최종 성과 지표:

> **1,852줄 → 사람이 봐야 할 critical/error 34줄 (1.8%)**

---

## 6. 공부할 것

### 정규식 (오늘 쓴 것만)

- `^` 줄 시작 고정 — 거의 모든 규칙이 쓴다. 이유는 ORA-60 오탐 사례
- `\d{3,5}` 자릿수 범위
- `\s+\S` 들여쓰기 판정
- `re.compile()` 미리 컴파일하는 이유
  (1,852줄 × 53규칙 = 매번 컴파일하면 느리다)

### 실제로 밟은 함정 3개

1. `\w` 는 `$` 를 안 잡는다 → `AUD$UNIFIED` 가 안 걸렸다
2. 경로 정규식 `/[\w./]+` 가 `cannot identify/lock` 의 `/lock` 을 먹었다
3. 규칙 순서를 잘못 배치해 일반 규칙이 특수 규칙을 먹었다

### 파이썬

- `yaml.safe_load()` — `load()` 가 아니라 `safe_load()` 인 이유
- `collections.Counter` — 집계
- 리스트 순서가 의미를 갖는 자료구조 설계 (dict 이 아닌 이유)

---

## 7. 남은 일

- **연속 줄 판정의 일반 규칙이 없다.**
  대부분은 들여쓰기로 잡히지만, 한 문장이 들여쓰기 없이 여러 줄로 접히는 경우가 있다.
  `"...used. This is a"` → `"user-specified limit on the amount..."`
  "소문자로 시작하면 연속" 규칙도 못 쓴다. 독립 줄인데 소문자로 시작하는 것들이 있다
  (`stopping change tracking`, `starting up 1 dispatcher(s)`).
  → 현재는 알려진 접힘 문구를 명시적으로 나열하고 있다.

- **`role` / `pair_key` 가 아직 안 쓰인다.** 2주차 상관분석에서 쓴다.

- **`parse.py` 의 `has_ora` 는 무효다.** 결정적인 줄에 ORA 코드가 없는 사례가 4건이다.

- **도구가 답할 수 없는 질문 2개** (범위 한계, 문서에 명시할 것):
  - 백업의 성공/실패 — 데이터파일 백업은 alert log 에 남지 않는다 (S02)
  - 시도했다가 실패한 명령 — 파싱 단계에서 거부되면 기록되지 않는다 (S04)
