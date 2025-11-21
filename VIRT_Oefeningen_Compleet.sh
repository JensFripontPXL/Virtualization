#!/bin/bash
# ============================================
# VIRTUALIZATION - ALLE OEFENINGEN MET OPLOSSINGEN
# Gebaseerd op cursusmateriaal en opgaven
# ============================================

# ============================================
# OEFENING 1 - Docker en Podman Installatie + Beheer op Afstand
# ============================================

# OPGAVE 1:
# Stel in dat de gebruiker student docker kan gebruiken zonder steeds sudo te moeten ingeven?
#
# OPLOSSING:
sudo usermod -aG docker student
# Log uit en opnieuw in, of gebruik:
newgrp docker
# Verificatie:
groups student
docker ps  # Zou nu moeten werken zonder sudo


# OPGAVE 2:
# Stel in dat je vanaf Client<jeinitialen> op volgende manier verbinding kan maken met Server<jeinitialen>.
# student@clientXX:~$ ssh student@serverXX
# student@serverxx's password:
# ...
# student@serverXX:~$
#
# OPLOSSING:
# A. Op BEIDE server en client: SSH service inschakelen en starten
sudo systemctl enable --now sshd
sudo systemctl status sshd  # Controleer of actief

# B. Op client: Hostname mapping toevoegen aan /etc/hosts
echo "192.168.112.100  serverJF" | sudo tee -a /etc/hosts

# C. Firewall configureren (indien actief)
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# D. Verificatie vanaf client:
ssh student@serverJF
# Voer wachtwoord in, je zou nu verbonden moeten zijn


# OPGAVE 3:
# Maak Docker "extern toegankelijk" zoals voor Docker beschreven in 3.3.
# Configureer hiervoor ook de firewall.
#
# OPLOSSING:
# A. Op SERVER: Docker daemon configureren voor externe toegang
sudo nano /etc/docker/daemon.json
# Inhoud toevoegen:
# {
#   "hosts": ["tcp://0.0.0.0:2376", "unix:///var/run/docker.sock"]
# }

# B. Systemd service file aanpassen
sudo nano /usr/lib/systemd/system/docker.service
# Zoek de regel:
# ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
# Vervang door:
# ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock

# C. Systemd herladen en Docker herstarten
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker

# D. Firewall configureren
sudo firewall-cmd --permanent --add-port=2376/tcp
sudo firewall-cmd --reload

# E. Op CLIENT: Docker CLI installeren
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce-cli

# F. Op CLIENT: Testen van externe verbinding
docker -H tcp://192.168.112.100:2376 version
docker -H tcp://serverJF:2376 ps

# EXTRA: Omgevingsvariabele instellen voor gemak
export DOCKER_HOST=tcp://192.168.112.100:2376
docker version  # Nu zonder -H optie


# OPGAVE 4:
# Stel in dat Podman "automatisch extern toegankelijk" wordt gemaakt bij het opstarten van het systeem.
# Tip: maak een .service-file aan.
#
# OPLOSSING:

# METHODE A: Podman socket gebruiken (eenvoudigste):
# A1. Podman socket enablen voor systemd (rootless)
systemctl --user enable --now podman.socket
systemctl --user status podman.socket

# A2. Voor root podman (indien nodig):
sudo systemctl enable --now podman.socket
sudo systemctl status podman.socket

# A3. Verificatie:
ls -l /run/user/$(id -u)/podman/podman.sock  # Rootless
sudo ls -l /run/podman/podman.sock           # Root

# METHODE B: Custom TCP service maken (zoals Docker):
# B1. Maak custom service file:
mkdir -p ~/.config/systemd/user/
nano ~/.config/systemd/user/podman-tcp.service

# B2. Inhoud van service file:
# [Unit]
# Description=Podman API Service TCP
# After=network.target
# 
# [Service]
# Type=simple
# ExecStart=/usr/bin/podman system service --time=0 tcp:0.0.0.0:2375
# Restart=on-failure
# 
# [Install]
# WantedBy=default.target

# B3. Service activeren:
systemctl --user daemon-reload
systemctl --user enable --now podman-tcp.service
systemctl --user status podman-tcp.service

# B4. Firewall configureren:
sudo firewall-cmd --permanent --add-port=2375/tcp
sudo firewall-cmd --reload

# B5. Testen vanaf client:
curl http://192.168.112.100:2375/version


# OPGAVE 5:
# Je hebt tot nu toe een wachtwoord nodig om verbinding te maken via SSH met Server<jeinitialen> 
# vanaf je Windows VMware Host. Zorg ervoor dat dit mogelijk wordt zonder wachtwoord in te geven.
#
# OPLOSSING: Passwordless SSH setup met SSH keys

# A. Op CLIENT/Windows VMware Host: SSH key genereren (indien nog niet bestaat)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
# Druk Enter (geen passphrase) voor volledig passwordless

# B. Public key kopiëren naar server:
ssh-copy-id student@serverJF
# Of handmatig:
cat ~/.ssh/id_rsa.pub | ssh student@serverJF "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# C. Permissies controleren op server:
ssh student@serverJF
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit

# D. Verificatie: SSH zonder wachtwoord
ssh student@serverJF
# Zou nu zonder wachtwoord moeten werken

# E. Troubleshooting: Op server SSH config checken
sudo nano /etc/ssh/sshd_config
# Zorg dat volgende lijnen actief zijn (uncomment indien nodig):
# PubkeyAuthentication yes
# PasswordAuthentication yes  # Kan op 'no' gezet worden voor extra veiligheid
sudo systemctl restart sshd


# OPGAVE 6:
# We willen een snelkoppeling met de naam Server<jeintialen> op het bureaublad zodat er 
# een verbinding als student met Server<jeinitialen> kan opgezet worden zonder een wachtwoord in te geven.
#
# OPLOSSING:

# OPTIE A: Linux Desktop (GNOME/KDE):
# A1. Desktop entry bestand maken:
nano ~/Desktop/ServerJF.desktop

# A2. Inhoud:
# [Desktop Entry]
# Version=1.0
# Type=Application
# Name=ServerJF
# Comment=SSH naar ServerJF
# Exec=gnome-terminal -- ssh student@serverJF
# Icon=utilities-terminal
# Terminal=false
# Categories=Network;

# A3. Executable maken:
chmod +x ~/Desktop/ServerJF.desktop


# OPTIE B: Windows (indien VMware Host Windows is):
# B1. Maak .bat bestand:
# Rechtermuisknop op bureaublad > Nieuw > Tekstbestand
# Naam: ServerJF.bat
# Inhoud:
# @echo off
# ssh student@serverJF
# pause

# B2. Of .rdp shortcut voor SSH (met PuTTY):
# Installeer PuTTY
# Maak shortcut met target:
# "C:\Program Files\PuTTY\putty.exe" -ssh student@192.168.112.100 -i "C:\path\to\privatekey.ppk"


# OPTIE C: SSH config shortcut (meest elegante oplossing):
# C1. Bewerk ~/.ssh/config:
nano ~/.ssh/config

# C2. Voeg toe:
# Host serverJF
#     HostName 192.168.112.100
#     User student
#     IdentityFile ~/.ssh/id_rsa

# C3. Nu werkt simpelweg:
ssh serverJF


# ============================================
# OEFENING 2 - Podman Basis Commands
# ============================================

# OPGAVE 1:
# Download de image voor apache van de Redhat Registry
#
# OPLOSSING:
podman pull registry.access.redhat.com/ubi10/httpd-24
# Verificatie:
podman images | grep httpd


# OPGAVE 2:
# Download de image voor nginx van Docker Hub
#
# OPLOSSING:
podman pull docker.io/library/nginx:latest
# Of korter:
podman pull nginx:latest
# Verificatie:
podman images | grep nginx


# OPGAVE 3:
# Download de Universal Base Image van Red Hat 10
#
# OPLOSSING:
podman pull registry.access.redhat.com/ubi10/ubi:latest
# Verificatie:
podman images | grep ubi


# OPGAVE 4:
# Geef een lijst van alle images die je hebt gedownload
#
# OPLOSSING:
podman images
# Of met meer details:
podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
# Of alleen IDs:
podman images -q


# OPGAVE 5:
# Start de Universal Base Image als een container en laat de inhoud van het /etc/hosts bestand tonen.
# De container stopt automatisch na het uitvoeren van de opdracht.
#
# OPLOSSING:
podman run --rm registry.access.redhat.com/ubi10/ubi:latest cat /etc/hosts
# --rm zorgt dat container automatisch verwijderd wordt na stoppen


# OPGAVE 6:
# Start de Universal Base Image als een container en start een interactieve shell.
# Sluit de shell af zonder de container te stoppen.
#
# OPLOSSING:
# A. Start interactieve container:
podman run -it --name myubi registry.access.redhat.com/ubi10/ubi:latest /bin/bash

# B. In de container: druk CTRL+P gevolgd door CTRL+Q (detach zonder stoppen)
# Of gebruik in aparte terminal:
podman exec -it myubi /bin/bash


# OPGAVE 7:
# Start de Universal Base Image als een container die op de achtergrond blijft draaien.
#
# OPLOSSING:
# METHODE 1: Sleep infinity (meest gebruikte):
podman run -d --name ubi-background registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# METHODE 2: Tail -f (houdt container actief):
podman run -d --name ubi-bg2 registry.access.redhat.com/ubi10/ubi:latest tail -f /dev/null

# METHODE 3: Bash met -it in detached mode:
podman run -d -it --name ubi-bg3 registry.access.redhat.com/ubi10/ubi:latest /bin/bash

# METHODE 4: While loop:
podman run -d --name ubi-bg4 registry.access.redhat.com/ubi10/ubi:latest bash -c "while true; do sleep 30; done"

# METHODE 5: Cat (simpel):
podman run -d --name ubi-bg5 registry.access.redhat.com/ubi10/ubi:latest cat

# Verificatie:
podman ps


# OPGAVE 8:
# Start een container met de image ubi-init en voer daarna het commando ps uit in de container 
# zonder een shell te starten.
#
# OPLOSSING:
# A. Start ubi-init container:
podman run -d --name ubi-init-container registry.access.redhat.com/ubi10/ubi-init:latest

# B. Voer ps commando uit zonder shell:
podman exec ubi-init-container ps aux
# Of zonder aux opties:
podman exec ubi-init-container ps


# OPGAVE 9:
# Start een container die snel gestopt kan worden.
#
# OPLOSSING:
# METHODE 1: Container met --init flag (zorgt voor proper signal handling):
podman run -d --init --name fast-stop registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# METHODE 2: Container met SIGTERM signal handling:
podman run -d --stop-signal SIGTERM --name fast-stop2 registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# METHODE 3: Gebruik ubi-init (heeft ingebouwd init systeem):
podman run -d --name fast-stop3 registry.access.redhat.com/ubi10/ubi-init:latest

# Testen:
time podman stop fast-stop   # Zou snel moeten stoppen (< 1 seconde)

# UITLEG: 
# - --init zorgt voor tini init process (PID 1) die signals proper afhandelt
# - Zonder init duurt stop 10 seconden (default timeout)
# - Met init stopt container onmiddellijk bij SIGTERM


# OPGAVE 10:
# Start een container en geef deze een naam.
#
# OPLOSSING:
podman run -d --name mijn-container registry.access.redhat.com/ubi10/ubi:latest sleep infinity
# Verificatie:
podman ps --filter name=mijn-container


# OPGAVE 11:
# Ping naar www.pxl.be vanuit een container.
#
# OPLOSSING:
# METHODE 1: Installeer iputils in bestaande container:
podman exec -it mijn-container bash
dnf install -y iputils
ping -c 4 www.pxl.be
exit

# METHODE 2: One-liner zonder interactieve shell:
podman exec mijn-container bash -c "dnf install -y iputils && ping -c 4 www.pxl.be"

# METHODE 3: Nieuwe container met iputils pre-installed:
podman run --rm registry.access.redhat.com/ubi10/ubi:latest bash -c "dnf install -y iputils && ping -c 4 www.pxl.be"


# OPGAVE 12:
# Voer het commando ls uit in een draaiende container zonder een shell te starten.
#
# OPLOSSING:
podman exec mijn-container ls -la /
# Of specifieke directory:
podman exec mijn-container ls -lh /etc
podman exec mijn-container ls /usr/bin


# OPGAVE 13:
# Verwijder een container.
#
# OPLOSSING:
# A. Stop eerst de container:
podman stop mijn-container
podman rm mijn-container

# B. Of forceer verwijdering (stopt en verwijdert in 1 commando):
podman rm -f mijn-container

# Verificatie:
podman ps -a


# OPGAVE 14:
# Verwijder alle containers.
#
# OPLOSSING:
# METHODE 1: Alle containers (actieve + gestopte) forceren verwijderen:
podman rm $(podman ps -a -q) -f

# METHODE 2: --all flag:
podman rm --all -f

# METHODE 3: Container prune (verwijdert alleen gestopte):
podman container prune -f

# Verificatie:
podman ps -a  # Zou leeg moeten zijn


# OPGAVE 15:
# Verwijder de ubi-init image.
#
# OPLOSSING:
# A. Eerst alle containers met deze image verwijderen:
podman rm $(podman ps -a -q --filter ancestor=registry.access.redhat.com/ubi10/ubi-init:latest) -f

# B. Image verwijderen:
podman rmi registry.access.redhat.com/ubi10/ubi-init:latest
# Of met image ID:
podman rmi <IMAGE_ID>

# Verificatie:
podman images | grep ubi-init


# OPGAVE 16:
# Verwijder alle images.
#
# OPLOSSING:
# METHODE 1: Alle images verwijderen:
podman rmi $(podman images -q) -f

# METHODE 2: --all flag:
podman rmi --all -f

# METHODE 3: Image prune (verwijdert ongebruikte images):
podman image prune -a -f

# METHODE 4: System prune (verwijdert alles: containers, images, volumes):
podman system prune -a --volumes -f

# Verificatie:
podman images  # Zou leeg moeten zijn


# ============================================
# OEFENING 3 - Podman Interactieve Container & Webserver
# ============================================

# OPGAVE 1:
# Start een container met de httpd-24 image op de achtergrond.
# De webserver moet bereikbaar zijn op poort 8080 van de host.
#
# OPLOSSING:
podman run -d --name myhttpd -p 8080:80 registry.access.redhat.com/ubi10/httpd-24:latest

# Verificatie:
podman ps
curl http://localhost:8080
# Of vanaf host browser: http://<server-ip>:8080


# OPGAVE 2:
# Maak verbinding met de draaiende httpd container en bekijk de configuratie bestanden.
#
# OPLOSSING:
# A. Interactieve shell in container:
podman exec -it myhttpd /bin/bash

# B. In de container: bekijk configuratie
cat /etc/httpd/conf/httpd.conf
ls -la /var/www/html/
cat /var/www/html/index.html

# C. Exit container:
exit


# OPGAVE 3:
# Pas de webpagina aan zodat deze een custom boodschap toont.
#
# OPLOSSING:
# METHODE 1: Direct vanaf host:
echo "<h1>Welkom bij mijn Podman Webserver!</h1>" | podman exec -i myhttpd tee /var/www/html/index.html

# METHODE 2: Via interactieve shell:
podman exec -it myhttpd bash
echo "<h1>Custom Webserver</h1><p>Door student JF</p>" > /var/www/html/index.html
exit

# Verificatie:
curl http://localhost:8080


# OPGAVE 4:
# Start een tweede container met nginx en maak deze bereikbaar op poort 8081.
#
# OPLOSSING:
podman run -d --name mynginx -p 8081:80 docker.io/library/nginx:latest

# Verificatie:
podman ps
curl http://localhost:8081


# OPGAVE 5:
# Test de communicatie tussen de twee containers (httpd en nginx).
#
# OPLOSSING:
# A. Van nginx container naar httpd:
podman exec -it mynginx bash
apt-get update && apt-get install -y curl
curl http://host.containers.internal:8080
exit

# B. Van httpd naar nginx:
podman exec -it myhttpd bash
dnf install -y curl
curl http://host.containers.internal:8081
exit

# UITLEG: 
# host.containers.internal is een speciale hostname die verwijst naar de host
# Containers kunnen via host ports met elkaar communiceren


# OPGAVE 6:
# Stop en verwijder beide containers.
#
# OPLOSSING:
podman stop myhttpd mynginx
podman rm myhttpd mynginx

# Of in één commando:
podman rm -f myhttpd mynginx

# Verificatie:
podman ps -a


# ============================================
# OEFENING 4 - Podman Dockerfiles/Containerfiles
# ============================================

# OPGAVE 1:
# Maak een Containerfile voor een DNS server met BIND.
# De container moet:
# - Gebruik maken van ubi10/ubi-init als basis image
# - BIND installeren
# - Configuratie bestanden bevatten
# - Automatisch de DNS server starten
#
# OPLOSSING:

# A. Directory structuur maken:
mkdir -p ~/oefening/scripts
cd ~/oefening

# B. Maak het Containerfile:
nano Dockerfile
# Inhoud:
# FROM registry.access.redhat.com/ubi10/ubi-init
# 
# # Bind + tools installeren
# RUN dnf -y install bind bind-utils procps-ng && dnf clean all
# 
# # Config & zone files
# COPY scripts/named.conf /etc/named.conf
# COPY scripts/abc.pri /var/named/abc.pri
# 
# # Vereiste directories + juiste rechten
# RUN mkdir -p /var/named \
#  && chown named:named /var/named \
#  && chmod 0750 /var/named \
#  && chown named:named /var/named/abc.pri /etc/named.conf \
#  && chmod 0640 /var/named/abc.pri /etc/named.conf
# 
# # Zorgt dat netjes gestopt wordt
# STOPSIGNAL SIGTERM
# 
# # Uitvoeren bij initialiseren container
# ENTRYPOINT ["/usr/sbin/named", "-g", "-u", "named", "-c", "/etc/named.conf"]
# 
# # Healthcheck (wordt named uitgevoerd)
# HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD \
#   pgrep named >/dev/null || exit 1

# C. Maak named.conf:
nano scripts/named.conf
# Inhoud:
# options {
#     directory "/var/named";
#     listen-on port 53 { any; };
#     allow-query { any; };
#     recursion yes;
#     allow-recursion { any; };
#     forwarders { 8.8.8.8; 8.8.4.4; };
#     forward only;
#     dnssec-validation no;
# };
# 
# zone "abc.pri" {
#     type master;
#     file "abc.pri";
# };

# D. Maak zone file:
nano scripts/abc.pri
# Inhoud:
# $TTL 8h
# $ORIGIN abc.pri.
# @   IN  SOA ns1.abc.pri. hostmaster.abc.pri. (
#         2025031701 ; serial (YYYYMMDDnn)
#         1d         ; refresh
#         3h         ; retry
#         3d         ; expire
#         3h         ; minimum TTL
# )
#     IN  NS  ns1.abc.pri.
# ns1 IN  A   127.0.0.1
# host IN  A   192.168.1.100


# OPGAVE 2:
# Build de DNS container image.
#
# OPLOSSING:
cd ~/oefening
podman build --format=docker -t contdns .

# Met --no-cache voor fresh build:
podman build --format=docker --no-cache -t contdns .

# Verificatie:
podman images | grep contdns


# OPGAVE 3:
# Start de DNS container en test of deze werkt.
#
# OPLOSSING:
# A. Container starten met poort mapping:
podman run -d --name contdns --hostname contdns -p 1053:53/udp -p 1053:53/tcp contdns

# Verificatie container draait:
podman ps

# B. Testen met dig:
dig @127.0.0.1 -p 1053 host.abc.pri

# C. Testen met nslookup:
nslookup host.abc.pri 127.0.0.1 -port=1053

# D. Healthcheck status bekijken:
podman inspect contdns | grep -A 10 Health


# OPGAVE 4:
# Maak een Containerfile voor een webserver met custom content.
# De webserver moet een custom HTML pagina tonen.
#
# OPLOSSING:

# A. Nieuwe directory:
mkdir -p ~/webserver/content
cd ~/webserver

# B. Custom HTML maken:
nano content/index.html
# Inhoud:
# <!DOCTYPE html>
# <html>
# <head>
#     <title>Mijn Container Webserver</title>
# </head>
# <body>
#     <h1>Welkom!</h1>
#     <p>Deze pagina draait in een container gebouwd met Podman.</p>
# </body>
# </html>

# C. Containerfile maken:
nano Dockerfile
# Inhoud:
# FROM registry.access.redhat.com/ubi10/httpd-24
# 
# # Custom HTML kopiëren
# COPY content/index.html /var/www/html/
# 
# # Juiste rechten
# RUN chown -R apache:apache /var/www/html
# 
# # Poort 80 exposen
# EXPOSE 80
# 
# # Webserver starten
# CMD ["/usr/bin/httpd", "-D", "FOREGROUND"]


# OPGAVE 5:
# Build en start de webserver container.
#
# OPLOSSING:
# A. Build:
cd ~/webserver
podman build -t myweb .

# B. Run:
podman run -d --name myweb -p 9090:80 myweb

# C. Test:
curl http://localhost:9090
# Of in browser: http://<server-ip>:9090


# OPGAVE 6:
# Commit een draaiende container naar een nieuwe image.
#
# OPLOSSING:
# A. Start een container en maak wijzigingen:
podman run -it --name temp-container registry.access.redhat.com/ubi10/ubi:latest bash
# In container:
dnf install -y httpd
echo "Test pagina" > /var/www/html/index.html
exit

# B. Commit container naar image:
podman commit temp-container my-custom-httpd

# C. Verificatie:
podman images | grep my-custom-httpd

# D. Test nieuwe image:
podman run -d --name test-custom -p 8082:80 my-custom-httpd /usr/sbin/httpd -D FOREGROUND
curl http://localhost:8082


# OPGAVE 7:
# Export en import een container image.
#
# OPLOSSING:
# A. Image exporteren naar tar file:
podman save -o contdns.tar localhost/contdns:latest

# B. Verificatie tar file:
ls -lh contdns.tar

# C. Image verwijderen (voor test):
podman rmi localhost/contdns:latest

# D. Image importeren:
podman load -i contdns.tar

# E. Verificatie:
podman images | grep contdns

# EXTRA: Image transfer naar andere host:
# scp contdns.tar student@otherserver:~/
# ssh student@otherserver
# podman load -i contdns.tar


# ============================================
# OEFENING 5 - Podman Networks
# ============================================

# OPGAVE 1:
# Toon alle beschikbare netwerken.
#
# OPLOSSING:
podman network ls

# Met details:
podman network inspect podman


# OPGAVE 2:
# Maak een custom bridge network met subnet 192.168.5.0/24 en gateway 192.168.5.1.
#
# OPLOSSING:
podman network create --subnet 192.168.5.0/24 --gateway 192.168.5.1 mynat

# Verificatie:
podman network ls
podman network inspect mynat


# OPGAVE 3:
# Start twee containers op het custom network en test de communicatie tussen beide.
#
# OPLOSSING:
# A. Oude containers opruimen:
podman rm --all -f

# B. Container 1 starten:
podman run -d -it --name C1 --hostname C1 --network mynat --ip 192.168.5.150 registry.access.redhat.com/ubi10/ubi-init

# C. Container 2 starten:
podman run -d -it --name C2 --hostname C2 --network mynat --ip 192.168.5.151 registry.access.redhat.com/ubi10/ubi-init

# D. Verificatie containers:
podman ps

# E. Test communicatie van C1 naar C2:
podman exec -it C1 bash
dnf install -y iputils
ping -c 3 C2
ping -c 3 192.168.5.151
exit

# F. Test van C2 naar C1:
podman exec -it C2 bash
dnf install -y iputils
ping -c 3 C1
ip a  # Bekijk IP configuratie
ip route  # Bekijk routing table
exit


# OPGAVE 4:
# Configureer een container die host.containers.internal kan gebruiken om de host te bereiken.
#
# OPLOSSING:
# A. Start webserver op host:
podman run -d --name hostweb -p 8080:80 registry.access.redhat.com/ubi10/httpd-24

# B. Start test container:
podman run --rm -it registry.access.redhat.com/ubi10/ubi bash

# C. In container: test verbinding naar host:
dnf install -y curl
curl -v http://host.containers.internal:8080
exit

# UITLEG:
# host.containers.internal is automatisch beschikbaar in containers
# Het wijst naar de host machine


# OPGAVE 5:
# Maak een macvlan network waarbij containers direct op het fysieke netwerk zitten.
#
# OPLOSSING:
# A. Macvlan network maken (pas interface naam aan):
podman network create -d macvlan --subnet 192.168.112.0/24 --gateway 192.168.112.2 -o parent=ens160 mymacvlan

# B. Container op macvlan starten:
podman run -d --name macvlan-test --network mymacvlan --ip 192.168.112.150 registry.access.redhat.com/ubi10/ubi-init

# C. Verificatie:
podman exec macvlan-test ip a

# LET OP: Container is nu direct bereikbaar op 192.168.112.150 vanaf fysiek netwerk


# OPGAVE 6:
# Verbind een container met meerdere netwerken tegelijk.
#
# OPLOSSING:
# A. Tweede netwerk maken:
podman network create --subnet 192.168.6.0/24 mynet2

# B. Container starten op eerste netwerk:
podman run -d --name multi-net --network mynat registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# C. Container verbinden met tweede netwerk:
podman network connect mynet2 multi-net

# D. Verificatie:
podman inspect multi-net | grep -A 20 Networks
podman exec multi-net ip a  # Zou meerdere interfaces moeten tonen

# E. Test beide netwerken:
podman exec multi-net bash -c "dnf install -y iputils && ping -c 2 192.168.5.150 && ping -c 2 192.168.6.1"


# OPGAVE 7:
# Verwijder een netwerk.
#
# OPLOSSING:
# A. Eerst alle containers op netwerk stoppen/verwijderen:
podman rm -f $(podman ps -a -q --filter network=mynet2)

# B. Netwerk verwijderen:
podman network rm mynet2

# C. Verificatie:
podman network ls


# ============================================
# OEFENING 6 - Podman Volumes
# ============================================

# OPGAVE 1:
# Maak een named volume.
#
# OPLOSSING:
podman volume create mydata

# Verificatie:
podman volume ls
podman volume inspect mydata


# OPGAVE 2:
# Start een container die de named volume gebruikt.
#
# OPLOSSING:
podman run -d --name vol-test -v mydata:/data registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# Test volume:
podman exec vol-test bash -c "echo 'Test data' > /data/test.txt"
podman exec vol-test cat /data/test.txt


# OPGAVE 3:
# Maak een tweede container die dezelfde volume mount en verifieer dat data persistent is.
#
# OPLOSSING:
# A. Tweede container starten:
podman run -d --name vol-test2 -v mydata:/shared-data registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# B. Verificatie data is beschikbaar:
podman exec vol-test2 cat /shared-data/test.txt
# Zou "Test data" moeten tonen

# C. Nieuwe data toevoegen vanaf container 2:
podman exec vol-test2 bash -c "echo 'Data from container 2' >> /shared-data/test.txt"

# D. Check vanaf container 1:
podman exec vol-test cat /data/test.txt
# Zou beide regels moeten tonen


# OPGAVE 4:
# Gebruik een bind mount om een host directory te mounten in een container.
#
# OPLOSSING:
# A. Directory op host maken:
mkdir -p ~/container-data
echo "Host data" > ~/container-data/host-file.txt

# B. Container starten met bind mount:
podman run -d --name bind-test -v ~/container-data:/mnt/host:Z registry.access.redhat.com/ubi10/ubi:latest sleep infinity

# C. Verificatie:
podman exec bind-test ls -la /mnt/host
podman exec bind-test cat /mnt/host/host-file.txt

# D. Wijziging vanuit container:
podman exec bind-test bash -c "echo 'Modified in container' >> /mnt/host/host-file.txt"

# E. Check op host:
cat ~/container-data/host-file.txt

# UITLEG :Z flag:
# :Z zorgt voor SELinux context relabeling (nodig op RHEL/Fedora)


# OPGAVE 5:
# Configureer Jellyfin media server met een persistent volume voor media.
#
# OPLOSSING:
# A. Volumes maken:
podman volume create jellyfin-config
podman volume create jellyfin-cache
mkdir -p ~/media/{movies,tv,music}

# B. Jellyfin container starten:
podman run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v jellyfin-config:/config:Z \
  -v jellyfin-cache:/cache:Z \
  -v ~/media:/media:Z \
  docker.io/jellyfin/jellyfin:latest

# C. Verificatie:
podman ps
podman logs jellyfin

# D. Open browser naar: http://<server-ip>:8096
# Volg setup wizard


# OPGAVE 6:
# Backup een volume.
#
# OPLOSSING:
# A. Volume backup naar tar:
podman run --rm -v mydata:/data -v ~/backups:/backup:Z registry.access.redhat.com/ubi10/ubi:latest tar czf /backup/mydata-backup.tar.gz -C /data .

# B. Verificatie:
ls -lh ~/backups/mydata-backup.tar.gz

# C. Restore volume (indien nodig):
# Nieuwe volume maken:
podman volume create mydata-restored

# Data terugzetten:
podman run --rm -v mydata-restored:/data -v ~/backups:/backup:Z registry.access.redhat.com/ubi10/ubi:latest tar xzf /backup/mydata-backup.tar.gz -C /data


# OPGAVE 7:
# Verwijder een volume.
#
# OPLOSSING:
# A. Eerst containers die volume gebruiken stoppen:
podman rm -f vol-test vol-test2

# B. Volume verwijderen:
podman volume rm mydata

# C. Verificatie:
podman volume ls


# OPGAVE 8:
# Verwijder alle ongebruikte volumes.
#
# OPLOSSING:
podman volume prune -f

# Verificatie:
podman volume ls


# ============================================
# EXTRA: Handige Troubleshooting Commands
# ============================================

# Container logs bekijken:
podman logs <container-name>
podman logs -f <container-name>  # Follow mode

# Container resource usage:
podman stats

# Container inspect (alle details):
podman inspect <container-name>

# Port mappings bekijken:
podman port <container-name>

# Container processen:
podman top <container-name>

# Container events monitoren:
podman events

# Disk usage:
podman system df

# Complete cleanup:
podman system prune -a --volumes -f

# Image history bekijken:
podman history <image-name>

# Container differences (vs image):
podman diff <container-name>

# Export container filesystem:
podman export <container-name> -o container.tar


# ============================================
# OEFENING 7 - Podman Compose
# ============================================

# OPGAVE 1:
# Installeer podman-compose op je systeem.
#
# OPLOSSING:
# METHODE 1: Via pip (Python package manager):
sudo dnf install -y python3-pip
pip3 install podman-compose

# METHODE 2: Via DNF (indien beschikbaar in repos):
sudo dnf install -y podman-compose

# METHODE 3: Direct van GitHub:
sudo curl -o /usr/local/bin/podman-compose https://raw.githubusercontent.com/containers/podman-compose/main/podman_compose.py
sudo chmod +x /usr/local/bin/podman-compose

# Verificatie:
podman-compose --version


# OPGAVE 2:
# Maak een docker-compose.yml bestand voor een eenvoudige webserver setup met nginx.
#
# OPLOSSING:
# A. Directory maken:
mkdir -p ~/compose-demo
cd ~/compose-demo

# B. docker-compose.yml maken:
nano docker-compose.yml

# Inhoud:
# version: '3'
# services:
#   web:
#     image: docker.io/library/nginx:latest
#     container_name: nginx-web
#     ports:
#       - "8080:80"
#     volumes:
#       - ./html:/usr/share/nginx/html:ro
#     restart: unless-stopped

# C. HTML directory en test pagina maken:
mkdir -p html
echo "<h1>Podman Compose Demo</h1>" > html/index.html


# OPGAVE 3:
# Start de compose stack.
#
# OPLOSSING:
cd ~/compose-demo
podman-compose up -d

# Verificatie:
podman-compose ps
podman ps
curl http://localhost:8080


# OPGAVE 4:
# Maak een multi-container applicatie met een database en webserver.
# De stack moet bestaan uit:
# - MariaDB database container
# - WordPress webserver container
# - Custom network
# - Persistent volumes
#
# OPLOSSING:
# A. Nieuwe directory:
mkdir -p ~/wordpress-stack
cd ~/wordpress-stack

# B. docker-compose.yml maken:
nano docker-compose.yml

# Inhoud:
# version: '3.8'
# 
# services:
#   db:
#     image: docker.io/library/mariadb:latest
#     container_name: wordpress-db
#     volumes:
#       - db_data:/var/lib/mysql
#     environment:
#       MYSQL_ROOT_PASSWORD: rootpassword
#       MYSQL_DATABASE: wordpress
#       MYSQL_USER: wpuser
#       MYSQL_PASSWORD: wppassword
#     networks:
#       - wordpress-net
#     restart: unless-stopped
# 
#   wordpress:
#     image: docker.io/library/wordpress:latest
#     container_name: wordpress-app
#     depends_on:
#       - db
#     ports:
#       - "8081:80"
#     volumes:
#       - wp_data:/var/www/html
#     environment:
#       WORDPRESS_DB_HOST: db:3306
#       WORDPRESS_DB_USER: wpuser
#       WORDPRESS_DB_PASSWORD: wppassword
#       WORDPRESS_DB_NAME: wordpress
#     networks:
#       - wordpress-net
#     restart: unless-stopped
# 
# volumes:
#   db_data:
#   wp_data:
# 
# networks:
#   wordpress-net:
#     driver: bridge


# OPGAVE 5:
# Start de WordPress stack en verifieer dat alles werkt.
#
# OPLOSSING:
cd ~/wordpress-stack
podman-compose up -d

# Verificatie:
podman-compose ps
podman network ls
podman volume ls

# Test WordPress:
# Open browser: http://<server-ip>:8081
# Volg WordPress setup wizard


# OPGAVE 6:
# Bekijk de logs van de containers in de compose stack.
#
# OPLOSSING:
cd ~/wordpress-stack

# Logs van alle services:
podman-compose logs

# Logs van specifieke service:
podman-compose logs wordpress
podman-compose logs db

# Follow mode (real-time):
podman-compose logs -f

# Laatste 50 regels:
podman-compose logs --tail=50


# OPGAVE 7:
# Stop en verwijder de compose stack (maar behoud volumes).
#
# OPLOSSING:
cd ~/wordpress-stack

# Stop containers:
podman-compose stop

# Stop en verwijder containers (volumes blijven):
podman-compose down

# Verificatie:
podman-compose ps
podman volume ls  # Volumes zijn nog aanwezig


# OPGAVE 8:
# Verwijder de compose stack inclusief volumes.
#
# OPLOSSING:
cd ~/wordpress-stack

# Verwijder alles inclusief volumes:
podman-compose down -v

# Verificatie:
podman volume ls  # Volumes zijn verwijderd


# OPGAVE 9:
# Maak een compose file voor een development environment met:
# - Redis cache
# - PostgreSQL database
# - Node.js applicatie container
#
# OPLOSSING:
# A. Directory maken:
mkdir -p ~/dev-stack
cd ~/dev-stack

# B. docker-compose.yml:
nano docker-compose.yml

# Inhoud:
# version: '3.8'
# 
# services:
#   redis:
#     image: docker.io/library/redis:alpine
#     container_name: dev-redis
#     ports:
#       - "6379:6379"
#     volumes:
#       - redis_data:/data
#     networks:
#       - dev-net
#     command: redis-server --appendonly yes
# 
#   postgres:
#     image: docker.io/library/postgres:15
#     container_name: dev-postgres
#     environment:
#       POSTGRES_USER: devuser
#       POSTGRES_PASSWORD: devpass
#       POSTGRES_DB: devdb
#     volumes:
#       - postgres_data:/var/lib/postgresql/data
#     ports:
#       - "5432:5432"
#     networks:
#       - dev-net
# 
#   app:
#     image: docker.io/library/node:18-alpine
#     container_name: dev-app
#     working_dir: /app
#     volumes:
#       - ./app:/app
#     ports:
#       - "3000:3000"
#     networks:
#       - dev-net
#     depends_on:
#       - redis
#       - postgres
#     command: sh -c "npm install && npm start"
#     environment:
#       REDIS_HOST: redis
#       REDIS_PORT: 6379
#       POSTGRES_HOST: postgres
#       POSTGRES_PORT: 5432
#       POSTGRES_USER: devuser
#       POSTGRES_PASSWORD: devpass
#       POSTGRES_DB: devdb
# 
# volumes:
#   redis_data:
#   postgres_data:
# 
# networks:
#   dev-net:
#     driver: bridge


# OPGAVE 10:
# Scale een service in een compose stack (meerdere replica's).
#
# OPLOSSING:
# A. Compose file met scalable service:
nano docker-compose.yml

# Inhoud:
# version: '3.8'
# services:
#   web:
#     image: docker.io/library/nginx:alpine
#     ports:
#       - "8080-8085:80"

# B. Start met scaling:
podman-compose up -d --scale web=3

# Verificatie:
podman-compose ps
podman ps


# OPGAVE 11:
# Gebruik environment variables in compose file.
#
# OPLOSSING:
# A. .env bestand maken:
cd ~/compose-demo
nano .env

# Inhoud:
# NGINX_PORT=8080
# NGINX_VERSION=latest
# PROJECT_NAME=myproject

# B. docker-compose.yml aanpassen:
nano docker-compose.yml

# Inhoud:
# version: '3.8'
# services:
#   web:
#     image: docker.io/library/nginx:${NGINX_VERSION}
#     container_name: ${PROJECT_NAME}-web
#     ports:
#       - "${NGINX_PORT}:80"

# C. Start stack:
podman-compose up -d


# OPGAVE 12:
# Maak een health check voor een service in compose.
#
# OPLOSSING:
nano docker-compose.yml

# Inhoud:
# version: '3.8'
# services:
#   web:
#     image: docker.io/library/nginx:latest
#     healthcheck:
#       test: ["CMD", "curl", "-f", "http://localhost"]
#       interval: 30s
#       timeout: 10s
#       retries: 3
#       start_period: 40s
#     ports:
#       - "8080:80"

# Start en check health:
podman-compose up -d
podman inspect <container-id> | grep -A 20 Health


# OPGAVE 13:
# Rebuild een service zonder de hele stack te herstarten.
#
# OPLOSSING:
cd ~/compose-demo

# Rebuild specifieke service:
podman-compose up -d --build web

# Of alleen rebuild zonder starten:
podman-compose build web


# OPGAVE 14:
# Export en backup een compose stack.
#
# OPLOSSING:
cd ~/wordpress-stack

# A. Export compose configuratie:
podman-compose config > compose-backup.yml

# B. Backup volumes:
mkdir -p ~/backups
podman volume export db_data -o ~/backups/db_data.tar
podman volume export wp_data -o ~/backups/wp_data.tar

# C. Backup complete stack met script:
nano backup-stack.sh
# #!/bin/bash
# COMPOSE_DIR=$(pwd)
# BACKUP_DIR=~/backups/$(date +%Y%m%d)
# mkdir -p $BACKUP_DIR
# cp docker-compose.yml $BACKUP_DIR/
# podman-compose ps -q | xargs -I {} podman export {} -o $BACKUP_DIR/container-{}.tar

chmod +x backup-stack.sh
./backup-stack.sh


# ============================================
# OEFENING 8 - TrueNAS & iSCSI Storage
# ============================================

# OPGAVE 1:
# Installeer de benodigde iSCSI initiator tools op RHEL.
#
# OPLOSSING:
sudo dnf install -y iscsi-initiator-utils

# Verificatie:
rpm -q iscsi-initiator-utils
systemctl status iscsid


# OPGAVE 2:
# Configureer de iSCSI initiator op je Linux systeem.
#
# OPLOSSING:
# A. iSCSI initiator naam instellen:
sudo nano /etc/iscsi/initiatorname.iscsi
# Voorbeeld inhoud:
# InitiatorName=iqn.2025-01.com.example:initiator01

# B. iSCSI daemon starten en enablen:
sudo systemctl enable --now iscsid
sudo systemctl enable --now iscsi

# C. Verificatie:
systemctl status iscsid
cat /etc/iscsi/initiatorname.iscsi


# OPGAVE 3:
# Discover iSCSI targets van TrueNAS server.
#
# OPLOSSING:
# A. Discovery uitvoeren (vervang IP met TrueNAS IP):
sudo iscsiadm -m discovery -t sendtargets -p 192.168.112.10

# Output toont beschikbare targets:
# 192.168.112.10:3260,1 iqn.2025-01.com.truenas:target01

# B. Bekijk gevonden targets:
sudo iscsiadm -m node

# C. Bekijk discovery database:
sudo iscsiadm -m discovery -P 1


# OPGAVE 4:
# Login op een iSCSI target en mount de storage.
#
# OPLOSSING:
# A. Login op target (vervang met jouw target name):
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --login

# B. Verificatie nieuwe disk:
lsblk
# Zou nieuwe disk moeten tonen (bijv. sdb)

# C. Bekijk session info:
sudo iscsiadm -m session -P 3

# D. Disk formatteren (indien nieuw):
sudo fdisk -l /dev/sdb
sudo mkfs.ext4 /dev/sdb

# E. Mount point maken en mounten:
sudo mkdir -p /mnt/iscsi-storage
sudo mount /dev/sdb /mnt/iscsi-storage

# F. Verificatie:
df -h | grep iscsi
lsblk


# OPGAVE 5:
# Configureer automatische mount bij boot voor iSCSI storage.
#
# OPLOSSING:
# A. iSCSI login automatisch maken:
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --op update -n node.startup -v automatic

# B. fstab entry toevoegen:
# Eerst UUID van disk vinden:
sudo blkid /dev/sdb

# fstab aanpassen:
sudo nano /etc/fstab
# Toevoegen (vervang UUID):
# UUID=your-uuid-here  /mnt/iscsi-storage  ext4  _netdev  0 0

# C. Netwerk services enablen:
sudo systemctl enable iscsi
sudo systemctl enable iscsid

# D. Test automount:
sudo umount /mnt/iscsi-storage
sudo mount -a
df -h | grep iscsi


# OPGAVE 6:
# Test de performance van de iSCSI storage.
#
# OPLOSSING:
# A. Write test:
sudo dd if=/dev/zero of=/mnt/iscsi-storage/testfile bs=1M count=1024 conv=fdatasync
# Bekijk throughput

# B. Read test:
sudo sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"
sudo dd if=/mnt/iscsi-storage/testfile of=/dev/null bs=1M

# C. Met fio (advanced):
sudo dnf install -y fio
sudo fio --name=randwrite --ioengine=libaio --iodepth=16 --rw=randwrite --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 --group_reporting --directory=/mnt/iscsi-storage

# D. Cleanup:
sudo rm /mnt/iscsi-storage/testfile


# OPGAVE 7:
# Logout van een iSCSI target.
#
# OPLOSSING:
# A. Eerst unmount:
sudo umount /mnt/iscsi-storage

# B. Logout van target:
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --logout

# C. Verificatie:
sudo iscsiadm -m session
lsblk  # iSCSI disk zou weg moeten zijn


# OPGAVE 8:
# Verwijder een iSCSI target configuratie.
#
# OPLOSSING:
# A. Eerst logout (indien nog ingelogd):
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --logout

# B. Verwijder node configuratie:
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --op delete

# C. Verificatie:
sudo iscsiadm -m node  # Target zou weg moeten zijn


# OPGAVE 9:
# Configureer CHAP authenticatie voor iSCSI (indien TrueNAS dit vereist).
#
# OPLOSSING:
# A. CHAP credentials instellen:
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --op update -n node.session.auth.authmethod -v CHAP

sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --op update -n node.session.auth.username -v iscsi-user

sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --op update -n node.session.auth.password -v SecretPassword

# B. Login met CHAP:
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --login

# C. Verificatie:
sudo iscsiadm -m session -P 3 | grep -i auth


# OPGAVE 10:
# Maak een multipath configuratie voor redundante iSCSI paden (indien meerdere NICs).
#
# OPLOSSING:
# A. Multipath installeren:
sudo dnf install -y device-mapper-multipath

# B. Multipath configuratie genereren:
sudo mpathconf --enable --with_multipathd y

# C. multipath.conf aanpassen:
sudo nano /etc/multipath.conf
# Toevoegen:
# defaults {
#     user_friendly_names yes
#     find_multipaths yes
# }

# D. Service starten:
sudo systemctl enable --now multipathd

# E. Multipath devices bekijken:
sudo multipath -ll

# F. Login op beide paden (2 IPs):
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.112.10 --login
sudo iscsiadm -m node -T iqn.2025-01.com.truenas:target01 -p 192.168.113.10 --login

# G. Verificatie:
sudo multipath -ll
lsblk


# OPGAVE 11:
# TrueNAS basic setup - Maak een storage pool (via WebUI instructies).
#
# OPLOSSING (Conceptueel - via TrueNAS WebUI):
# A. Log in op TrueNAS WebUI: https://<truenas-ip>
#    Default: admin / wachtwoord ingesteld bij installatie

# B. Ga naar: Storage > Pools

# C. Klik "Add" en selecteer "Create new pool"

# D. Pool configuratie:
#    - Name: tank (of eigen naam)
#    - Select disks (minimaal 1)
#    - Layout kiezen: Stripe, Mirror, RAIDZ1, RAIDZ2
#    - Klik "Create"

# E. Verificatie in terminal (indien SSH toegang):
# ssh root@truenas-ip
# zpool status
# zfs list


# OPGAVE 12:
# Maak een iSCSI extent en target op TrueNAS (via WebUI).
#
# OPLOSSING (via TrueNAS WebUI):
# A. Maak Dataset:
#    - Storage > Pools > tank > Add Dataset
#    - Name: iscsi-data
#    - Share Type: Generic

# B. Maak iSCSI Extent:
#    - Sharing > iSCSI > Extents > Add
#    - Name: extent01
#    - Type: Device
#    - Device: /mnt/tank/iscsi-data
#    - Disk Extent Size: 10 GiB

# C. Maak iSCSI Portal:
#    - Portals > Add
#    - Listen: 0.0.0.0:3260

# D. Maak iSCSI Initiator (optioneel voor beveiliging):
#    - Initiators > Add
#    - Initiators: iqn.2025-01.com.example:initiator01

# E. Maak iSCSI Target:
#    - Targets > Add
#    - Target Name: target01
#    - Portal Group: 1
#    - Initiator Group: 1 (of None voor open toegang)

# F. Koppel Extent aan Target:
#    - Associated Targets > Add
#    - Target: target01
#    - Extent: extent01

# G. Enable iSCSI service:
#    - Services > iSCSI > Enable


# OPGAVE 13:
# Troubleshooting: Check iSCSI verbindingsproblemen.
#
# OPLOSSING:
# A. Check firewall op TrueNAS:
# - WebUI: Network > Firewall
# - Port 3260 moet open zijn

# B. Check op Linux client:
# Service status:
sudo systemctl status iscsid
sudo systemctl status iscsi

# Logs bekijken:
sudo journalctl -u iscsid -f
sudo journalctl -u iscsi -f

# C. Test netwerk connectiviteit:
ping 192.168.112.10
telnet 192.168.112.10 3260

# D. Check discovery opnieuw:
sudo iscsiadm -m discovery -t sendtargets -p 192.168.112.10 -P 1

# E. Check initiator name match:
cat /etc/iscsi/initiatorname.iscsi
# Vergelijk met TrueNAS initiator configuratie

# F. Reset discovery database (als laatste optie):
sudo iscsiadm -m node --logout
sudo rm -rf /var/lib/iscsi/nodes/*
sudo systemctl restart iscsid


# ============================================
# EINDE ALLE OEFENINGEN
# ============================================
