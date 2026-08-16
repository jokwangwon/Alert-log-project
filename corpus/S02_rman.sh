#!/bin/bash
# S02 : RMAN 전체 백업
# RMAN은 sqlplus가 아닌 별도 바이너리라 셸 스크립트로 감싼다.
# 노리는 것: backup.autobackup / archive.archived / RMAN 진행 메시지
#
# 실행: bash S02_rman.sh

set -u

mark() {
  sqlplus -s / as sysdba <<SQL
SET FEEDBACK OFF
EXEC DBMS_SYSTEM.KSDWRT(2, '$1');
EXIT
SQL
}

mark '### S02 BEGIN rman-backup'

rman target / <<'EOF'
BACKUP DATABASE;
EOF

sleep 10
mark '### S02 END'

echo ">>> 30초 쉬고 S03 으로"
