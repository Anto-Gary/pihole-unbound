# Pi-hole - With Unbound 
- pihole container which uses unbound container as DNS resolver (Bullseye OS (64 bit)) 


## What is Unbound? (taken from [here](https://docs.pi-hole.net/guides/dns/unbound/))

### A standard Pi-hole installation will do it as follows:

    * Your client asks the Pi-hole Who is pi-hole.net?
    * Your Pi-hole will check its cache and reply if the answer is already known.
    * Your Pi-hole will check the blocking lists and reply if the domain is blocked.
    * Since neither 2. nor 3. is true in our example, the Pi-hole forwards the request to the configured external upstream DNS server(s).
    * Upon receiving the answer, your Pi-hole will reply to your client and tell it the answer to its request.
    * Lastly, your Pi-hole will save the answer in its cache to be able to respond faster if any of your clients queries the same domain again.


### After you set up your Pi-hole as described in this guide, this procedure changes notably:

    * Your client asks the Pi-hole Who is pi-hole.net?
    * Your Pi-hole will check its cache and reply if the answer is already known.
    * Your Pi-hole will check the blocking lists and reply if the domain is blocked.
    * Since neither 2. nor 3. is true in our example, the Pi-hole delegates the request to the (local) recursive DNS resolver.
    * Your recursive server will send a query to the DNS root servers: "Who is handling .net?"
    * The root server answers with a referral to the TLD servers for .net.
    * Your recursive server will send a query to one of the TLD DNS servers for .net: "Who is handling pi-hole.net?"
    * The TLD server answers with a referral to the authoritative name servers for pi-hole.net.
    * Your recursive server will send a query to the authoritative name servers: "What is the IP of pi-hole.net?"
    * The authoritative server will answer with the IP address of the domain pi-hole.net.
    * Your recursive server will send the reply to your Pi-hole which will, in turn, reply to your client and tell it the answer to its request.
    * Lastly, your Pi-hole will save the answer in its cache to be able to respond faster if any of your clients queries the same domain again.




### Manual Prerequisites
```bash
    * `ssh <user>@<raspberry_pi_ipaddr>`

    * `sudo raspi-config`
        * enable VNC
            * `Interface Options` -> `VNC`
        * set VNC screen resolution (because a monitor was never used with pi)
            * `Display Options` -> `VNC Resolution`


## command to silently generate ssh key for auth with github
# ssh-keygen -q -t rsa -f "$HOME/.ssh/id_rsa" -N "" ; cat ~/.ssh/id_rsa.pub
```



### Installation Instructions
```bash
# 0.
# change IP in addStaticIp.sh
# add pihole password in .env file

# 1. add static IP to dhcpcd file && install some packages
./addStaticIp.sh && ./newServerSetup.sh && sudo reboot

# 2. install docker 
./installDocker.sh && sudo reboot

# 3. start containers 
./startPihole.sh

# 4. stop containers (also removes all images too)
./stopPihole.sh
```



### Browser Security
---

* [Cloudflare test 1](https://www.cloudflare.com/ssl/encrypted-sni/#dns)
* [Cloudflare test 2](https://1.1.1.1/help)



### [General DNS tools](https://www.routersecurity.org/testdns.php)
---

* [Show DNS resolvers](https://dnscheck.tools/)
* [DNS Leak Test](https://www.perfect-privacy.com/en/tests/dns-leaktest)
* [DNS Leak Test2](https://www.dnsleaktest.com/)