# ufw-ipset

A helper script for expanding `ipset` members into individual `ufw` rules on Linux.  
This allows `ufw` to apply rules to all IPs in an ipset, which it does not natively support.

### Parameters

* `allow|deny|reject|limit`: UFW action.
* `proto tcp|udp`: Protocol to match (optional).
* `from ipset:<name>` or `to ipset:<name>`: IP set to expand.
* `to any port <ports>`: Target ports (optional).
* `comment "text"`: Optional rule comment.

## Example

Create the IP Sets
```sh
# IPv4 set
sudo ipset create cloudflare4 hash:net family inet
curl -s https://www.cloudflare.com/ips-v4 | sudo xargs -n1 ipset add cloudflare4

# IPv6 set
sudo ipset create cloudflare6 hash:net family inet6
curl -s https://www.cloudflare.com/ips-v6 | sudo xargs -n1 ipset add cloudflare6
```

Load them into UFW
```sh
ufw-ipset route allow proto tcp from ipset:cloudflare4 to 172.18.0.8 port 80,443 comment "Cloudflare IPv4 -> Traefik HTTP(S)"
# Not required, as Cloudflare proxies IPv6 clients to the server’s IPv4. Also you're unable to without configuration as iptables/ip6tables) doesn’t allow mixing IPv6 source addresses with an IPv4 destination.
# ufw-ipset route allow proto tcp from ipset:cloudflare6 to 172.18.0.8 port 80,443 comment "Cloudflare IPv6 -> Traefik HTTP(S)" 
```

## Notes

* The script loops over each IP in the ipset and applies the `ufw` rule individually.  
* Verbose `ufw` status is printed at the end.  