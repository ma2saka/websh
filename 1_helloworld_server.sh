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

LISTEN_PORT=${1:-"10080"}

function server()
{
    # リクエストライン読み込み
	read -u ${FD}

    # HTTP ヘッダ出力
	echo -e "HTTP/1.0 200 OK"
	echo -e "Content-Type: text/plain"
	echo

	# Hello World 出力
	echo "hello world"

    # HTTP ヘッダ終了まで読んで残りを破棄。
	while read "line"
	do
		if [ "$(echo $line | tr -d "\r")" = "" ]
		then
			break
		fi
	done <&${FD}
}


#----------------------------------------------
# サーバの実行
#----------------------------------------------
echo "starting server on localhost:${LISTEN_PORT}"
	server | nc -k -l localhost ${LISTEN_PORT} >&${FD}
