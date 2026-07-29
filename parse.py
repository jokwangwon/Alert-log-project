import re
import sys

TS = re.compile(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') # timestamp pattern: YYYY-MM-DDTHH:MM:SS
ORA = re.compile(r'ORA-\d{3,5}') # ORA error code pattern: ORA-XXXXX

def is_timestamp(line, ts_pattern=TS):
  return ts_pattern.match(line)

def parse_blocks(lines, ts_pattern=TS, ora_pattern=ORA):
  """
  alert log를 타임스탬프 단위 블록으로 나눈다

  Args:
    lines (list): 로그 줄 
    ts_pattern (re.Pattern): 타임스탬프 패턴
    ora_pattern (re.Pattern): ORA 에러 코드 패턴

  Returns:
    list[dict]: 타임스탬프 단위 블록 리스트
        {
          "timestamp": str,        # 블록 시작 타임스탬프 줄
          "ora_codes": list[str],  # 블록에서 찾은 ORA 코드
          "has_ora": bool,         # ORA 코드 포함 여부
          "message": str,          # 대표 메시지 1줄
          "raw_lines": list[str],  # 원문 줄들
        }
  """

  blocks = []
  current = None

  for line in lines:
    line = line.rstrip() # 왼쪽 들여쓰기는 유지해야함으로 rstrip()만 사용
    if not line:
      continue

    if is_timestamp(line, ts_pattern):
      if current is not None:
        blocks.append(current)
      current = {"timestamp": line, "ora_codes": [], "has_ora": False, "message": "", "raw_lines": []}
    else:
      if current is None:
        continue
      current["raw_lines"].append(line)
      if not current["message"]:
        current["message"] = line

      found_ora_codes = ora_pattern.findall(line)
      
      if found_ora_codes:
        current["ora_codes"].extend(found_ora_codes)
        current["has_ora"] = True
  if current is not None:
    blocks.append(current)
  return blocks

if __name__ == "__main__":
  with open(sys.argv[1], 'r', encoding='utf-8') as f:
    file = f.read()
    blocks = parse_blocks(file.strip().splitlines())

    ora_count = 0
    for block in blocks:
      if block["ora_codes"]:
        print(f"\ntimestamp: {block['timestamp']}\nORA codes: {block['ora_codes']}\nMessage: {block['message']}")
        ora_count += 1

    print(f"\n총 {len(blocks)}개 중 ORA 코드가 포함된 블록: {ora_count}개")