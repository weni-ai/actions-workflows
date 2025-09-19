#!/bin/bash -l

set -e

CACHE_DIR="${CACHE_DIR-'.cache_secret'}"

function gen_random_passphrase(){
	chars='abcdefghijklmnopqrstuvwxyz/.-[{]}1234567890!@#$%^&*()_+'
	n=42

	str=
	for ((i = 0; i < n; ++i)); do
		str+=${chars:RANDOM%${#chars}:1}
		# alternatively, str=$str${chars:RANDOM%${#chars}:1} also possible
	done

	echo "$str"
}

function get_secret(){
	if [ "${SECRET}" ] ; then
		cat <<< "${SECRET}"
	else
		if [ ! -r "${CACHE_DIR}/.token" ] ; then
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
				cat <<< "${SECRET}"
			) --output - <(
				cat <<< "${IN}"
			) | base64 -w0
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
				cat <<< "${SECRET}"
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
	*)
		echo $"op input can be only {encode|decode}"
		exit 1
esac
