# gandi.net-dns-dynamic

Use a Gandi.Net subdomain you own as a replacement for a DynDNS host.

## What Does This Do?

* Every hour (by default), it will run a script.
* That script will determine your externally-facing IPv4 and/or IPv6 address.
* It will create or update A or AAAA records for a subdomain under a domain you have registered at Gandi.Net.

## Why Does This Do?

I got a renewal notice for DynDNS.com and noticed that the cost had shot up precipitously. I thought there had to be a better way. I went searching at my registrar, Gandi.Net, and saw that [they had an example of how to do this](https://github.com/Gandi/api-examples/blob/master/bash/livedns/mywanip.sh), using an older API. So I created a new version based on that with [their v5 API](https://api.gandi.net/docs/livedns/).

## How Does This Do?

* Installs a `systemd` user timer and user service.
* Accepts necessary parameters (API key, domain name, subdomain)
* Determines your IPv4 and/or IPv6 address
* Submits those 4 pieces of information to Gandi.Net to create or update an A and/or AAAA record with a TTL of 30m
* Expects every invocation to run like `systemd start --user gandi-dyndns.service` (no standalone execution)

## Installation

```shell
git clone https://github.com/KlfJoat/gandi.net-dns-dynamic.git
cd gandi.net-dns-dynamic
make install
```

## Setup

(stub)

**Prerequisite**: Pay for a domain hosted by Gandi.Net.

1. Go to Gandi.Net
2. Create an API key
3. Configure the API key & domain in the `systemd` environment file at `$XDG_CONFIG_HOME/gandi-dyndns.conf` or in the script itself
4. Further optional configuration can be performed in the `systemd` environment file at `$XDG_CONFIG_HOME/gandi-dyndns.conf` or in the script itself
    * Subdomain - defaults to `hostname --short`
    * DNS record TTL (in seconds) - defaults to 1800 (30 minutes)
    * Service to get your external IP address - defaults to `me.gandi.net`
    * API endpoint - defaults to `api.gandi.net/v5/`. Override this to test using the Gandi API Sandbox at `api.sandbox.gandi.net/v5/`.

## Future Enhancements

1. Due to a bug in `systemd` 257, it is not currently (Ubuntu 2025.11) possible to use the nifty [systemd Credentials mechanism](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#Credentials) to pass in the API key.
2. I should make the Setup section above clearer and more step-by-step.

## Contributions

I might accept PRs, I might not. I'm trying to keep this relatively simple. But give it a shot if you have something to add!
