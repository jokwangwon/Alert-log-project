import re
import sys
import collections

import yaml

DICT_PATH = "event_dict.yaml"

MARKER = re.compile(r'^### (S\d\d) (BEGIN|END)') # corpus marker: ### Snn BEGIN|END
ORA_HEAD = re.compile(r'^ORA-(\d{3,5})\b')      # ORA code at line head: ORA-XXXXX

SEVERITY_ORDER = ["critical", "error", "warn", "notice", "info", "noise"]
ROLE_ORDER = ["timestamp", "marker", "blank", "continuation", "noise", "signal"]


def normalize_ora(code):
  """ORA 코드를 5자리로 통일한다

  같은 에러가 ORA-1157 과 ORA-01157 두 표기로 쓰인다.
  정규화하지 않으면 같은 에러를 두 번 센다.

  Args:
    code (str): 숫자 부분만. 예 "1157"

  Returns:
    str: "ORA-01157"
  """
  return "ORA-%05d" % int(code)


def find_ora_codes(line):
  """줄 머리의 ORA 코드만 찾는다

  줄 어디든 찾으면 오탐이 난다. ORA-00060 메시지 본문에
  "Troubleshooting ORA-60 Errors" 라는 문구가 들어 있다.

  Args:
    line (str): 로그 줄

  Returns:
    list[str]: 정규화된 ORA 코드. 없으면 빈 리스트
  """
  stripped = line.strip()

  found = ORA_HEAD.match(stripped)
  if found:
    return [normalize_ora(found.group(1))]
  return []


def compile_rules(entries):
  """사전 항목의 정규식을 미리 컴파일한다

  match 는 패턴 하나, any 는 여러 개 중 하나라도 맞으면 된다.
  리스트 순서를 그대로 유지해야 한다. 순서가 곧 우선순위다.

  Args:
    entries (list[dict]): event_dict.yaml 의 roles 또는 events

  Returns:
    list[tuple]: (id, 항목, [컴파일된 패턴])
  """
  rules = []

  for entry in entries:
    patterns = []
    if 'match' in entry:
      patterns.append(entry['match'])
    patterns.extend(entry.get('any', []))

    rules.append((entry['id'], entry, [re.compile(p) for p in patterns]))
  return rules


def load_dict(path=DICT_PATH):
  """이벤트 사전을 읽어 컴파일한다

  Args:
    path (str): 사전 파일 경로

  Returns:
    tuple: (roles 규칙, events 규칙)
  """
  with open(path, 'r', encoding='utf-8') as f:
    dictionary = yaml.safe_load(f)
  return compile_rules(dictionary['roles']), compile_rules(dictionary['events'])


def classify_line(line, roles, events):
  """한 줄을 역할과 이벤트 타입으로 분류한다

  1단계 roles 에서 안 걸리면 signal 이다. signal 을 판정하는 규칙은 따로 없고
  나머지 전부가 signal 이다. 그래서 미분류는 2단계에서만 생긴다.

  Args:
    line (str): 로그 줄
    roles (list[tuple]): compile_rules 로 만든 roles 규칙
    events (list[tuple]): compile_rules 로 만든 events 규칙

  Returns:
    tuple: (role, event_id, severity). 미분류면 ('signal', None, None)
  """
  for role_id, entry, patterns in roles:
    if any(p.search(line) for p in patterns):
      if role_id == 'noise':
        return 'noise', None, 'noise'
      return role_id, None, None

  for event_id, entry, patterns in events:
    if any(p.search(line) for p in patterns):
      return 'signal', event_id, entry.get('severity', 'info')

  return 'signal', None, None


def label_regions(lines):
  """마커로 시나리오 구간 라벨을 만든다

  S00 만 BEGIN 마커가 없다. DB 가 꺼진 상태라 마커를 박을 수 없어서
  로그 시작부터 첫 마커까지가 S00 구간이다.

  Args:
    lines (list[str]): 로그 줄

  Returns:
    list: 줄마다 시나리오 id. 구간 밖이면 None
  """
  labels = [None] * len(lines)
  current = None
  has_marker = False

  for i, line in enumerate(lines):
    found = MARKER.match(line)
    if found:
      has_marker = True
      scenario_id, kind = found.groups()
      current = scenario_id if kind == 'BEGIN' else None
      continue
    labels[i] = current

  if has_marker:
    for i, line in enumerate(lines):
      if MARKER.match(line):
        break
      labels[i] = 'S00'
  return labels


def classify_file(path, roles, events):
  """파일 전체를 분류한다

  Args:
    path (str): 로그 파일 경로
    roles (list[tuple]): roles 규칙
    events (list[tuple]): events 규칙

  Returns:
    dict: 집계 결과
        {
          "total": int,                    # 전체 줄 수
          "roles": Counter,                # 역할별 줄 수
          "events": Counter,               # 이벤트 타입별 줄 수
          "severity": Counter,             # severity 별 줄 수
          "ora": Counter,                  # 정규화된 ORA 코드별 개수
          "unknown": list[tuple],          # (줄번호, 구간, 원문)
        }
  """
  with open(path, 'r', encoding='utf-8') as f:
    lines = f.read().splitlines()

  labels = label_regions(lines)
  result = {
    "total": len(lines),
    "roles": collections.Counter(),
    "events": collections.Counter(),
    "severity": collections.Counter(),
    "ora": collections.Counter(),
    "unknown": [],
  }

  for i, line in enumerate(lines):
    role, event_id, severity = classify_line(line, roles, events)
    result["roles"][role] += 1

    if role == 'signal':
      if event_id:
        result["events"][event_id] += 1
        result["severity"][severity] += 1
      else:
        result["unknown"].append((i + 1, labels[i], line))

    for code in find_ora_codes(line):
      result["ora"][code] += 1
  return result


def print_summary(path, result):
  """커버리지 요약을 출력한다"""
  total = result["total"]
  signal = result["roles"].get('signal', 0)
  unknown = len(result["unknown"])
  classified = total - unknown

  print(f"파일: {path}")
  print(f"전체 {total}줄\n")

  print("-- 1단계: 줄 역할 --")
  for role in ROLE_ORDER:
    count = result["roles"].get(role, 0)
    print(f"  {role:<14} {count:5d}  ({count / total * 100:4.1f}%)")

  print(f"\n-- 2단계: signal {signal}줄 중 --")
  print(f"  분류됨         {signal - unknown:5d}  ({(signal - unknown) / signal * 100:4.1f}%)")
  print(f"  미분류         {unknown:5d}  ({unknown / signal * 100:4.1f}%)")

  print(f"\n-- 전체 커버리지 {classified}/{total} = {classified / total * 100:.1f}% --")

  print("\n-- severity 분포 --")
  for severity in SEVERITY_ORDER:
    if result["severity"].get(severity):
      print(f"  {severity:<9} {result['severity'][severity]:5d}")

  print("\n-- ORA 코드 (정규화 후) --")
  for code, count in result["ora"].most_common(15):
    print(f"  {code}  {count}")


def print_unknown(result):
  """미분류 줄만 출력한다. 사전을 보강할 때 쓴다"""
  print(f"미분류 {len(result['unknown'])}줄\n")

  for line_no, label, line in result["unknown"]:
    print(f"{line_no:5d} [{label or '_gap':<5}] {line[:110]}")


def print_events(result):
  """이벤트 타입별 집계를 출력한다"""
  print("이벤트 타입별 집계\n")

  for event_id, count in result["events"].most_common():
    print(f"{count:5d}  {event_id}")


if __name__ == "__main__":
  # 사용: python3 classify.py <로그파일> [--unknown | --events]
  log_path = sys.argv[1] if len(sys.argv) > 1 else "alert_corpus_20260806.log"
  mode = sys.argv[2] if len(sys.argv) > 2 else ""

  roles, events = load_dict()
  result = classify_file(log_path, roles, events)

  if mode == "--unknown":
    print_unknown(result)
  elif mode == "--events":
    print_events(result)
  else:
    print_summary(log_path, result)
