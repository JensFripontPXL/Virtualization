# Passwordless ssh 
# Op client
ssh-keygen
ssh-copy-id student@$Server_IP
# nu kan je zonder wachtwoord inloggen op server 

# Docker remote toegangkelijk maken
# op server
# Eerst instellen dat docker op server luistert naar tcp verbindingen
sudo nano /etc/docker/daemon.json 
# toevoegen
{ 
   "hosts": ["tcp://0.0.0.0:2376", "unix:///var/run/docker.sock"] } 
# omdat er een apart document is ingesteld waarnaar docker luistert moet je die ook aanpassen
sudo nano /usr/lib/systemd/system/docker.service 
# deze regel aanpassen : ExecStart=/usr/bin/dockerd -H fd:// -containerd=/run/containerd/containerd.sock 
# naar : ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock 

sudo systemctl daemon-reload; sudo systemctl restart docker; sudo systemctl status docker

# Firewall aanpassen op server om poort 2376 open te zetten
sudo firewall-cmd --add-port=2376/tcp --permanent
sudo firewall-cmd --reload

# op client
# docker client installeren
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 
sudo dnf install docker-ce-cli
# nu kan je vanaf client verbinding maken met docker op server
docker -H tcp://192.168.112.100:2376 version 

# dit blijft een oveilige verbinding omdat er geen encryptie is ingesteld
# je kan dit oplossen door een ssh tunnel te maken
ssh -t student@192.168.112.100 "sudo docker version" # -t zorgt ervoor dat sudo werkt via ssh

# 4 Containers en container images 
# <image-naam>:<tag>
sudo docker pull redhat/ubi10:latest # docker moet met sudo 
podman pull redhat/ubi10:latest ? # podman hoeft niet met sudo
podman login registry.redhat.io # inloggen op redhat registry
# podman commando's 
podman run registry.access.redhat.com/ubi10/ubi:latest  # podman run <image>, voert container uit op basis van image
podman run registry.access.redhat.com/ubi10/ubi:latest whoami # voert command uit in container, na de opdracht wordt container gestopt
podman ps -a # toont alle containers, ook gestopte
podman start <container-id> # start een gestopte container
podman stop <container-id> # stopt een draaiende container
podman logs <container-id> # toont logs van container, stdout en stderr
podman images # toont alle images

# Interactieve container opstarten
podman run -it registry.access.redhat.com/ubi10/ubi:latest 
# -i interactive, -t terminal
# je zit nu in de container
# Interacief of detached; detached is op de achtergrond -d
podman run -d registry.access.redhat.com/ubi10/ubi:latest tail -f /dev/null 
podman logs <container-id> # zal geen output geven omdat /dev/null geen output genereert
# Om in een draaiende container te komen
podman exec -it <container-id> /bin/bash
echo $SHELL # toont welke shell je gebruikt
podman ps # toont de /dev/null container als draaiend

# info over container opvragen
podman image inspect registry.access.redhat.com/ubi10/ubi:latest 
# verschillende lagen van image worden getoond, elke laag is een wijziging tov de vorige laag

# interactief een container bouwen
## webserver
sudo podman run -it -p 8080:80 registry.access.redhat.com/ubi10/ubi:latest /bin/bash 
# -p <HOST_POORT>:<CONTAINER_POORT>:  poort doorsturen van host naar container
# in container
dnf install httpd -y
echo "Hello from Podman Webserver" > /var/www/html/index.html
usr/sbin/httpd # start webserver
# start een tweede terminal sessie naar server en kijk of er containers actief zijn
podman ps # zou de webserver container moeten tonen
podman exec -it <container-id> ip addr # terug naar webserver container
# vanuit container 
curl 192.168.112.100 # zou de webpagina moeten tonen
# vanuit server zelf
curl 192.168.112.100:8080 # zou de webpagina moeten tonen

## DNS server
# nieuwe interactieve detached container 
podman run -d registry.access.redhat.com/ubi10/ubi:latest sleep infinity # sleep infinity zorgt ervoor dat container actief blijft
podman exec -it <container-id> /bin/bash
# in container
cat/etc/hostname # toont container hostname
ip addr show dev ens160 # toont IP adres van container
dnf install bind bind-utils -y
# configuratiebestanden aanpassen in /etc/named.conf en /var/named/
nano /etc/named.conf
cat > /etc/named.conf <<'EOF'
options {
    directory "/var/named";
    recursion yes;
    allow-recursion { any; };

    # kies forwarders die vanaf jouw netwerk bereikbaar zijn:
    forwarders { 8.8.8.8; 8.8.4.4; };
    forward only;

    # in containers vaak handig, tenzij je klok/anchors perfect zijn:
    dnssec-validation no;
    # (of: dnssec-validation auto;  als je tijd NTP-juist is en validatie wilt)
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

zone "abc.pri" IN {
    type master;
    file "/var/named/abc.pri.dns";
    allow-query { any; };
    allow-transfer { none; };
};
EOF

nano /var/named/abc.pri.dns
cat > /var/named/abc.pri.dns <<'EOF'
$TTL 8h 
$ORIGIN abc.pri. 
@   IN  SOA ns1.abc.pri. hostmaster.abc.pri. ( 
        2025031701 ; serial (YYYYMMDDnn) 
        1d         ; vernieuwingsperiode 
        3h         ; herhalingsperiode 
        3d         ; vervaltijd 
        3h         ; minimum TTL 
) 
    IN  NS  ns1.abc.pri. ns1 IN  A   127.0.0.1 host IN  A   192.168.1.100
EOF

chown -r named:named /var/named/
chmod 770 -R /var/named/

# syntax check
named-checkconf -z /etc/named.conf 
named-checkzone abc.pri /var/named/abc.pri.dns

named -g -u named # start named in foreground met logging naar stdout, user named
# in tweede terminal sessie, verbinding maken met container
podman exec -it <container-id> /bin/bash
dnf install -y iputils 
ping -c 1 www.google.com # zou moeten werken door forwarders
nslookup host.abc.pri 127.0.0.1
# nslookup host.abc.pri 192.168.112.xxx (container IP adres) zou ook moeten werken
exit # terug naar server
podman ps # dns server container zouden actief moeten zijn
podman stop <container-id> # stopt dns server container

# image afleiden van container
podman commit <container-id> contdns
podman images # toont nieuwe image contdns

podman run --detaach contdns # start nieuwe container op basis van image contdns, --detach of -d om in detached mode te starten
podman exec -it <container-id> bash
named -g -u named # start dns server
# in tweede terminal sessie
podman exec -it <container-id> bash
nslookup host.abc.pri # werkt nog steeds
# aangezien we geen portmapping hebben ingesteld is de dns server niet van buitenaf bereikbaar
podman kill <container-id> # stopt container

# we starten nu een container met portmapping
sudo podman run -p 53:53/udp -p 53:53/tcp --detach contdns # poort 53 mappen voor udp en tcp, sudo nodig voor poorten <1024
#werkt niet omdat je als sudo niet aan gewone user images kan 
# oplossing = image exporteren als student en importeren als root 
podman save -o contdns.tar localhost/contdns:latest 
sudo podman load -i /home/student/contdns.tar 
sudo podman images 
sudo podman run -p 53:53/udp -p 53:53/tcp --detach localhost/contdns:latest
sudo podman exec -it <container-id> bash
named -g -u named
# in tweede terminal sessie op server
nslookup www.google 192.168.112.100

# Als bovenstaande niet werkt wil dat zeggen dat er vanuit de container geen verbinding kan gemaakt worden met 8.8.8.8. Dit los je als volgt op (op de container host): 
# student@serverXX:~$ sudo iptables -t nat -A POSTROUTING -s 10.88.0.0/16 -o ens160 -j 
# MASQUERADE 
# student@serverXX:~$  sudo iptables -I FORWARD 1 -s 10.88.0.0/16 -o ens160 -j ACCEPT 
# student@serverXX:~$ sudo iptables -I FORWARD 1 -d 10.88.0.0/16 -m state --state RELATED,ESTABLISHED -i ens160 -j ACCEPT 

nslookup host.abc.pri 192.168.112.100 
sudo podman kill <container-id>

# Containers starten stoppen en verwijderen
podman rm $(podman ps -a -q) -f # verwijder alle containers, -f force
podman rmi $(podman images -q) -f # verwijder alle images,
podman container prune # verwijder alle gestopte containers

# Container image bouwen met een containerfile
#Dockerfile
    #FROM: welke image als basis gebruiken
    #COPY: bestanden kopiëren van host naar image
    #RUN: opdracht uit te voeren na de start van de container
    #CMD: commando dat uitgevoerd wordt bij het starten van de container
# stap 1: mappen structuur aanmaken
mkdir -p ~/oefening/scripts 
nano oefening/Dockerfile 
cat > oefening/Dockerfile <<'EOF'
FROM registry.access.redhat.com/ubi10/ubi-init 
 
# Bind + tools installeren 
RUN dnf -y install bind bind-utils && dnf clean all 
 
# Config & zone 
COPY scripts/named.conf /etc/named.conf 
COPY scripts/abc.pri /var/named/abc.pri # Vereiste directories + juiste rechten 
RUN mkdir -p /var/named \ 
 && chown named:named /var/named \ 
 && chmod 0750 /var/named \ 
 && chown named:named /var/named/abc.pri /etc/named.conf \ 
 && chmod 0640 /var/named/abc.pri /etc/named.conf 
EOF

nano oefening/scripts/named.conf
cat > oefening/scripts/named.conf <<'EOF'
options {
    directory "/var/named";
    listen-on port 53 { any; };
    allow-query { any; };
    recursion yes;
    allow-recursion { any; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    forward only;
    dnssec-validation no;
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "abc.pri" IN {
    type master;
    file "abc.pri";
    allow-query { any; };
    allow-transfer { none; };
};
EOF

nano oefening/scripts/abc.pri
cat > oefening/scripts/abc.pri <<'EOF'
$TTL 8h 
$ORIGIN abc.pri. 
@   IN  SOA ns1.abc.pri. hostmaster.abc.pri. ( 
        2025031701 ; serial (YYYYMMDDnn) 
        1d         ; vernieuwingsperiode 
        3h         ; herhalingsperiode 
        3d         ; vervaltijd 
        3h         ; minimum TTL 
) 
    IN  NS  ns1.abc.pri. ns1 IN  A   127.0.0.1 host IN  A   192.168.1.100 
EOF

cd ~/oefening
podman build --format=docker -t contdns . 
podman images # toont nieuwe image contdns
podman run -d -p 1053:53/udp -p 1053:53/tcp contdns /usr/sbin/named -g -u named -c /etc/named.conf
podman ps
dig @127.0.0.1 -p 1053 host.abc.pri 

## naam van container en hostname kiezen 
podman run -d --name contdns --hostname contdns -p 1053:53/udp -p 1053:53/tcp contdns /usr/sbin/named -g -u named -c /etc/named.conf 
podman exec -it contdns bash
podman rm contdns -f 

#Command en entrypoint in Dockerfile
#toevoegen aan Dockerfile
# Zorgt dat netjes gestopt wordt 
STOPSIGNAL SIGTERM 
# Uitvoeren bij initialiseren container 
CMD /usr/sbin/named -g -u named -c /etc/named.conf 
# of 
ENTRYPOINT ["/usr/sbin/named", "-g", "-u", "named", "-c", "/etc/named.conf"]
# verschil: CMD kan overschreven worden bij podman run, ENTRYPOINT niet
# wij kiezen entrypoint

# gewijzigde image aanmaken
podman build --format=docker -t contdns .
podman run -d --name contdns --hostname contdns -p 1053:53/udp -p 1053:53/tcp contdns 
 

# Healthcheck instructie in Dockerfile
nano oefening/Dockerfile
cat >> oefening/Dockerfile <<'EOF'
FROM registry.access.redhat.com/ubi10/ubi-init 
# Bind + tools installeren 
RUN dnf -y install bind bind-utils procps-ng && dnf clean all 
 
# Config & zone 
COPY scripts/named.conf /etc/named.conf 
COPY scripts/abc.pri     /var/named/abc.pri 
 
# Vereiste directories + juiste rechten 
RUN mkdir -p /var/named \ 
 && chown named:named /var/named \ 
 && chmod 0750 /var/named \ 
 && chown named:named /var/named/abc.pri /etc/named.conf \ 
 && chmod 0640 /var/named/abc.pri /etc/named.conf 
 
# Zorgt dat netjes gestopt wordt 
STOPSIGNAL SIGTERM 
 
# Uitvoeren bij initialiseren container 
ENTRYPOINT ["/usr/sbin/named", "-g", "-u", "named", "-c", "/etc/named.conf"] #Healthcheck (wordt named uitgevoerd) 
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD \  pgrep named >/dev/null || exit 1
EOF

podman build --format=docker -t --no-cache contdns .
podman rm contdns -f
podman run -d --name contdns --hostname contdns -p 1053:53/udp -p 1053:53/tcp contdns
podman ps # toont ook de health status

# images uploaden naar Docker Hub
# 1. repo aanmaken op hub.docker.com
# 2. cli inloggen podman
podman login docker.io
# 3. image taggen
podman tag contdns docker.io/<dockerhub-gebruikersnaam>/contdns:latest
# 4. image pushen
podman push docker.io/<dockerhub-gebruikersnaam>/contdns:latest
# 5. image pullen op andere machine
podman pull docker.io/<dockerhub-gebruikersnaam>/contdns:latest

# cockpit 
sudo dnf install -y cockpit 
sudo systemctl enable --now cockpit.socket
sudo firewall-cmd --add-service=cockpit --permanent (--zone=…) 
sudo firewall-cmd --reload
# toegang via webbrowser https://localhost:9090

# Containers netwerken en data volumes 
# netwerken
# rootless netwerktoegang
podman rm --all -f # opkuisen vorige containers
podman version # hoger dan 3.0
podman info --debug | grep rootless # rootless moet true zijn, pasta 
# pasta = container heeft zelfde op als host, gebruikt host gateway, host interface, 
## uitbreiding: slirp4netns instellen
sudo dnf install -y slirp4netns
sudo nano /usr/share/containers/containers.conf
default_rootless_network_cmd = "slirp4netns" # veranderen

## standaard rootless netwerk 
# als je geen netwerk opties opgeeft bij podman run wordt standaard een rootless netwerk aangemaakt
podman run -d --name C1 --hostname C1 ubi10/ubi-init 
podman ps # check of ie draait
podman exec -it C1 bash
dnf install -y iputils iproute curl 
ping-c 1 www.google.com # werkt
ip addr show eth0 # toont IP adres van host 

# communicatie container > container host
sudo dnf install -y httpd # webserver op host
sudo systemctl enable --now httpd
curl 127.0.0.1 # werkt
podman exec -it C1 bash 
curl 127.0.0.1 # werkt niet 
curl http://host.containers.internal # werkt wel, host.containers.internal is DNS naam voor host in rootless netwerk
podman run -d --network 'pasta:--map-gw' --name C2 -hostname C2 ubi10/ubi-init # maak de gateway van de host bereikbaar in de container en gebruik dat als alias voor het host-loopback adres
podman exec -it C2 bash
curl 192.168.112.2 # werkt nu ook

# specifieke hostloopback mappen
podman run -d --network 'pasta:--map-hostloopback=11.11.11.11' --name C3 --hostname C3 ubi10/ubi-init 
podman exec -it C3 bash
curl 11.11.11.11 # werkt, 11.11.11.11 is een extra ip in de container die wordt doorgestuurde naar 127.0.0.1 op de host
exit 
sudo systemctl stop httpd
podman rm --all -f

# communicatie met containers van buitenaf
podman run -d --name myhttpd -p 8080:80 ubi10/ubi sh -c "dnf install -y httpd && httpd -D FOREGROUND" 
# sh-c "<command>" wordt PID 1 in container, eerst dnf installeren en dan webserver starten

# nu moeten we portforwarding instellen op host
sudo sysctl -w net.ipv4.ip_forward=1 
sudo firewall-cmd --direct --add-rule ipv4 nat OUTPUT 0 -p tcp --dport 80 -j REDIRECT --to-ports 8080 success

curl 192.168.112.100 # zou de webpagina moeten tonen

## vanaf andere host
# op server firewall aanpassen
sudo firewall-cmd --direct --add-rule ipv4 nat PREROUTING 0 -p tcp --dport 80 -j DNAT --to-destination 192.168.112.100:8080 
# op client
curl 192.168.112.100
# opkuisen
sudo systemctl reload firewalld 

## communicatie tussen 2 containers 
podman run -d --name myhttpd -p 8080:80 ubi10/ubi sh -c "dnf install -y httpd && httpd -D FOREGROUND" # deze draait nog
# 8080 op host is gekoppeld aan 80 in container

# via host.containers.internal kan je in een andere container 8080 op host bereiken, die is gekoppeld aan 80 in myhttpd container
podman run --rm -it ubi10/ubi   curl -v http://host.containers.internal:8080 # --rm zorgt ervoor dat container verwijderd wordt na exit

# Userspace netwerk
# voorbeeld 1: eigen netwerk aanmaken
podman network create --subnet 192.168.5.0/24 --gateway 192.168.5.1 mynat 
podman network ls
podman network inspect mynat
podman rm --all -f # opkuisen vorige containers
podman run -d --name C1 --hostname C1 --network mynat --ip 192.168.5.150  ubi10/ubi-init 
podman run -d --name C2 --hostname C2 --network mynat --ip 192.168.5.151 ubi10/ubi-init
podman exec -it C1 bash
ip a # toont eth0@if4 eth0 is interface, @if4 is koppeling met index 4 op host
dnf install -y iputils
ping -c 1 C2 # werkt
ip route # toont default via 192.168.5.1
cat /etc/resolv.conf # toont DNS server, 192.168.5.1
ping -c 1 www.google.com # werkt
exit

# voorbeeld 2, extra opties
podman network create mynat2 --subnet 10.0.0.0/24 --gateway 10.0.0.1 --dns 10.0.0.4 mynat2 # extra dns server instellen
podman network inspect mynat2
podman network rm mynat2

# user-mode netwerken en poorttoewijzing
# in een user-mode netwerk wordt verkeer van buitenaf standaard niet doorgestuurd naar containers
podman network ls # we maken een nieuwe container aan in mynat
podman run -d -it --name myhttpd -p 8080:80 --network mynat --ip 192.168.5.160 ubi10/ubi
podman exec -it myhttpd dnf install -y httpd 
podman exec -it myhttpd ip a 
podman exec -it myhttpd httpd
# op host
curl 192.168.112.100:8080 # werkt wel omdat we poort 8080 op host hebben gekoppeld aan poort 80 in container

# meerdere containers met poort 80 verbinden aan verschillende host poorten
podman run -d --name myhttpd2 --publish 1234:80 ubi10/ubi sh -c "dnf install -y httpd && httpd -D FOREGROUND" 
curl 192.168.112.100:1234 # werkt

# Rootfull netwerktoegang 
# rootfull zonder netwerk opties
# rootfull heeft een eigen IP, kan pingen en curlen
# podman kan hierbij gebruik maken van bridge netwerk van host
sudo podman network ls # wordt gebruik gemaakt van het standaard netwerk
# je kan nu ook poorten <1024 mappen omdat je root bent
sudo systemctl stop httpd # stop webserver op host
sudo podman run -d --name myhttpd10 --publish 80:80 ubi10/ubi sh -c "dnf install -y httpd && httpd -D FOREGROUND" 
curl 192.168.112.100 # werkt, webserver draait in container op poort 80

# Netwerkmodi 
# pasta = container gebruikt netwerk van host, rootless standaard
# bridge = rootfull standaard, eigen netwerk met brug naar host
# host = container gebruikt netwerk van host, rootfull en rootless
# none = geen netwerk, rootfull en rootless
# macvlan = container krijgt eigen IP in netwerk van host, rootfull
# ipvlan = container krijgt eigen IP in netwerk van host maar zonder extra MAC's, rootfull

## Hostnetwerk
podman rm --all -f; sudo podman rm --all -f # opkuisen
podman network prune; sudo podman network prune
sudo podman run -d --name myhttpd --network host ubi10/ubi sh -c "dnf install -y httpd && httpd -D FOREGROUND" 
sudo podman exec -it myhttpd ip addr show # toont IP van host
curl localhost # werkt

# vanuit een andere container toegang krijgen tot host webserver 
podman run --rm --network host ubi10/ubi curl http://localhost # --rm zorgt ervoor dat container verwijderd wordt na exit, 


## macvlan netwerk
#containers eigen mac en ip in netwerk van host
podman rm --all -f; sudo podman rm --all -f # opkuisen
podman network prune; sudo podman network prune 
nmcli connection show # toont netwerkverbindingen
nmcli connection show ens160 |grep ipv4.address # toont IP adres van ens160
nmcli connection show ens160 |grep ipv4.dns # toont DNS servers van ens160
nmcli connection show ens160 |grep ipv4.gateway # toont gateway van ens160
# aanmaken macvlan netwerk
sudo podman network create -d macvlan  --subnet 192.168.112.0/24 --gateway 192.168.112.2  -o parent=ens160  macvlan_netwerk macvlan_netwerk
sudo podman network ls 

# nieuwe container in macvlan netwerk
sudo podman run --detach -it --name contiis3 --hostname contiis3 --network macvlan_netwerk --ip 192.168.112.180 ubi10/ubi 
sudo podman exec -it contiis3 bash
ip addr # eigen ip
ip route # default via gateway
cat /etc/resolv.conf # toont dns servers van host

dnf install -y iputils
ping -c 1 www.google.com # werkt
dnf install -y httpd # webserver installeren
httpd 
curl 192.168.112.180
# vanaf windows machine
http://192.168.112.100 # zou de webpagina moeten tonen
# vanaf andere container
sudo podman run --detach -it --name containerX --hostname containerX --network macvlan_netwerk  --ip 192.168.112.181 ubi10/ubi 
sudo podman exec -it containerX bash
dnf install -y iputils curl 
curl http://192.168.112.180 # werkt

# scheiding met host 
# geen virtuele bridge met host, verkeer gaat rechtstreeks via fysieke netwerk 
# daardoor ziet de host eigen containers niet, tenzij je een extra interface toevoegt aan host in hetzelfde netwerk
# op host
ping -c 1 192.168.112.100 # werkt niet
sudo ip link add macvlan_host link ens160 type macvlan mode bridge # extra macvlan interface op host
sudo ip addr add 192.168.112.22/24 dev macvlan_host
sudo ip link set macvlan_host up
ping -c 1 192.168.112.100 # werkt nu wel

# opkuisen
sudo ip link del macvlan_host

# ipvlan
# containers eigen ip in netwerk van host maar zonder extra mac adressen
podman rm --all -f; sudo podman rm --all -f # opkuisen
podman network prune; sudo podman network prune 

sudo podman network create -d ipvlan --subnet 192.168.112.0/24 --gateway 192.168.112.2 -o parent=ens160 ipvlan_netwerk ipvlan_netwerk 
sudo podman network ls 

# nieuwe container in ipvlan netwerk
sudo podman run --detach -it --name contiis4 --hostname contiis4 --network ipvlan_netwerk --ip 192.168.112.180 ubi10/ubi 
sudo podman exec -it contiis4 bash 
ip addr # eigen ip
ip route # default via gateway
cat /etc/resolv.conf # toont dns servers van host
dnf install -y iputils
ping -c 1 www.google.com # werkt
dnf install -y httpd # webserver installeren
httpd
curl 192.168.112.180 
exit 
# vanaf windows machine
http://192.168.112.180 # zou de webpagina moeten tonen
# vanaf andere container
sudo podman run --detach -it --name containerY --hostname containerY --network ipvlan_netwerk  --ip 192.168.112.181 ubi10/ubi 
sudo podman exec -it containerY bash 
dnf install -y iputils curl
curl http://192.168.112.180 # werkt
exit 

# scheiding met host
# geen virtuele bridge met host, verkeer gaat rechtstreeks via fysieke netwerk
# valt op te lossen door een ipvlan"gateway" toe te voegen 
# op host
sudo ip link add ipvlan_host link ens160 type ipvlan 
sudo ip addr add 192.168.112.222/24 dev ipvlan_host 
sudo ip link set ipvlan_host up # ssh valt weg imdat host geen extra mac adressen kan aanmaken

# Lokale volumes koppelen aan containers 
## named volumes, gemaakt en beheerd door podman
## bind mounts, bestaande mappen op host koppelen aan container
## tmpf volumes, data aleen in geheugen, verdwijnt na herstart host
## remote volumes, opslag op externe systemen zoals NFS
## ISCSI- integratie, Maak verbinding met een iSCSI-target op de host en koppel het als block device of filesystem. 

# Stateless vs statefull 
# stateless = geen data bewaren na stoppen container
# statefull = data bewaren na stoppen container

# Named volumes
podman rm --all -f; sudo podman rm --all -f # opkuisen
podman network prune; sudo podman network prune
sudo ip link delete ipvlan_host # opkuisen ipvlan host interface
sudo systemctl restart sshd # ssh herstarten na netwerk wijzigingen

# volume aanmaken
podman volume create mijn_data_volume2 --label "project=my_project" mijn_data_volume
podman run -d --name conta -v mijn_data_volume:/test ubi10/ubi-init
podman exec -it conta bash
echo "Dit is wat data" > /test/data.txt
exit
podman rm conta -f
ls -l /home/student/.local/share/containers/storage/volumes/mijn_data_volume/_data 

podman run -d --name contb -v mijn_data_volume:/test ubi10/ubi-init 
podman exec -it contb bash -c "cat /test/bestandtest.txt" # toont de data

podman volume ls 
podman volume ls -q # toont enkel volume namen
podman rm contb -f 
podman volume rm $(podman volume ls -q)  # verwijder alle volumes

sudo podman volume create mijn_data_volume3 
sudo podman volume inspect mijn_data_volume3 # mountpoint is nu /var/lib/containers/storage/volumes/...
sudo podman volume rm mijn_data_volume3 

# Bind mounts
sudo mkdir -p /srv/contdata 
echo "Dit is wat data in bind mount" | sudo tee /srv/contdata/binddata.txt
sudo podman run -d --name cont1 --hostname cont1 -v /srv/contdata:/data:Z ubi10/ubi-init 
sudo podman exec -it cont1 bash -c "cat /data/binddata.txt" # toont de data
sudo podman exec -it cont1 bash -c "echo 'Meer data' >> /data/binddata.txt"
cat /srv/contdata/binddata.txt # toont de extra data
sudo podman stop cont1 

# tmpfs volumes
# niet beschikbaar nadat container is afgesloten
podman run --detach -i --name mijn_container --tmpfs /tijdelijk:rw,size=64M ubi10/ubi
podman exec -it mijn_container bash
df -h /tijdelijk # toont tmpfs met grootte 64M
dd if=/dev/zero of=/tijdelijk/testfile.img bs=10M count=1 
df -h /tijdelijk # toont gebruikte ruimte, 10M gebruikt
exit

# remote volumes toevoegen aan containers 
# map aanmaken op client, mounten op server, dontainer maakt gebruik van die map op server
# op client
sudo dnf install -y nfs-utils
sudo mkdir -p /srv/gedeeld 
echo 'Dit zijn gegevens' | sudo tee /srv/gedeeld/data.txt 

sudo nano /etc/exports 
/srv/gedeeld 192.168.112.100(rw) 

sudo systemctl enable --now nfs-server 
sudo systemctl status nfs-server
sudo exportfs -rav exporting 
sudo firewall-cmd --zone=public --permanent --addservice=nfs 
sudo firewall-cmd --zone=public --permanent --addservice=mountd 
sudo firewall-cmd --zone=public --permanent --addservice=rpc-bind 
sudo systemctl restart firewalld 

sudo dnf install -y nfs-utils
sudo mkdir -p /nfs/gedeeld
sudo mount -t nfs 192.168.112.200:/srv/gedeeld /nfs/gedeeld

sudo podman run -d --name contV --hostname contV  -v /nfs/gedeeld:/contdata ubi10/ubi-init 
sudo podman exec -it contV bash -c 'cat /contdata/data.txt' 

# 6 Podman images 
# 6.2 Webserver 
less /etc/containers/registries.conf # staan de registries in waar podman images kan ophalen

podman pull registry.access.redhat.com/ubi10/nginx-126 
podman inspect --format '{{json .Config}}' registry.access.redhat.com/ubi10/nginx-126 | jq 

# directory structuur maken 
sudo mkdir -p /wwwdata/html
sudo echo "Hello from Podman Nginx Webserver" | sudo tee /wwwdata/html/index.html
cat /wwwdata/html/index.html
sudo podman run -d --name nginx -p 8080:8080 -v /wwwdata/html:/opt/app-root/src:Z ubi10/nginx-126 nginx -g "daemon off;" 

# Database server 
podman search mariadb 
podman login registry.redhat.io
podman pull registry.redhat.io/rhel10/mariadb-1011 
podman inspect --format '{{json .Config}}' registry.redhat.io/rhel10/mariadb-1011 | jq 
podman ps 
sudo dnf install mariadb 
mysql -h 127.0.0.1 -p 3306 -u student -p testdb
exit 

# Wordpress 
## podman volumes aanmaken 
podman volume create mysql-data 
podman volume create 
## podman netwerk aanmaken
podman network create wpnet
## mariadb container starten
podman run -d --name mariadb --network wpnet -e MARIADB_ROOT_PASSWORD='ServerXXdocker007' -e MARIADB_DATABASE='wordpress' -e MARIADB_USER='wp' -e MARIADB_PASSWORD='ServerXXdocker1' -v mysqldata:/var/lib/mysql:Z docker.io/library/mariadb:latest 
podman logs -f mariadb # checken of maria connecties vraagt 
# wordpress container starten
podman run -d --name wordpress --network wpnet -p 8080:80 -e WORDPRESS_DB_HOST='mariadb:3306' -e WORDPRESS_DB_USER='wp' -e WORDPRESS_DB_PASSWORD='ServerXXdocker1' -e WORDPRESS_DB_NAME='wordpress' -v wp-content:/var/www/html/wp-content:Z docker.io/library/wordpress:latest … 
netstat -tlpn | grep 8080 # checken of poort open is
http://localhost:8080  # wordpress installatiepagina
# inloggen op wordpress met admin en wachtwoord dat je gekozen hebt

# 7 Podman Compose 
sudo dnf install -y python3-pip
pip3 install podman-compose
podman-compose 
podman-compose version

# Componenten van een yaml-bestand 
## services 
## networks
## volumes
## depends_on 
## environment
## command 

# Voorbeeld 1 gedeelde map 
services:   
    config_writer: 
    image: registry.access.redhat.com/ubi10/ubi     
    container_name: config_writer     
    volumes: 
-	shared_volume:/config:z     
    command: > 
      /bin/bash -c "sleep 5; 
      echo 'config=true' > /config/appsettings.txt; 
      echo 'Configuratiebestand geschreven naar /config/appsettings.txt';       sleep 20" 
      
   app: 
    image: registry.access.redhat.com/ubi10/ubi     
    container_name: app     
    depends_on:       
        - config_writer     
    volumes: 
        -	shared_volume:/app_config:z     
        command: > 
        /bin/bash -c "sleep 10; 
        if [ -f /app_config/appsettings.txt ]; then         
        cat /app_config/appsettings.txt;       
        else 
        echo 'Configuratiebestand niet gevonden.';       
        fi"  

volumes: 
    shared_volume: 
# bestand opslaan als podman-compose-oefening1.yaml
mkdir voorbeeld1
nano voorbeeld1/compose.yml

cd voorbeeld1
podman-compose up 

# logs bekijken 
podman-compose logs config_writer
podman-compose logs app

podman-compose down
podman ps -a # toont geen containers meer
ls  /home/student/.local/share/containers/storage/volumes/voorbeeld1_shared_volume/_data # toont data in volume, podman compose down -v verwijdert volumes ook

# podman-compose down vs podman-compose stop 
# podman-compose down stopt en verwijdert containers, netwerken, volumes en images die in het compose bestand zijn gedefinieerd
# podman-compose stop stopt enkel de containers, maar laat de netwerken, volumes en images

# podman-compose up -d # detached mode
# podman-compose --help # toont alle opties

# voorbeeld 2 Wordpress 
mkdir wordpressmysql 
nano wordpressmysql/compose.yml
      services:
        mariadb:
          image: mariadb:latest
          container_name: mariadb
          restart: always
          environment:
            MARIADB_ROOT_PASSWORD: ServerXXdocker007
            MARIADB_DATABASE: wordpress
            MARIADB_USER: wp
            MARIADB_PASSWORD: ServerXXdocker1
          volumes:
            - mysql-data:/var/lib/mysql:Z
          networks:
            - wpnet

        wordpress:
          image: wordpress:latest
          container_name: wordpress
          restart: always
          ports:
            - "8080:80"
          environment:
            WORDPRESS_DB_HOST: mariadb:3306
            WORDPRESS_DB_USER: wp
            WORDPRESS_DB_PASSWORD: ServerXXdocker1
            WORDPRESS_DB_NAME: wordpress
          volumes:
            - wp-content:/var/www/html/wp-content:Z
          networks:
            - wpnet

      volumes:
        mysql-data:
        wp-content:

      networks:
        wpnet:

cd wordpressmysql
podman-compose up

# 8 Podman Compose in combinatie met containerfile
# Containerfile is een script om een image te bouwen
# podman-compose kan je meerdere containers definieren adhv images 

# voorbeeld1 
mkdir vb1 
nano vb1/Dockerfile 
FROM registry.access.redhat.com/ubi10/ubi 
COPY script.sh /scripts/script.sh 
RUN chmod +x /scripts/script.sh 
WORKDIR /scripts 
CMD ["/bin/bash", "./script.sh"] 

nano vb1/script.sh
#!/bin/bash echo "Hallo, dit is een bash-script dat draait in een RHEL-container!" 

nano vb1/compose.yml
version: "3.8"

services:
  bashrunner:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: bashrunner
    networks:
      - bashnet

networks:
  bashnet:
    driver: bridge

cd vb1
podman-compose up --build
podman-compose up # kan zonder build omdat image al gebouwd is

# Voorbeeld 2 
mkdir -p vb2/mywebsite 
nano vb2/Containerfile
FROM registry.access.redhat.com/ubi10/httpd-24 
COPY mywebsite/ /var/www/html/ 
EXPOSE 8080  

nano vb2/mywebsite/index.html
<head> 
    <title>Voorbeeld 2 website</title> 
</head> 
    <body> 
        <h1>Welkom bij Voorbeeld 2 website!</h1> 
    </body> 
</html> 

nano vb2/compose.yml
version: "3.8"
services:
  webserver:
    build:
      context: .
      dockerfile: Containerfile
    image: wwwimage
    container_name: webserver
    ports:
      - "8080:8080"
    networks:
      - webnet

networks:
  webnet: {}

cd vb2
podman-compose up --build

curl http://localhost:8080

# 9 Podman pods 
# pod = groep van containers die netwerk en opslag delen, bevat altijd infra container

podman pod create --name mypod 
podman pod ps 
podman ps -a --pod 
podman run -dt --name myubi --pod mypod registry.access.redhat.com/ubi10/ubi /bin/bash 
podman pod ps 
podman ps -a --pod
podman pod top mypod # toont processen in pod
podman pod stats -a --no-stream # toont resource gebruik van pod
podman pod inspect mypod 
podman pod stop mypod
podman ps -a --pod
podman pod rm mypod

## wordpress 
podman pod create --name wp-pod -p 8080:80 
podman run -d --restart=always --pod=wp-pod -e MYSQL_ROOT_PASSWORD="dbpass" -e MYSQL_DATABASE="wp" -eMYSQL_USER="wordpress" -e MYSQL_PASSWORD="wppass" --name=wp-db mariadb 
podman ps -a --pod # infra container is automatisch aangemaakt
podman run -d --restart=always --pod=wp-pod -e WORDPRESS_DB_NAME="wp" -e WORDPRESS_DB_USER="wordpress" -e WORDPRESS_DB_PASSWORD="wppass" -e WORDPRESS_DB_HOST="127.0.0.1" --name wp-web wordpress  
podman ps -a --pod
http://localhost:8080
podman pod rm wp-pod -f

# met gegevens op server bewaren
mkdir -p wpdata/{html,db} 
podman pod create --name wp-pod -p 8080:80 
podman run -d   --pod wp-pod   --name wp-db   -e MYSQL_ROOT_PASSWORD="admin123"   -e MYSQL_DATABASE="wordpress"   -e MYSQL_USER="wpuser"   -e MYSQL_PASSWORD="user123"   -v /home/student/wpdata/db:/var/lib/mysql:Z   docker.io/library/mariadb:latest 
podman run -d --pod wp-pod --name wp-app -e WORDPRESS_DB_HOST="127.0.0.1" -e WORDPRESS_DB_NAME="wordpress" -e WORDPRESS_DB_USER="wpuser" -e WORDPRESS_DB_PASSWORD="user123" -v $HOME/wpdata/html:/var/www/html:Z docker.io/library/wordpress:latest 

podman ps -a --pod
podman pod stop wp-pod 
podman pod rm wp-pod -f 

# je kan nogsteeds een nieuwe pod aanmaken met dezelfde naam en de data blijft bewaard
podman pod create --name wp-pod2 -p 8080:80
podman run -d   --pod wp-pod2   --name wp-db   -e MYSQL_ROOT_PASSWORD="admin123"   -e MYSQL_DATABASE="wordpress"   -e MYSQL_USER="wpuser"   -e MYSQL_PASSWORD="user123" -v /home/student/wpdata/db:/var/lib/mysql:Z   docker.io/library/mariadb:latest
podman run -d --pod wp-pod2 --name wp-app -e WORDPRESS_DB_HOST="127.0.0.1" -e WORDPRESS_DB_NAME="wordpress" -e WORDPRESS_DB_USER="wpuser" -e WORDPRESS_DB_PASSWORD="user123" -v $HOME/wpdata/html:/var/www/html:Z docker.io/library/wordpress:latest 
podman ps -a --pod
http://localhost:8080

# 10 Storage infrastructure
# opslag systemen 
# DAS - Direct Attached Storage 
# SAN - Storage Area Network
# NAS - Network Attached Storage

# ISCSI
TRUENAS - VMNET2 Host only - SERVERXX - VMNET8 NAT - WINDOWS host - INTERNET 
10.10.10.x -     - 10.10.10.x     - 192.168112.10  - 192.168.112.1 

#Truenas configureren
# 10 iscsi tekst