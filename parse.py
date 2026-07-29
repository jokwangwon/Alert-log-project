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
    list: 타임스탬프 단위 블록 리스트
        {"timestamp": str, "body": list, "ora_codes": list}
  """

  blocks = []
  current = None

  for line in lines:
    line = line.rstrip()
    if not line:
      continue

    if is_timestamp(line, ts_pattern):
      if current != None:
        blocks.append(current)
      current = {"timestamp": line, "body": [], "ora_codes": []}
    else:
      if current is None:
        continue
      current["body"].append(line)
      if ora_pattern.findall(line):
        current["ora_codes"].extend(ora_pattern.findall(line))
  if current != None:
    blocks.append(current)
  return blocks

if __name__ == "__main__":
  with open(sys.argv[1], 'r', encoding='utf-8') as f:
    file = f.read()
    blocks = parse_blocks(file.strip().splitlines())

    for block in blocks:
      if block["ora_codes"]:
        print(block)