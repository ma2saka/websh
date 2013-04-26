#!/usr/local/bin/bash

#----------------------------------------------
# 定数と関数の定義
#----------------------------------------------

DATE_FORMAT='%Y/%m/%d %p %I:%M:%S'
LISTEN_PORT=${1:-"10080"}
DOCUMENT_ROOT=${2:-"`pwd`/public_html_v5"}

function handle_get()
{
	local path
	path="${1%%\?*}"
	path="${path%%#*}"
	query="${1##*\?}"
	
	if [ "${path##*/}" = "" ]
	then
	    if [ -e "${DOCUMENT_ROOT}/${path}/index.html" ]
		then
			path="${path}/index.html"
		else
			echo -e "HTTP/1.0 200 OK"
			echo -e "Content-Type: text/html"
			echo
			echo "<h1> List of ${path}</h1>"
			echo "<hr/>"
			ls -p "${DOCUMENT_ROOT}/${path}" | while read L; do echo "<a href='${path}${L}'>${L}</a><br>"; done
			exit 0
		fi
	fi

	FILE_PATH="${DOCUMENT_ROOT}/${path}"
	test -e ${FILE_PATH} &&
	case "${path}" in
		*.htm | *.html)
			echo "HTTP/1.0 200 OK"
			echo "Content-Type: text/html"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*.css)
			echo "HTTP/1.0 200 OK"
			echo "Content-Type: text/css"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*.js)
			echo "HTTP/1.0 200 OK"
			echo "Content-Type: text/javascript"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*.jpeg | *.jpg)
			echo "HTTP/1.0 200 OK"
			echo "Content-Type: image/jpeg"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*.png)
			echo "HTTP/1.0 200 OK"
			echo "Content-Type: image/png"
			echo
			cat ${FILE_PATH}
			return 0
			;;
		*)
		;;
	esac

	# いずれのハンドラでも処理されなかった場合、404 を返す。
	# 4秒後にトップページへリフレッシュを指定する。
	echo "HTTP/1.0 404 Not Found"
	echo "Content-Type: text/plain"
	echo "Refresh: 4;/"
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

	# handle_get へ移譲する
	handle_get "${path}"
	return $?
}

function server()
{
    # リクエストライン読み込み
	IFS=' '
	read "method" "path" "protocol"

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
	done
	
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


case "$1" in
	server)
		server $@
		exit 0
		;;
	*)
		echo "starting server on localhost:${LISTEN_PORT}"
		socat TCP4-LISTEN:${LISTEN_PORT},reuseaddr,fork system:"$0 server $2"
		;;
esac
