#!/bin/bash
#
# gandi-dyndns.sh
#     Use a Gandi.Net subdomain you own as a replacement for a DynDNS host.
#
# Uses Reference:
#  * https://api.gandi.net/docs/livedns/
#
# Shamelessly combining
#  * https://github.com/Gandi/api-examples/blob/master/bash/livedns/mywanip.sh
#

# Gandi livedns API KEY
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
my_needed_commands="curl"
missing_counter=0
for needed_command in $my_needed_commands; do
  if ! hash "$needed_command" >/dev/null 2>&1; then
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
    if [[ ! ${ip_addr} =~ ^($ipv4seg\.){3,3}$ipv4seg$ ]]; then
        echo "ERROR: ${ip_addr} is not valid. Aborting..." >&2
        exit 1
    fi
}

function validate_ipv6 {
    # Regex from https://stackoverflow.com/a/17871737/3661441
    local ip_addr="${1}"
    # Test for a valid IPv6 segment
    local ipv6seg='[0-9a-fA-F]{1,4}'
    # Subset of the regex; we don't need to accept any of the IPv6/IPv4 combos.
    local ipv6addr='^(($ipv6seg:){7,7}$ipv6seg|($ipv6seg:){1,7}:|($ipv6seg:){1,6}:$ipv6seg|($ipv6seg:){1,5}(:$ipv6seg){1,2}|($ipv6seg:){1,4}(:$ipv6seg){1,3}|($ipv6seg:){1,3}(:$ipv6seg){1,4}|($ipv6seg:){1,2}(:$ipv6seg){1,5}|$ipv6seg:((:$ipv6seg){1,6})|:((:$ipv6seg){1,7}|:)$'
    if [[ ! ${ip_addr} =~ $ipv6addr ]]; then
        echo "ERROR: ${ip_addr} is not valid. Aborting..." >&2
        exit 1
    fi
}


function usage {
  echo 
  echo "${0}"
  echo "    Create and use a subdomain of your Gandi.Net domain for Dynamic DNS."
  echo
  echo "Usage"
  echo "  ${0} [--apikey <API_KEY>] [--domain <example.net>] [--hostname $(hostname --short)] [--help]"
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
while [ $# -gt 0 ]; do
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
      echo "ERROR: \"${1}\" is not supported."
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

if [[ ! -z ${argerr} ]]; then
  echo "Argument errors. Aborting..." >&2
  exit 1
fi

# Get current Internet-facing IP addresses.
ipv4=$(curl --silent --ipv4 ${ip_service})
ipv6=$(curl --silent --ipv6 ${ip_service})

# Ensure that we got something from at least one of them
if [[ -z ${ipv4} && -z ${ipv6} ]]; then
  echo "Something went wrong. Can not get your IP (v4 or v6) from ${ip_service}"
  exit 1
fi

# Validate IPv4 address.
if [[ ! -z $ipv4 ]]; then
  validate_ipv4 "${ipv4}"
fi

# Validate IPv6 address.
if [[ ! -z $ipv6 ]]; then
  validate_ipv6 "${ipv6}"
fi

AuthZ="Authorization: Apikey ${apikey}"

# Update IPv4
if [[ ! -z ${ipv4} ]]; then
  echo "Setting ${subdomain}.${domain} to ${ipv4}"

  data='{"rrset_ttl": '${ttl}', "rrset_values": ["'${ipv4}'"]}'
  # Note that PUT works for subdomain creation exactly like POST does.
  curl --request PUT \
       --header "Content-Type: application/json" \
       --header "${AuthZ}" \
       --data "${data}" \
       ${api}/livedns/domains/${domain}/records/${subdomain}/A
  echo
fi

# Update IPv6
if [[ ! -z ${ipv6} ]]; then
  echo "Setting ${subdomain}.${domain} to ${ipv6}"

  data='{"rrset_ttl": '${ttl}', "rrset_values": ["'${ipv6}'"]}'
  # Note that PUT works for subdomain creation exactly like POST does.
  curl --request PUT \
       --header "Content-Type: application/json" \
       --header "${AuthZ}" \
       --data "${data}" \
       ${api}/livedns/domains/${domain}/records/${subdomain}/AAAA
  echo
fi

