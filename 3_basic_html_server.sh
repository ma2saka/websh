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
DOCUMENT_ROOT="${2:-"`pwd`/public_html_v3"}"
function handle_get()
{
	local path
	path="$1"
	if [ "${path}" = "/" ]
	then
		path="index.html"
	fi
	
	FILE_PATH="${DOCUMENT_ROOT}/${path}"
	test -e ${FILE_PATH} &&
	case "${path}" in
		*.htm | *.html)
			echo -e "HTTP/1.0 200 OK"
			echo -e "Content-Type: text/html"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*.png)
			echo -e "HTTP/1.0 200 OK"
			echo -e "Content-Type: image/png"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*)
		;;
	esac
	echo -e "HTTP/1.0 404 Not Found"
	echo -e "Content-Type: text/plain"
	echo
	echo '404 not found.'
	return 1
}

function handle()
{
	local method path
	method="$1"
	path="$2"

	# GET アクセスのみを許容する
    if [ ! "${method}" = "GET" ]
	then
		echo -e "HTTP/1.0 400 Bad Request :-)"
		echo -e "Content-Type: text/plain"
		echo
		echo '400 bad request.'
		return 1
	fi

	handle_get "${path}"
	return $?
}

function server()
{
    # リクエストライン読み込み
	IFS=' '
	read -u ${FD} "method" "path" "protocol"

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
	
	# handle 関数で実体を処理
	handle "${method}" "${path}" 

	if [ $? -eq 0 ]
	then
		# 200 レスポンスを返した場合、アクセスログ出力
		echo "${HEADERS[Host]}; $(date "+${DATE_FORMAT}"); ${method}; ${path}" >&2
	else
		# 200 レスポンスを返した場合、アクセスログ出力
		echo "process failed : ${HEADERS[Host]}; $(date "+${DATE_FORMAT}"); ${method}; ${path}" >&2
	fi

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
