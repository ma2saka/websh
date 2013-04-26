#!/usr/local/bin/bash

#----------------------------------------------
# 名前付きパイプの作成
#----------------------------------------------
PIPE_PATH=/tmp/server.$$
if [ ! -e "${PIPE_PATH}" ];
then
	mkfifo "${PIPE_PATH}"
fi
exec {FD}<>"${PIPE_PATH}"
trap "test -e ${PIPE_PATH} && rm -f ${PIPE_PATH};exit" 0 HUP INT QUIT

#----------------------------------------------
# 定数と関数の定義
#----------------------------------------------

DATE_FORMAT='%Y/%m/%d %p %I:%M:%S'
LISTEN_PORT=${1:-"10080"}

function server()
{
    # リクエストライン読み込み
	IFS=' '
	read -u ${FD} "method" "path" "protocol"

    # HTTP ヘッダ出力
	echo -e "HTTP/1.0 200 OK"
	echo -e "Content-Type: text/plain"
	echo

	# Hello World 出力
	echo "hello world (`date "+${DATE_FORMAT}"`)"

	declare -A HEADERS
    # HTTP ヘッダ終了まで読んで残りを破棄。
	IFS=": "
	while read "key" "value"
	do
		if [ "$value" = "" ]
		then
			break
		fi

		# \r の削除方法がイマイチ（${value%%\\r*} ではまずい？）
		HEADERS[${key}]=$(echo ${value} | tr -d "\r")
	done <&${FD}

    # アクセスログ出力
	echo "${HEADERS[Host]}; $(date "+${DATE_FORMAT}"); ${method}; ${path}" >&2
	
	# 本文にパスを出力
	echo "${path}"
	unset HEADERS

}


#----------------------------------------------
# サーバの実行
#----------------------------------------------
echo "starting server on localhost:${LISTEN_PORT}"
while true
do
	server | nc -l localhost ${LISTEN_PORT} >&${FD}
done
