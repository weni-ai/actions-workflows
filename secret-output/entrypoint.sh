#!/bin/bash -l

set -e

CACHE_DIR="${CACHE_DIR-"${GITHUB_WORKSPACE}/.cache_secret"}"

declare -A levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
script_logging_level="${LOG_LEVEL-"INFO"}"

function log(){
	local log_message=$1
	local log_priority=$2

	# check if level exists
	[[ ${levels[$log_priority]} ]] || return 1

	# check if level is enough
	(( ${levels[$log_priority]} < ${levels[$script_logging_level]} )) && return 0

	echo "${log_message}" 1>&2
}

function gen_random_passphrase(){
	chars='abcdefghijklmnopqrstuvwxyz/.-[{]}1234567890!@#$%^&*()_+'
	n=42

	str=
	for ((i = 0; i < n; ++i)); do
		str+="${chars:RANDOM%${#chars}:1}"
	done

	echo "$str"
}

function get_secret(){
	if [ "${SECRET}" ] ; then
		log 'Use secret env' 'DEBUG'
		cat <<< "${SECRET}"
	else
		if [ ! -r "${CACHE_DIR}/.token" ] ; then
			log 'Gen cache secret' 'DEBUG'
			mkdir -p "${CACHE_DIR}"
			gen_random_passphrase > "${CACHE_DIR}/.token"
		fi
		cat "${CACHE_DIR}/.token"
	fi
}

case "${OPERATION}" in
	encode)
		result=$(
			gpg --symmetric --batch --passphrase-file <(
				get_secret
			) --output - <(
				cat <<< "${IN}"
			) | base64 | xargs | tr -d ' '
		)
		#echo "out=${result}" >> "${GITHUB_OUTPUT}"
		{
			echo 'out<<EOFoutput'
			cat <<< "${result}"
			echo 'EOFoutput'
		} >> "${GITHUB_OUTPUT}"
	;;
	decode)
		result=$(
			gpg --decrypt --quiet --batch --passphrase-file <(
				get_secret
			) --output - <(
				base64 -d <<< "${IN}"
			)
		)
		echo "::add-mask::${result}"
		{
			echo 'out<<EOFoutput'
			cat <<< "${result}"
			echo 'EOFoutput'
		} >> "${GITHUB_OUTPUT}"
		#} | tee -a "${GITHUB_OUTPUT}"
	;;
	toml-decode)
		result=$(
			gpg --decrypt --quiet --batch --passphrase-file <(
				get_secret
			) --output - <(
				base64 -d <<< "${IN}"
			)
		)
		echo "::add-mask::${result}"
		for toml_key in $( yq -p toml 'keys' -o csv | tr ', ' '\n' ) ; do
			{
				echo "${toml_key}<<EOFoutput"
				yq -p toml ".${toml_key}" -r <<< "${result}"
				echo 'EOFoutput'
			} >> "${GITHUB_OUTPUT}"
		done
	;;
	cleanup)
		rm -rf "${CACHE_DIR}/.token"
	;;
	*)
		echo $"op input can be only {encode|decode|toml-decode|cleanup}"
		exit 1
esac
