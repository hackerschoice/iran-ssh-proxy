# Docker Server Side for the Iran Proxy 

This information is for Linux Admins who operate an EXIT server outside of IRAN.

---
* If you are an ADMIN inside of IRAN: Join us on [Telegram](https://t.me/+tIblf9hhvBAwOGNk).  
* If you are a USER inside of IRAN: Read [https://iq.thc.org/latest-iran-proxy-servers](https://iq.thc.org/latest-iran-proxy-servers).

---

***Send us LOGIN NAME + PASSWORD of any server in Iran. We can turn it into a SSH _and_ ShadowSocks proxy that anyone can use (without needing to install any software).***

---

This docker image runs on an EXIT server outside of Iran. The container connects (by SSH) to a VPS inside of Iran and forwards ports back to the EXIT server (ssh -R). No data is stored inside of Iran. The EXIT server runs socks/shadowsocks/nginx inside the docker container. The user connects to the VPS inside of Iran and the connection is forwarded (via ssh-reverse) to the EXIT server where the data is stored.

This proxy works when all international Internet is OFF for user's in Iran and when Iran filters or block all outgoing connections.

The user can:
1. Download PuTTY and Instructions via the VPS inside of Iran.
1. Use SSH (`ssh -D1080` or PuTTY) to set up a hidden socks channel to Freedom with the VPS inside of Iran being the entry.
1. Use ShadowSocks

Risk to VPS Admin and User (in Iran):
1. We do not install _any_ software on the VPS
1. The traffic is directly forwarded to our servers in Bahrain and Germany.
2. The VPS does not log any connecting IP.
3. The ISPs generally do not log incoming TCP connections.
5. The traffic appears as Secure Shell (SSH) (all the way to Germany) traffic and can not be decrypted.
5. We have heard that some volunteers are sending us LOGIN + PASSWORD of hacked servers that our software (unknowingly) turns into a free proxy for others to use. Is this clever or not? In case you are unsure perhaps best to [contact us](https://t.me/+tIblf9hhvBAwOGNk) and we can verify the credentials and calm your conscience.


**Step 1:**  
Create a User on any VPS inside of Iran. We assume the user is called `ubuntu` with password `pass1234` and has IP Address `1.2.3.4`. Execute this command on the IRAN-VPS (as root):
```shell
sed 's/.*GatewayPorts no.*/GatewayPorts yes/' -i /etc/ssh/sshd_config
systemctl restart sshd
```

**Step 2:**  
Execute this command on the EXIT server outside of Iran:
```shell
docker run --rm -e CONFIG="ubuntu:pass1234@1.2.3.4:22" -v$(pwd)/config:/config -it hackerschoice/iran-ssh-proxy
```

**Step 3:**  
Ask the Users to read the Instructions at http://1.2.3.4:8080 to tunnel out of Iran.

---
If you have ROOT access to the VPS inside of Iran then use this:

**Step 1:**  
Create an SSH key on the EXIT server:
```shell
mkdir config
ssh-keygen -t ed25519 -N "" -f config/id
```

**Step 2:**  
Add the `id.pub` to `/root/.ssh/authorized_keys` on the VPS inside of Iran.

```shell
docker run --rm -e CONFIG="root:/config/id@1.2.3.4:22" -v$(pwd)/config:/config -it hackerschoice/iran-ssh-proxy
```

---
Renting a VPS inside Iran:

1. https://www.avanetco.com/iran-vps-hosting/ (accepts BitCoin)
1. https://www.arvancloud.com
