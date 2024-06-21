#!/bin/bash
# upload_package - uploads an iControl LX package and verifies installation

# Provide package name here
# Note! the package must have already been downloaded to the /var/config/rest/downloads directory
FN="/var/config/rest/downloads/f5-telemetry-1.32.0-2.noarch.rpm"

# Variables
CREDS=admin:admin
IP=localhost:8100
LEN=$(wc -c $FN | cut -f 1 -d ' ')
RANGE=$((LEN - 1))/$LEN
DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"$FN\"}"

echo "uploading package file..."
curl -u $CREDS http://$IP/mgmt/shared/file-transfer/uploads/$FN -H 'Content-Type: application/octet-stream' -H "Content-Range: 0-$RANGE" -H "Content-Length: $LEN" -H 'Connection: keep-alive' --data-binary @$FN 2>/dev/null 1>/dev/null

echo "installing TS..."
curl -u $CREDS "http://$IP/mgmt/shared/iapp/package-management-tasks" -H "Origin: https://$IP" -H 'Content-Type: application/json;charset=UTF-8' --data $DATA > ./.curl.out 2> ./.curl.err

echo "checking for install success..."
if
   [ `cat ./.curl.out | grep '"status":"CREATED"'` ]
then
   ID=`cat ./.curl.out | jq '.id' | tr -d '"'`
   echo "task id is: $ID"
fi

for i in {1..20}; do
   echo "   trying ($i) of (20)"
   curl -su $CREDS --retry 1 --connect-timeout 5 "http://$IP/mgmt/shared/iapp/package-management-tasks/$ID" > ./.curl.out 2> ./.curl.err
   STATUS=`cat ./.curl.out | jq '.status' | tr -d '"'`
   case "$STATUS" in
        "FAILED")
                echo "Installation Failed."
                ERRMSG=`cat ./.curl.out | jq '.errorMessage' | tr -d '"'`
                echo "Error: $ERRMSG"
                exit 1
        ;;

        "FINISHED")
                echo "Installation Completed."
                exit 0
        ;;
        *)
                echo "waiting..."
                sleep 5
        ;;
   esac
done
echo "Unknown Error."
exit 1
