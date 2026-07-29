####`ALTER SYSTEM SWITCH LOGFILE;`
```
2026-07-27T19:01:43.778212+09:00
Beginning log switch checkpoint up to RBA [0x9e.2.10], SCN: 13058389
2026-07-27T19:01:43.778325+09:00
Thread 1 advanced to log sequence 158 (LGWR switch)
  Current log# 2 seq# 158 mem# 0: /u01/app/oracle/oradata/ORA19C/redo02.log
2026-07-27T19:01:44.464330+09:00
ARC2 (PID:2319): Archived Log entry 261 added for T-1.S-157 ID 0x4cc2c1cf LAD:1
```

####`ALTER SYSTEM CHECKPOINT;`
```
2026-07-27T19:03:17.060909+09:00
Beginning global checkpoint up to RBA [0x9e.5f.10], SCN: 13058585
Completed checkpoint up to RBA [0x9e.5f.10], SCN: 13058585
Completed checkpoint up to RBA [0x9e.2.10], SCN: 13058389
```

####`ALTER SYSTEM SET open_cursors=200;`
```
2026-07-27T19:04:30.581049+09:00
ALTER SYSTEM SET open_cursors=200 SCOPE=BOTH;
```

####`ALTER SYSTEM SET open_cursors=100;`
```
2026-07-27T19:04:57.571140+09:00
ALTER SYSTEM SET open_cursors=100 SCOPE=BOTH;
```

####`CREATE TABLESPACE test_ts DATAFILE SIZE 20M AUTOEXTEND ON;`
```
2026-07-27T19:06:55.586596+09:00
CREATE TABLESPACE test_ts DATAFILE SIZE 20M AUTOEXTEND ON
Completed: CREATE TABLESPACE test_ts DATAFILE SIZE 20M AUTOEXTEND ON
```

####`ALTER TABLESPACE test_ts OFFLINE;`
```
2026-07-27T19:07:22.036832+09:00
ALTER TABLESPACE test_ts OFFLINE
Completed: ALTER TABLESPACE test_ts OFFLINE
```

#### (명령 없음 — 백그라운드 자동 발생)
```
2026-07-27T19:14:34.887043+09:00
Control autobackup written to DISK device
handle '/home/oracle/clone/c-1284554106-20260727-00'
```
- 내가 친 명령이 아님. RMAN 컨트롤파일 자동백업이 스스로 기록
- 트리거는 19:06~19:07의 구조 변경(CREATE TABLESPACE / OFFLINE)인데 **7분 뒤에 기록됨**
- → 시간 순서만으로 인과를 추정하면 안 된다

####`ALTER DATABASE DATAFILE '...test_ts...' RESIZE 40M;`
```
2026-07-27T19:14:50.099172+09:00
ALTER DATABASE DATAFILE '...test_ts...' RESIZE 40M
ORA-7345 signalled during: ALTER DATABASE DATAFILE '...test_ts...' RESIZE 40M...
```

####`ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORA19C/datafile/o1_mf_test_ts_o6gcfzm1_.dbf' RESIZE 40M;`
```
2026-07-27T19:18:36.658372+09:00
ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORA19C/datafile/o1_mf_test_ts_o6gcfzm1_.dbf' RESIZE 40M
ORA-376 signalled during: ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORA19C/datafile/o1_mf_test_ts_o6gcfzm1_.dbf' RESIZE 40M...
2026-07-27T19:18:36.899594+09:00
Checker run found 2 new persistent data failures
```


####`ALTER TABLESPACE test_ts ONLINE;`
```
2026-07-27T19:19:35.372592+09:00
ALTER TABLESPACE test_ts ONLINE
Completed: ALTER TABLESPACE test_ts ONLINE
```

#### (명령 없음 — 백그라운드) 컨트롤파일 자동백업 2회차
```
2026-07-27T19:24:38.271676+09:00
Control autobackup written to DISK device

handle '/home/oracle/clone/c-1284554106-20260727-01'
```
- 19:19 `ALTER TABLESPACE ONLINE`(구조 변경)이 트리거. 이번에도 약 5분 뒤 기록
- 파일명 순번이 `-00` → `-01`로 증가 → 구조 변경마다 반복 발생
- **블록 중간에 빈 줄이 들어감** (1회차엔 없었음)

#### (명령 없음 — 백그라운드) 증분 체크포인트
```
2026-07-27T19:24:47.009853+09:00
Incremental checkpoint up to RBA [0x9e.6e3.0], current log tail at RBA [0x9e.80b.0]
```
- 주기적으로 자동 발생 (`log_checkpoints_to_alert=TRUE` 설정 때문에 기록됨)
- 로그의 상당 부분을 차지하는 정보성 노이즈

#### `ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORA19C/datafile/o1_mf_test_ts_o6gcfzm1_.dbf' RESIZE 40M;`
```
2026-07-27T19:28:04.850685+09:00
ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORA19C/datafile/o1_mf_test_ts_o6gcfzm1_.dbf' RESIZE 40M
2026-07-27T19:28:05.274566+09:00
Resize operation completed for file# 10, old size 20480K, new size 40960K
Completed: ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORA19C/datafile/o1_mf_test_ts_o6gcfzm1_.dbf' RESIZE 40M
```
- 앞선 실패(ORA-376)와 **같은 명령의 성공 버전**
- 성공: 명령 원문 → 결과 상세 → `Completed:` / 실패: 명령 원문 → `ORA-nnn signalled during:`
- 명령과 완료가 **서로 다른 타임스탬프 블록**에 걸침 (0.4초 차)