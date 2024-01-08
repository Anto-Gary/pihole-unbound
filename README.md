# Pi-hole - With Unbound 
this script assumes its being run on a raspberry pi Bullseye OS (64 bit) with a static IP address assigned to it

1. change `WEBPASSWORD` under `environment` key in `docker-compose.yml` file

2. run `./start-pihole-unbound.sh`
   * runs `docker-compose.yml` file
   * pihole UI accessible on `http://<raspberry_pi_ipaddr>/admin` with password from step 1 


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


### Browser Security
---

* [Cloudflare test 1](https://www.cloudflare.com/ssl/encrypted-sni/#dns)
* [Cloudflare test 2](https://1.1.1.1/help)



### [General DNS tools](https://www.routersecurity.org/testdns.php)
---

* [Show DNS resolvers](https://dnscheck.tools/)
* [DNS Leak Test](https://www.perfect-privacy.com/en/tests/dns-leaktest)
* [DNS Leak Test2](https://www.dnsleaktest.com/)