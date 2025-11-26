#!/bin/bash
#
# gandi-dyndns.sh
#     Use a Gandi.Net subdomain you own as a replacement for a DynDNS host.
#
# Uses:
#  * https://api.gandi.net/docs/
#
# Shamelessly cribbing
#  * https://github.com/Gandi/api-examples/blob/master/bash/livedns/mywanip.sh
#

# Gandi v5 API KEY
apikey=${apikey:-""}
# Static domain
domain=${domain:-""}
# Dynamic subdomain
subdomain=${subdomain:-$(hostname --short)}
# Set TTL (default 30m/1800s)
ttl=${ttl:-1800}
# IP service
ip_service=${ip_service:-http://me.gandi.net}
# API base
api=${api:-https://api.gandi.net/v5/}


# Verify script requirements
my_needed_commands="curl ip jq"
missing_counter=0
for needed_command in ${my_needed_commands}; do
  if ! hash "${needed_command}" >/dev/null 2>&1; then
    echo "ERROR: Command not found in PATH: ${needed_command}" >&2
    ((missing_counter++))
  fi
done
if ((missing_counter > 0)); then
  echo "ERROR: Minimum ${missing_counter} commands are missing in PATH. Aborting..." >&2
  exit 1
fi

function validate_ipv4 {
    # Regex from https://stackoverflow.com/a/17871737/3661441
    local ip_addr="${1}"
    # Test for a valid IPv4 segment
    local ipv4seg='(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])'
    if [[ ! ${ip_addr} =~ ^(${ipv4seg}\.){3,3}${ipv4seg}$ ]]; then
        echo "ERROR: ${ip_addr} is not a valid IPv4 address. Aborting..." >&2
        exit 1
    fi
}


# @description Test if something is an IPv6 address.
# See if the argument is an IPv6 address. This works by using `ip`.
# This is the most robust test bc it uses an external program that MUST be correct.
# It is also the most fragile bc it's non-portable.
#
# @arg 1 string String to test.
# @exitcode 0 Address passed validation
# @exitcode 1 Address failed validation
# @see [POSIX shell compatible IPv6 expand/compress](https://stackoverflow.com/a/76164024/3661441)
validate_ipv6() {
  # shellcheck disable=SC2292  # This is designed for /bin/sh, not just bash.
  if ! ip -family inet6 route get "${1}" >/dev/null 2>/dev/null ; then
      echo -E "ERROR: '${1}' is not a valid IPv6 address. Aborting..." >&2
      exit 1
  fi
  return 0
}


# @description Test if IPv6 address passed in is a ULA or not.
# Unique Local Addresses have 'scope global' in Linux, so a straight
# address check is the only way to identify them.
# ULAs fall under fc00::/7, so that's fc00::/8 and fd00::/8.
#
# @example
#
#     if is_ipv6_ula "fddd:aaaa:bbbb:cccc:55ae:bdb2:5b39:d6d5"; then...
#
# @arg $1 string IPv6 address to test the first two characters of.
# @exitcode 0 Address *IS* a Unique Local Address (first 2 chars are 'fc' or 'fd')
# @exitcode 1 Address is *NOT* a Unique Local Address (first 2 chars are NOT 'fc' or 'fd')
# @see https://en.wikipedia.org/wiki/Unique_local_address
# @test ===
is_ipv6_ula() {
  if [[ "${1,,}" == fd* ]] || [[ "${1,,}" == fc* ]]; then
    return 0
  fi
  return 1
}


# @description Get device IPv6 addresses that are global scoped and privacy template flagged.
#
# @example
#     mapfile -d '' ipv6_globaltemplate < <( get_ipv6_globaltemplate enp4s0 )
#     #wait "$!"  # use in bash-4.4+ to get exit status of the process substitution
#
# @arg $1 string Optional interface name to scope down the list.
# @stdout Null-terminated list of IPv6 addresses, optionally scoped to $1
# @test ===
# shellcheck disable=SC2120   # The arguments are optional
get_ipv6_globaltemplate() {
  local iface
  iface=''
  if [[ -n "${1}" ]]; then
    iface="dev ${1}"
  fi

  # shellcheck disable=SC2312,SC2086   # If `ip` throws an error, we'll see no or bad output; I want word splitting
  ip -family inet6 -json address ${iface} show scope global mngtmpaddr \
  | jq --raw-output0 '.[].addr_info.[].local | select(.!=null)'
}


function usage {
  echo
  echo "${0}"
  echo "    Create and use a subdomain of your Gandi.Net domain for Dynamic DNS."
  echo
  echo "Usage"
  echo "  ${0} [--apikey <API_KEY>] [--domain <example.net>] [--hostname $(hostname --short ||true)] [--help]"
  echo
  echo "You can also pass optional parameters via command-line or environment"
  echo "  --apikey    : Gandi.net API token."
  echo "  --domain    : Domain hosted at Gandi.net."
  echo "  --subdomain : Subdomain you want to point to your IP address."
  echo "                If not set, defaults to hostname --short"
  echo "  --help      : This help."
  echo
  echo "View source for more options or to embed options."
  echo
  exit 1
}

# Check for parameters
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --apikey)
      apikey="$2"
      shift
      shift;;
    --domain)
      domain="$2"
      shift
      shift;;
    --subdomain)
      subdomain="$2"
      shift
      shift;;
    -h|--help)
      usage;;
    *)
      echo "ERROR: \"${1}\" is not supported." >&2
      usage;;
  esac
done

# Check arguments, list the problems, abort if necessary.
argerr=""
if [[ -z "${apikey}" ]]; then
  echo "ERROR: A Gandi.Net API token has not been provided." >&2
  argerr=1
fi

if [[ -z "${domain}" ]]; then
  echo "ERROR: Domain has not been provided." >&2
  argerr=1
fi

if [[ -z "${subdomain}" ]]; then
  echo "ERROR: Subdomain has not been provided." >&2
  argerr=1
fi

if [[ -n ${argerr} ]]; then
  echo "Argument errors. Aborting..." >&2
  exit 1
fi

# Get current Internet-facing IP addresses.
echo "Fetching IPv4 address"
ipv4=$(curl --silent --ipv4 "${ip_service}")
echo "Fetched '${ipv4}' as IPv4 address"

echo "Fetching IPv6 address"
declare -a ipv6addrs
declare ipv6iface
# shellcheck disable=SC2312   # It's okay if this returns blank or error
mapfile -d '' ipv6addrs < <( get_ipv6_globaltemplate )
for i in "${ipv6addrs[@]}"; do
  if ! is_ipv6_ula "${i}"; then
    ipv6iface="${i}"
    # Only return the first ipv6 address since we can only set one
    break
  fi
done
ipv6=$(curl --silent --ipv6 --interface "${ipv6iface}" "${ip_service}")
echo "Fetched '${ipv6}' as IPv6 address"

# Ensure that we got something from at least one of them
if [[ -z ${ipv4} && -z ${ipv6} ]]; then
  echo "Something went wrong. Can not get your IP (v4 or v6) from ${ip_service}! Aborting..." >&2
  exit 1
fi

# Validate IPv4 address.
if [[ -n ${ipv4} ]]; then
  validate_ipv4 "${ipv4}"
fi

# Validate IPv6 address.
if [[ -n ${ipv6} ]]; then
  validate_ipv6 "${ipv6}"
fi

AuthZ="Authorization: Apikey ${apikey}"

# Update IPv4
if [[ -n ${ipv4} ]]; then
  echo "Setting ${subdomain}.${domain} to ${ipv4}"

  data='{"rrset_ttl": '${ttl}', "rrset_values": ["'${ipv4}'"]}'
  # Note that PUT works for subdomain creation exactly like POST does.
  curl --no-progress-meter \
       --request PUT \
       --header "Content-Type: application/json" \
       --header "${AuthZ}" \
       --data "${data}" \
       "${api}"/livedns/domains/"${domain}"/records/"${subdomain}"/A
  echo
fi

# Update IPv6
if [[ -n ${ipv6} ]]; then
  echo "Setting ${subdomain}.${domain} to ${ipv6}"

  data='{"rrset_ttl": '${ttl}', "rrset_values": ["'${ipv6}'"]}'
  # Note that PUT works for subdomain creation exactly like POST does.
  curl --no-progress-meter \
       --request PUT \
       --header "Content-Type: application/json" \
       --header "${AuthZ}" \
       --data "${data}" \
       "${api}"/livedns/domains/"${domain}"/records/"${subdomain}"/AAAA
  echo
fi
