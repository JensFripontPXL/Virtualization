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

# A. Op Windows VMware Host: SSH key genereren (indien nog niet bestaat)
ssh-keygen -t rsa -b 4096 -f ./.ssh/id_rsa
# Druk Enter (geen passphrase) voor volledig passwordless

# B. Public key kopiëren naar server (Windows host):

# PowerShell:
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | ssh student@192.168.112.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# C. Permissies controleren op server:
ssh student@serverJF
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit

# D. Verificatie: SSH zonder wachtwoord
ssh student@192.168.112.100
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

# OPTIE A: Windows - SSH shortcut met .bat bestand:
# A1. Maak een batch bestand op het bureaublad:
# - Open Kladblok (Notepad)
# - Plak onderstaande inhoud:

@echo off
ssh student@192.168.112.100
pause

# - Sla op als: C:\Users\<jouw-gebruikersnaam>\Desktop\ServerJF.bat
# - Zorg dat "Opslaan als type" op "Alle bestanden" staat

# A2. Test de shortcut door erop te dubbelklikken


# OPTIE B: Windows - PowerShell shortcut:
# B1. Maak een PowerShell script:
# - Open Kladblok
# - Plak:

# PowerShell SSH shortcut
ssh student@192.168.112.100

# - Sla op als: C:\Users\<jouw-gebruikersnaam>\Desktop\ServerJF.ps1

# B2. Maak een snelkoppeling naar PowerShell:
# - Rechtermuisknop op bureaublad > Nieuw > Snelkoppeling
# - Locatie: powershell.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\Desktop\ServerJF.ps1"
# - Naam: ServerJF


# OPTIE C: Windows - SSH config (meest elegante oplossing):
# C1. Open PowerShell en bewerk SSH config:
notepad $HOME\.ssh\config

# C2. Voeg toe aan het bestand:
# Host serverJF
#     HostName 192.168.112.100
#     User student
#     IdentityFile C:\Users\<jouw-gebruikersnaam>\.ssh\id_rsa

# C3. Sla op en nu werkt simpelweg:
ssh serverJF

# C4. Maak een batch bestand voor de shortcut:
# Inhoud van ServerJF.bat:
# @echo off
# ssh serverJF
# pause


# OPTIE D: Windows - Windows Terminal profiel (modern):
# D1. Open Windows Terminal
# D2. Ga naar Instellingen (Ctrl+,)
# D3. Klik op "Nieuw profiel toevoegen"
# D4. Configureer:
#     Naam: ServerJF
#     Opdrachtregel: ssh student@192.168.112.100
#     Pictogram: kies een SSH icoon
# D5. Sla op en gebruik het profiel vanuit het dropdown menu


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
podman run -rm registry.access.redhat.com/ubi10/ubi:latest cat /etc/hosts
# --rm zorgt dat container automatisch verwijderd wordt na stoppen


# OPGAVE 6:
# Start de Universal Base Image als een container en start een interactieve shell.
# Sluit de shell af zonder de container te stoppen.
#
# OPLOSSING:
# A. Start interactieve container:
podman run -it --name myubi registry.access.redhat.com/ubi10/ubi:latest /bin/bash

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

# Volg exact de commands uit de screenshots hieronder. Deze zijn plain commands
# (geen comments) zodat je ze kunt copy/pasten en uitvoeren.

# 1.	Verwijder alle containers en container images en images van de user root. Maak gebruik van zo weinig mogelijk karakters.
podman rm -a -f ; podman rmi -a -f

# 2.	Download eerst de Red Hat ubi10-init container image en start daarna een container afgeleid van deze image op de achtergrond (detached)
#       met een poortbinding die poort 80 van de container koppelt aan poort 80 op de host.
podman pull registry.access.redhat.com/ubi10/ubi-init:latest
sudo podman run -d -p 80:80 --name Httpd10 --hostname Httpd10 registry.access.redhat.com/ubi10/ubi-init:latest tail -f /dev/null

# Open firewall port 80 voor toegang
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --reload

# 3.	Installeer httpd in de container die je juist gestart bent. Je mag maar één commando gebruiken.
sudo podman exec -it Httpd10 dnf install -y httpd

# Start httpd in de container
sudo podman exec -d Httpd10 httpd -DFOREGROUND

# 4.	Stel in dat je eigen voor- en achternaam getoond worden wanneer http://192.168.112.100 wordt ingegeven in de browser van de container host. 
# Doe dit door eerst in te breken in de container en dan index.html aan te maken met de juiste inhoud.
sudo podman exec -it Httpd10 bash
echo "<h1>Jens Fripont</h1>" > /var/www/html/index.html
exit
# Controleer of de inhoud correct is.
sudo podman exec Httpd10 cat /var/www/html/index.html
# Controleer of de webserver correct is geïnstalleerd.
sudo podman exec Httpd10 ps aux | grep httpd 
curl http://192.168.112.100
# 5.	Ga uit de container en start de webserver op voor te testen.  
exit
sudo podman exec -d Httpd10 httpd -DFOREGROUND
# 6.	Ga naar een ander terminalvenster en vraag de webpagina op met curl.
curl http://192.168.112.100
# Controleer of je naam en voornaam getoond worden.
# Indien dit niet het geval is, controleer je stappen en los je problemen op.
# maak een SSH-tunnel van je laptop naar serverJF voor poort 80 indien nodig om de webpagina te kunnen opvragen in een volgend onderdeel.
ssh -L 8080:localhost:80 student@serverJF
# 7.	Stel in dat de container automatisch de webserver opstart wanneer de container start. Maak hiervoor gebruik van systemctl.
sudo podman exec -it Httpd10 bash
systemctl enable httpd
exit

# 8.	Stop de container en maak een container image met de naam webserver en tag v1 van de container.
sudo podman stop Httpd10
sudo podman commit Httpd10 webserver:v1
sudo podman run -d -p 80:80 --name Httpd10 localhost/webserver:v1

# 9.	Toon enkel het image webserver:v1.
sudo podman images webserver:v1
# Controleer of het image webserver:v1 de juiste inhoud heeft.
sudo podman run -it --rm webserver:v1 bash -c "cat /var/www/html/index.html"
<h1>Fripont Jens</h1>
exit
# Nu kan je de webpagina opvragen via http://localhost:8080 op je laptop.
# dit werkt zo niet je moet eerste de oude container verwijderen
sudo podman rm -f Httpd10 2>/dev/null || true
sudo podman run -d -p 80:80 --name Httpd10 localhost/webserver:v1 httpd -DFOREGROUND
# 10.	Verwijder de webserver-container die draait met één commando.
sudo podman rm -f Httpd10

# 11.	Check dat er niet geluisterd wordt naar aanvragen op poort 80.
ss -tuln | grep :80

# 12.	Maak een container aan afgeleid van jouw opgeslagen container image. De container moet op de container host draaien op poort 90. 
# Je moet de container detached starten.
sudo podman run -d -p 90:80 --name Httpd90 webserver:v1 tail -f /dev/null

# 13.	Vraag nu de webpagina die je naam en voornaam toont op aan de hand van de container die je juist gestart bent.
sudo firewall-cmd --add-port=90/tcp --permanent
sudo firewall-cmd --reload
curl http://localhost:90

# Controleer of je naam en voornaam getoond worden.
sudo podman exec -d Httpd90 httpd -DFOREGROUND # start de webserver in de container
sudo podman exec Httpd90 ss -tuln | grep :80 # controleer of de webserver luistert
sudo podman exec Httpd90 curl -sS http://localhost # controleer of de webpagina correct is
curl -v http://localhost:90 # controleer of de webpagina correct is

# 14.	Zorg ervoor dat de website beschikbaar is op clientAS. 
# Hiervoor moet je de firewall op serverAS aanpassen.
sudo firewall-cmd --add-port=90/tcp --permanent
sudo firewall-cmd --reload


# 15.	Vraag op clientAS de webpagina van de container op serverAS op.
curl http://serverJF:90
# Controleer of je naam en voornaam getoond worden.
# 16.	Verwijder alle containers en container images en images van de user root. Maak gebruik van zo weinig mogelijk karakters.
sudo podman rm -a -f ; sudo podman rmi -a -f


# ============================================
# OEFENING 4 - Podman Dockerfiles/Containerfiles
# ============================================
# OPGAVE
# OEFENING 4 - Podman Dockerfiles/Containerfiles
# ============================================

# OPGAVE 1:
# 1.	Voer deze oefening uit in de map oef1<jeintialen> waarin je de containerfile opslaat. 
# Bouw een containerfile met de naam containerfile1 voor een webserver gebaseerd op registry.access.redhat.com/ubi10/ubi.
# De website moet je eigen voor- en achternaam tonen.
# De imagenaam noemt localhost/mijnwww<jeinitialeninkleineletters>.
# De container die je van de image afleidt noemt oef1<jeintialen>.
# De website moet op de containerhost beschikbaar zijn op poort 8081. 
# Laat uiteraard ook, zoals bij alle vragen, je resultaat zien. 

# OPLOSSING:
# A. Directory maken en naar toe gaan:
mkdir -p oef1jf
cd oef1jf

# B. Containerfile maken:
nano containerfile1
FROM registry.access.redhat.com/ubi10/ubi:latest
RUN dnf -y install httpd && dnf clean all
COPY index.html /var/www/html/index.html
EXPOSE 80
CMD ["httpd","-DFOREGROUND"]

# C. Index.html maken:
echo "<h1>Jens Fripont</h1>" > index.html

# D. Image bouwen:
podman build -t localhost/mijnwwwjf -f containerfile1 .

# E. Container starten:
podman run -d --name oef1jf -p 8081:80 localhost/mijnwwwjf

# F. Firewall aanpassen (indien nodig):
sudo firewall-cmd --add-port=8081/tcp --permanent
sudo firewall-cmd --reload

# G. Verificatie:
podman images | grep mijnwwwjf
podman ps | grep oef1jf
curl http://localhost:8081
# Zou "<h1>Jens Fripont</h1>" moeten tonen

# 2.	Voer deze oefening uit in de map oef2<jeintialen> waarin je de containerfile opslaat. 
# Bouw een containerfile met de naam containerfile2 voor een webserver gebaseerd op registry.access.redhat.com/ubi10/ubi-init.
# De website moet je eigen voor- en achternaam tonen.
# De imagenaam noemt localhost/mijnwww2<jeinitialeninkleineletters>.
# De container die je van de image afleidt noemt oef2<jeinitialen>. 
# Maak de image ingelogd als de gebruiker student.
# De website moet op de containerhost beschikbaar zijn op poort 80. 
# Zorg ervoor dat PID1 init is.

# OPLOSSING:
# A. Directory maken en naar toe gaan:
mkdir -p oef2jf
cd oef2jf

# B. Containerfile maken:
nano containerfile2

# Inhoud van containerfile2:
# FROM registry.access.redhat.com/ubi10/ubi-init:latest
# 
# RUN dnf install -y httpd && dnf clean all
# 
# COPY index.html /var/www/html/index.html
# 
# EXPOSE 80
# 
# CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]

# C. Index.html maken:
echo "<h1>Jens Fripont</h1>" > index.html

# D. Image bouwen als student:
sudo -u student podman build -t localhost/mijnwww2jf -f containerfile2 .

# E. Container starten:
sudo -u student podman run -d --name oef2jf -p 80:80 localhost/mijnwww2jf

# F. Firewall aanpassen (indien nodig):
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --reload

# G. Verificatie:
sudo -u student podman images | grep mijnwww2jf
sudo -u student podman ps | grep oef2jf
curl http://localhost:80
# Zou "<h1>Jens Fripont</h1>" moeten tonen

# 3.	Voer deze oefening uit in de map oef3<jeintialen>. Maak gebruik van registry.access.redhat.com/ubi10/ubi-init. Maak een containerfile met de naam containerfile3 waarmee je een image aanmaakt die zowel een SSH-server als een webserver draait (jawel, ook dat gaat 😊).
# -	De container die je afleidt van het image toont <jevoornaam><jeachternaam> als je http://localhost:8080 opent analoog aan onderstaande.
 

# -	Op de SSH-server moet een gebruiker <jevoornaam> kunnen inloggen via poort 2222. Je moet via "su –" kunnen overgaan naar de root-gebruiker.
# -	Ingelogd via SSH op de container pas je de webpagina aan: <jeachternaam><jevoornaam> i.p.v. andersom.
 

# Opgelet: je mag geen gebruik maken van sed. Maak enkel gebruik van commando’s die je zelf begrijpt. De rechten en eigenaar van /var/www/html moet je niet veranderen.

# OPLOSSING:
# A. Directory maken en naar toe gaan:
mkdir -p oef3jf
cd oef3jf

# B. Containerfile maken:
nano containerfile3

# Inhoud van containerfile3:
FROM registry.access.redhat.com/ubi10/ubi-init:latest

RUN dnf install -y httpd openssh-server && dnf clean all

RUN useradd -m Jens && echo 'Jens:password' | chpasswd && echo 'root:password' | chpasswd

RUN mkdir -p /var/run/sshd

RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

RUN cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak && grep -v 'pam_systemd.so' /etc/pam.d/system-auth > /tmp/system-auth && mv /tmp/system-auth /etc/pam.d/system-auth

COPY index.html /var/www/html/index.html

EXPOSE 80 22

RUN systemctl enable httpd sshd

CMD ["/usr/sbin/init"]

# C. Index.html maken:
echo "<h1>Jens Fripont</h1>" > index.html

# D. Image bouwen:
podman build -t localhost/mijnwww3jf -f containerfile3 .

# E. Container starten:
podman run -d --name oef3jf -p 8080:80 -p 2222:22 localhost/mijnwww3jf

# F. Firewall aanpassen (indien nodig):
sudo firewall-cmd --add-port=2222/tcp --permanent
sudo firewall-cmd --reload

# G. Verificatie web:
curl http://localhost:8080
# Zou "<h1>Jens Fripont</h1>" moeten tonen

# H. SSH als Jens:
ssh -o StrictHostKeyChecking=no Jens@localhost -p 2222
# Password: password

# I. In SSH: su -
# Password: password

# J. Als root: echo "<h1>Fripont Jens</h1>" > /var/www/html/index.html

# K. exit (root), exit (SSH)

# L. Verificatie:
curl http://localhost:8080
# Zou "<h1>Fripont Jens</h1>" moeten tonen



# ============================================
# OEFENING 5 - Podman Networks
# ============================================

# OPGAVE
# 1.	Maak een rootless container aan zonder zelfgemaakt netwerk. 
# Maak verbinding met de server vanuit de container door middel van SSH (SSH in container met Server<jeinitialen>). 
# Maak gebruik van ubi10-image zonder init. 
# De naam van de container is sshtest<jeintialen>. 

# OPLOSSING:
# A. Rootless container starten met SSH keys gemount:
podman run -it --network host --name sshtestjf -v /home/student/.ssh:/root/.ssh:Z registry.access.redhat.com/ubi10/ubi:latest /bin/bash

# B. Binnen de container: SSH clients installeren en verbinden:
dnf install -y openssh-clients
echo 192.168.112.100 serverJF >> /etc/hosts
chmod 700 /root/.ssh
chmod 600 /root/.ssh/id_rsa
ssh -o StrictHostKeyChecking=no student@192.168.112.100
ssh student@serverJF
# Dit zou werken dankzij de eerder ingestelde passwordless SSH
# Je bent nu verbonden met de server vanaf de container

# C. Verificatie:
podman ps -a | grep sshtestjf
# Container zou gestopt zijn na exit


# 2.	Zoek via het commando podman naar de officiële Pi-hole docker image.

# OPLOSSING:
podman search pihole
# Dit toont de officiële Pi-hole image: pihole/pihole

# 3.	Maak een container aan met Pi-hole (official image), gebaseerd op  de officiële Pi-hole docker image.  Maak gebruik van een host-netwerk.
# Maak geen gebruik van volume mapping (optie -v). Dat is immers nog niet gezien in de lessen.  Laat Pi-hole DNS doorverwijzen naar de DNS-servers van Google.
# Geef de container de naam pihole<jeintialen>.  
# Doel van de installatie Pi-hole:
# o	Je moet kunnen inloggen op de webinterface via Pi-hole via http://server<jeinitialen>.lan/admin .
# o	Je moet gebruik kunnen maken van de DNS-functie van Pi-hole om advertenties te vermijden op websites.
# Toon volgend resultaat:
# o	Laat de webinterface zien waar je Pi-hole kan beheren door in te loggen op http://server<jeinitialen>.lan/admin. 
# o	Voer “nslookup www.kde.org “ uit gebruik makend van DNS-server Pi-hole op Server<jeinitialen>.
# o	Doe een check dat er geen advertenties te zien zijn door te surfen naar https://fuzzthepiguy.tech/adtest/ op Server<jeinitialen>. Pas hiervoor uiteraard de DNS-instellingen op Server<jeinitialen> aan.

# OPLOSSING:

# Create data directories
sudo mkdir -p /dataJF/conf /dataJF/logs
sudo chown root:root /dataJF/conf /dataJF/logs
sudo chmod 700 /dataJF/conf /dataJF/logs

# A. Pi-hole container starten met host netwerk en Google DNS forwarding:
sudo podman run -d --network host --name piholejf \
  -v /dataJF/conf:/etc/pihole \
  -v /dataJF/logs:/var/log/pihole \
  -e TZ='Europe/Brussels' \
  -e PIHOLE_DNS1=8.8.8.8 \
  -e PIHOLE_DNS2=8.8.4.4 \
  docker.io/pihole/pihole:latest

# Wacht even tot container volledig opgestart is
sleep 30

# B. Firewall aanpassen voor web interface (poort 80) en DNS (poort 53):
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --add-port=53/udp --permanent
sudo firewall-cmd --add-port=53/tcp --permanent
sudo firewall-cmd --reload

# C. Verificatie dat container draait:
sudo podman ps | grep piholejf

# D. Controleer dat data opgeslagen is in de volumes:
ls -la /dataJF/conf
ls -la /dataJF/logs

# E. Web interface openen (vereist DNS configuratie voor serverJF.lan):
# Eerst /etc/hosts aanpassen voor lokale DNS:
echo "127.0.0.1 serverJF.lan" | sudo tee -a /etc/hosts

# Open browser naar: http://serverJF.lan/admin
# Default wachtwoord: verander dit via sudo podman logs piholejf | grep "password"

# E. DNS test met nslookup:
nslookup www.kde.org 127.0.0.1
# Dit gebruikt Pi-hole als DNS server

# F. Advertentie test:
# Backup huidige DNS config:
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Stel Pi-hole in als DNS server:
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Verificatie dat Pi-hole ad blocking werkt:
nslookup doubleclick.net 127.0.0.1
# Zou 0.0.0.0 moeten retourneren voor geblokkeerde domeinen

# Open browser naar: https://fuzzthepiguy.tech/adtest/
# Controleer dat er geen advertenties worden getoond

# Herstel DNS config:
sudo mv /etc/resolv.conf.backup /etc/resolv.conf

# 4.	Deze vraag is een vervolg op vraag 3.

# OPLOSSING:
# Zorg ervoor dat Pi-hole container draait op ServerJF (zie oef5.3)
# Op serverJF: Open firewall voor DNS verkeer
sudo firewall-cmd --add-port=53/udp --permanent && sudo firewall-cmd --add-port=53/tcp --permanent && sudo firewall-cmd --reload
# Op ClientJF (RHEL10):
# A. DNS server instellen op IP van ServerJF (192.168.112.100)
# Methode 1: Via nmcli (NetworkManager)
# Eerst connection naam vinden:
nmcli connection show
# Stel DNS in (vervang <connection-name> met juiste naam, bijv. 'Wired connection 1'):
sudo nmcli connection modify ens160 ipv4.dns 192.168.112.100
sudo nmcli connection down ens160
sudo nmcli connection up ens160

# Methode 2: Direct /etc/resolv.conf bewerken (tijdelijk):
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
echo "nameserver 192.168.112.100" | sudo tee /etc/resolv.conf

# B. Verificatie: Voer uit op ClientJF:
nslookup www.kde.org
# Dit zou moeten resolven via Pi-hole op ServerJF, en ad blocking zou werken

# C. Optioneel: Test ad blocking door https://fuzzthepiguy.tech/adtest/ te openen in browser op ClientJF
# (zou geen ads moeten tonen)

# D. Herstel DNS indien nodig:
# Voor nmcli: sudo nmcli connection modify ens160 ipv4.dns ""
# Voor resolv.conf: sudo mv /etc/resolv.conf.backup /etc/resolv.conf

# 5.	Installeer een DHCP-server in ubi10/ubi-init. Je zal merken dat je gebruik moet maken van een alternatief voor dhcpd. Gebruik een range van 192.168.112.10 tot 192.168.112.200. Maak gebruik van een macvlan-netwerk.

# OPLOSSING:
# Alternatief voor dhcpd: Gebruik dnsmasq, aangezien dhcp-server niet beschikbaar is in ubi10.

# A. Maak macvlan netwerk aan:
sudo podman network create -d macvlan --subnet 192.168.112.0/24 --gateway 192.168.112.1 -o parent=ens160 macvlan-net

# B. Maak directory voor config:
mkdir -p oef5dhcp

# C. Maak Containerfile voor DHCP server:
cat > oef5dhcp/Containerfile << 'EOF'
FROM registry.access.redhat.com/ubi10/ubi-init:latest

RUN dnf install -y dnsmasq && dnf clean all

COPY dnsmasq.conf /etc/dnsmasq.conf

RUN systemctl enable dnsmasq

EXPOSE 67/udp

CMD ["/usr/sbin/init"]
EOF

# D. Maak dnsmasq config:
cat > oef5dhcp/dnsmasq.conf << 'EOF'
interface=eth0
dhcp-range=192.168.112.10,192.168.112.200,255.255.255.0,24h
dhcp-option=option:router,192.168.112.1
dhcp-option=option:dns-server,192.168.112.100
EOF

# E. Bouw de image:
sudo podman build -t localhost/dhcp-server -f oef5dhcp/Containerfile oef5dhcp

# F. Start de container:
sudo podman run -d --name dhcp-server --network macvlan-net --privileged localhost/dhcp-server

# G. Verificatie:
sudo podman ps | grep dhcp-server
sudo podman logs dhcp-server

# H. Test: Op ClientJF, zet netwerk op DHCP (indien niet al), en controleer of IP in range 10-200 wordt toegekend.
# Bijv. ip addr show op ClientJF

# I. Cleanup:
sudo podman stop dhcp-server
sudo podman rm dhcp-server
sudo podman network rm macvlan-net

# 6.	Uitbreidingsoefening 1 
# Maak dezelfde oefening als oefening 3 maar maak gebruik van een rootless container zonder eigen ingesteld netwerk. Gebruik poort 6000 voor DNS en poort 8080 voor de admin website van Pi-hole. 
# Doe een nslookup op poort 6000 op Server<jeintialen> voor te testen. 
# Pas daarna de firewall op Server<jeintialen> aan zodat je op Server<jeinitialen> de DNS-server van Pi-hole kan gebruiken via de standaardpoort. Test dit uit door een nslookup te doen. Test ook uit in browser dat er geen advertenties getoond worden: https://fuzzthepiguy.tech/adtest/ . Maak Youtube-video van 5 minuten erover. Bewaar link en breng mee.

# 7.	Uitbreidingsoefening 2
# Voer deze oefening uit op Server<jeinitialen>.

# Maak een rootfull container aan waarop je Pi-hole installeert. Maak gebruik van het standaard bridge-netwerk.
# Vertrek van de image ubi10/ubi-init. Hierin zit de moeilijkheid. Normaal wordt Debian Linux gebruikt…
# Stel volgende poorten in:
# - Poort 53 TCP/UDP moet open staan voor DNS-verkeer.
# - Poort 80 TCP en 443 TCP voor webinterface.
# Voor Pihole heeft de container een statisch IP-adres nodig.
# De naam en hostname van de container is: pihole<jeintialen>. 
# Check Pi-hole:
# a.	Laat zien dat DNS-aanvraag voor www.google.be kan via je pi-hole.
# b.	Check via https://fuzzthepiguy.tech/adtest/ dat er geen advertenties meer worden doorgelaten.
# Maak Youtube-video van 5 minuten erover. Bewaar link en breng mee.


# ============================================
# OEFENING 6 - Podman Volumes
# ============================================

# OPGAVE
# 1.	Voor deze oefening pas je oefening 3 (i.v.m. Pi-hole) van oefening 5 Podman networks aan. Maak nu gebruik van een gekoppeld volume voor configuratie en logs. Deze gegevens wordt bewaard in /data<jeintialen> met de submappen conf en logs. Alleen de root mag toegang hebben tot deze gegevens. Zorg ervoor dat Pi-hole als enige toegang heeft als container tot deze data. Laat ook zien dat er daadwerkelijk data op de containerhost opgeslagen in in die 2 mappen.

# OPLOSSING:
# A. Maak data directory aan met juiste permissies (alleen root toegang):
sudo mkdir -p /dataJF/conf /dataJF/logs
sudo chown root:root /dataJF/conf /dataJF/logs
sudo chmod 700 /dataJF/conf /dataJF/logs

# B. Pi-hole container starten met gekoppelde volumes (bound mounts) in plaats van named volumes:
sudo podman run -d --network host --name piholejf \
  -v /dataJF/conf:/etc/pihole:Z \
  -v /dataJF/logs:/var/log/pihole:Z \
  -e TZ='Europe/Brussels' \
  -e PIHOLE_DNS1=8.8.8.8 \
  -e PIHOLE_DNS2=8.8.4.4 \
  docker.io/pihole/pihole:latest

# Wacht even tot container volledig opgestart is
sleep 30

# C. Firewall aanpassen voor web interface (poort 80) en DNS (poort 53):
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --add-port=53/udp --permanent
sudo firewall-cmd --add-port=53/tcp --permanent
sudo firewall-cmd --reload

# D. Verificatie dat container draait:
sudo podman ps | grep piholejf

# E. Controleer dat data daadwerkelijk opgeslagen wordt in de host mappen:
ls -la /dataJF/conf
ls -la /dataJF/logs

# F. Toon dat alleen root toegang heeft (andere gebruikers kunnen niet lezen):
sudo -u student ls /dataJF/conf  # Zou toegang geweigerd moeten worden
sudo -u student ls /dataJF/logs  # Zou toegang geweigerd moeten worden

# G. Web interface openen (vereist DNS configuratie voor serverJF.lan):
# Eerst /etc/hosts aanpassen voor lokale DNS:
echo "127.0.0.1 serverJF.lan" | sudo tee -a /etc/hosts

# Open browser naar: http://serverJF.lan/admin
# Default wachtwoord: verander dit via sudo podman logs piholejf | grep "password"

# H. DNS test met nslookup:
nslookup www.kde.org 127.0.0.1
# Dit gebruikt Pi-hole als DNS server

# I. Advertentie test:
# Backup huidige DNS config:
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Stel Pi-hole in als DNS server:
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Verificatie dat Pi-hole ad blocking werkt:
nslookup doubleclick.net 127.0.0.1
# Zou 0.0.0.0 moeten retourneren voor geblokkeerde domeinen

# Open browser naar: https://fuzzthepiguy.tech/adtest/
# Controleer dat er geen advertenties worden getoond

# Herstel DNS config:
sudo mv /etc/resolv.conf.backup /etc/resolv.conf


# 2.	Zet een Jellyfin Media Server op in Podman op Server<jeintialen>. 
# Maak gebruik van het image van jellyfin/jellyfin.
# Gebruik 2 named volumes :
# a.	media<jeintialen> voor opslag foto’s enz.
# b.	configuratie<jeintialen>  voor opslag configuratie
# Maak gebruik van macvlan. 
# Sla één foto op van een pinguin in het named volume media<jeintialen>.

# Jellyfin moet bereikbaar zijn via poort 8096 op Server<jeintialen> en Client<jeintialen>.
# Start Jellyfin Media Server op in een webbrowser op Server<jeintialen> en laat de pinguin zien. Doe hetzelfde op Client<jeinititialen>

# Opgelet: laat in je screenshot duidelijk zien op welke VM je zit (zoals in onderstaande afbeelding bijvoorbeeld).


# OPLOSSING:
# Create named volumes for media and configuration
sudo podman volume create mediaJF
sudo podman volume create configuratieJF

# Verify volumes
sudo podman volume ls
sudo podman volume inspect mediaJF
sudo podman volume inspect configuratieJF

# Create macvlan network for container networking
sudo podman network create \
  --driver macvlan \
  -o parent=ens160 \
  --subnet 192.168.112.0/24 \
  --gateway 192.168.112.1 \
  macvlanJF

# Pull and run Jellyfin container with static IP on macvlan network
sudo podman pull docker.io/jellyfin/jellyfin:latest
sudo podman run -d \
  --name jellyfinJF \
  --network macvlanJF \
  --ip 192.168.112.101 \
  -v mediaJF:/media \
  -v configuratieJF:/config \
  --restart=always \
  docker.io/jellyfin/jellyfin:latest

# Add host macvlan interface for connectivity
sudo ip link add mvlan0 link ens160 type macvlan mode bridge
sudo ip addr add 192.168.112.102/24 dev mvlan0
sudo ip link set mvlan0 up

# Test connectivity to container
ping -c 3 192.168.112.101

# Make host macvlan persistent via NetworkManager
sudo nmcli connection add type macvlan ifname mvlan0 dev ens160 mode bridge ip4 192.168.112.102/24
sudo nmcli connection up mvlan0

# Add a penguin photo to the media volume
MP=$(sudo podman volume inspect mediaJF -f '{{.Mountpoint}}')
sudo mkdir -p "$MP/Pictures"

# Download a royalty-free penguin photo to the media volume
sudo cp /home/student/pinguin.jpg "$MP/Pictures/penguin.jpg"

# Verify the file
sudo ls -lh "$MP/Pictures/"

# Setup Jellyfin: Open browser on ServerJF to http://192.168.112.101:8096
# Complete initial setup (language, admin user, password)
# Add a library: Type - Photos, Path - /media/Pictures
# The penguin photo should appear in the Photos library.


# Opgelet: VMware Workstation laat mogelijk maar één MAC-adres per virtuele adapter toe, tenzij je dat expliciet toestaat.
# Los dit als volgt op:
# 	Open .vmx-bestand van VM als VM uit staat
# 	Voeg onderstaande regels toe:
# 		ethernet0.promiscuousMode = "accept"
# ethernet0.allowGuestConnectionControl = "TRUE"
# ethernet0.noPromisc = "FALSE"


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


# 1. Zonder containerfile of podman-compose.
# Voer deze oefening uit door commando’s na elkaar uit te voeren.
# Je moet vertrekken van ubi10/ubi-image.
# Stel in dat jouw voor- en achternaam wordt toont door te surfen naar localhost:8080 op de containerhost. 
# Geef de container die je met portmapping aanmaakt de naam nginx<jevoornaam>. 
# De inhoud van de webpagina met je voor- en achternaam wordt getoond aan de hand van een gekoppeld volume (~/nginx<jeinitialen> op de container host). 
# Werk rootless.
# Maak gebruik van het standaard rootless netwerk.
# Toon uiteraard dat het werkt met curl. 

# Tip: maak eerst image met installatie nginx aan. 

# OPLOSSING:
# A. Maak directory voor volume:
mkdir -p ~/nginxjf

# B. Maak index.html in volume:
echo "<h1>Jens Fripont</h1>" > ~/nginxjf/index.html

# C. Pull base image:
podman pull registry.access.redhat.com/ubi10/ubi:latest

# D. Maak custom image met nginx geïnstalleerd:
podman run -d --name temp-nginx registry.access.redhat.com/ubi10/ubi:latest sleep infinity
podman exec temp-nginx dnf install -y nginx
podman commit temp-nginx nginx-jens
podman stop temp-nginx
podman rm temp-nginx

# E. Start container met volume en port mapping:
podman run -d --name nginxJens -p 8080:80 -v ~/nginxjf:/usr/share/nginx/html:Z nginx-jens nginx -g 'daemon off;'

# F. Firewall aanpassen (indien nodig):
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload

# G. Verificatie:
curl http://localhost:8080
# Zou "<h1>Jens Fripont</h1>" moeten tonen


# 2. Met containerfile.
# Voor deze oefening maak je verplicht gebruik van Visual Studio Code.
# Maak dezelfde oefening als oefening 1 maar maak gebruik van een containerfile om hetzelfde resultaat te bekomen. 
# De image die je aanmaakt krijgt als naam nginx-<jevoornaam>. De container noemt ook nginx-<jevoornaam>. 
# Opgelet: je moet nog altijd gebruik maken van een gekoppeld volume zodat de inhoud van de website kan veranderen wanneer de container draait (dynamisch binden).

# OPLOSSING:
# A. Maak directory voor oefening:
mkdir -p oef7-2
cd oef7-2

# B. Maak Containerfile:
cat > Containerfile << 'EOF'
FROM registry.access.redhat.com/ubi10/ubi:latest
RUN dnf install -y nginx && dnf clean all
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# C. Maak index.html:
echo "<h1>Jens Fripont</h1>" > index.html

# D. Bouw image:
podman build -t nginx-Jens .

# E. Maak volume directory:
mkdir -p ~/nginxjf

# F. Start container met volume:
podman run -d --name nginx-Jens -p 8080:80 -v ~/nginxjf:/usr/share/nginx/html:Z nginx-Jens

# G. Verificatie:
curl http://localhost:8080


# 3. Met podman-compose.
# Voor deze oefening maak je verplicht gebruik van Visual Studio Code.
# Pas oefening 1 aan zodat alles wordt aangemaakt met podman-compose in combinatie met containerfile. 
# De image moet gebouwd worden via podman-compose.
# Gebruik voor deze oefening onderstaande structuur (gebruik uiteraard dockerfile<jouweigenvoornaam>).

# Gebruik dezelfde containernaam. Gebruik nu poort 9000 op de containerhost. Laat zeker een screenshot zoals onderstaande (niet vervaagd uiteraard).

# OPLOSSING:
# A. Maak directory structuur:
mkdir -p oef7-3
cd oef7-3
mkdir -p dockerfileJens

# B. Maak Containerfile in dockerfileJens:
cat > dockerfileJens/Containerfile << 'EOF'
FROM registry.access.redhat.com/ubi10/ubi:latest
RUN dnf install -y nginx && dnf clean all
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# C. Maak podman-compose.yml:
cat > podman-compose.yml << 'EOF'
version: '3.8'
services:
  nginxJens:
    build:
      context: ./dockerfileJens
      dockerfile: Containerfile
    ports:
      - "9000:80"
    volumes:
      - ~/nginxjf:/usr/share/nginx/html:Z
EOF

# D. Maak volume directory en index.html:
mkdir -p ~/nginxjf
echo "<h1>Jens Fripont</h1>" > ~/nginxjf/index.html

# E. Start met podman-compose:
podman-compose up -d

# F. Verificatie:
curl http://localhost:9000


# 4. Met podman-compose.
# Pas oefening 3 aan zodat gebruik wordt gemaakt van een eigen netwerk (rootless). 
# Maak ook gebruik van Visual Studio Code.
# Stel ook in dat de webpagina beschikbaar is vanaf je Windows 11 host. De container krijgt als IP 10.10.10.10. Maak uiteraard geen gebruik van de GUI.
# Opgelet: je moet eerst een extern netwerk aanmaken!

# OPLOSSING:
# A. Maak rootless netwerk:
podman network create --subnet 10.10.10.0/24 mynet

# B. Update podman-compose.yml:
cat > podman-compose.yml << 'EOF'
version: '3.8'
networks:
  mynet:
    external: true
services:
  nginxJens:
    build:
      context: ./dockerfileJens
      dockerfile: Containerfile
    networks:
      mynet:
        ipv4_address: 10.10.10.10
    volumes:
      - ~/nginxjf:/usr/share/nginx/html:Z
EOF

# C. Start met podman-compose:
podman-compose up -d

# D. Verificatie vanaf host (SSH tunnel indien nodig):
curl http://10.10.10.10


# 5. Schrijf een containerfile waarbij er een bestand /aanmaakdatum in de image wordt aangemaakt met als inhoud de datum wanneer het image is aangemaakt (maak gebruik van commando date) en je voor- en achternaam in het formaat zoals hieronder staat weergegeven. 

# Je zorgt er uiteraard voor dat je eigen naam wordt weergegeven.
# Baseer je op ubi10/ubi-image. De image die je aanmaakt moet dateimage<jeinitialen> noemen. 
# Een container afgeleid van deze image moet blijven draaien, ook als je de optie -it niet meegeeft aan het commando podman.
# Test dit ook uit. 

# OPLOSSING:
# A. Maak directory:
mkdir -p oef7-5
cd oef7-5

# B. Maak Containerfile:
cat > Containerfile << 'EOF'
FROM registry.access.redhat.com/ubi10/ubi:latest
RUN echo "Jens Fripont - $(date)" > /aanmaakdatum
CMD ["sleep", "infinity"]
EOF

# C. Bouw image:
podman build -t dateimagejf .

# D. Start container (blijft draaien):
podman run -d --name test-date dateimagejf

# E. Verificatie:
podman ps | grep test-date
podman exec test-date cat /aanmaakdatum
