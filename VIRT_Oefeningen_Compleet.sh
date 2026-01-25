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

# OPLOSSING die vanaf de eerste keer werkt:

# 1. Zorg dat poort 53 vrij is en server heeft werkende DNS voor opstart
sudo systemctl stop systemd-resolved 2>/dev/null
sudo systemctl disable systemd-resolved 2>/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 2. Firewall aanpassen VOOR container start
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --add-port=53/udp --permanent
sudo firewall-cmd --add-port=53/tcp --permanent
sudo firewall-cmd --reload

# 3. A. Pi-hole container starten met host netwerk en Google DNS forwarding:
# OPMERKING: Gebruik dubbele streepjes voor podman opties
sudo podman run -d \
  --network host \
  --name piholejf \
  -e TZ='Europe/Brussels' \
  -e PIHOLE_DNS_='8.8.8.8;8.8.4.4' \
  -e FTLCONF_dns_listeningMode='all' \
  -e WEBPASSWORD='Pass1234' \
  --cap-add=NET_ADMIN \
  --restart=unless-stopped \
  docker.io/pihole/pihole:latest

# 4. Wacht langer tot container volledig opgestart is (Pi-hole heeft tijd nodig voor gravity database)
echo "Wachten op Pi-hole initialisatie (kan 2-3 minuten duren)..."
sleep 180

# 5. Verificatie dat container draait en check logs:
sudo podman ps | grep piholejf
echo "=== Pi-hole logs ==="
sudo podman logs piholejf | tail -20

# 6. Check of Pi-hole services draaien in container:
echo "=== Pi-hole status ==="
sudo podman exec piholejf pihole status 2>/dev/null || echo "Pi-hole status check mislukt, wacht nog even..."

# 7. /etc/hosts aanpassen voor lokale DNS:
echo "127.0.0.1 serverJF.lan" | sudo tee -a /etc/hosts

# 8. Stel Pi-hole in als DNS server op de host:
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# 9. DNS test met nslookup:
echo "=== DNS test: nslookup www.kde.org ==="
nslookup www.kde.org 127.0.0.1

# 10. Verificatie dat Pi-hole ad blocking werkt:
echo "=== Ad blocking test: nslookup doubleclick.net ==="
nslookup doubleclick.net 127.0.0.1

# 11. Web interface toegang testen:
echo "=== Web interface test ==="
echo "Open browser naar: http://serverJF.lan/admin"
echo "Login wachtwoord: Pass1234"
echo "Of vind wachtwoord met: sudo podman logs piholejf | grep 'password'"

# 12. Test commando om te controleren of Pi-hole DNS werkt:
echo "=== Test Pi-hole functionaliteit ==="
echo "Test gewone site:"
nslookup google.com 127.0.0.1
echo ""
echo "Test geblokkeerde site (zou 0.0.0.0 moeten zijn):"
nslookup ads.example.com 127.0.0.1

# 13. Instructies voor advertentie test:
echo ""
echo "=== Voor advertentie test: ==="
echo "1. Open browser op ServerJF"
echo "2. Ga naar: https://fuzzthepiguy.tech/adtest/"
echo "3. Controleer dat er geen advertenties worden getoond"
echo "4. DNS instellingen zijn al aangepast naar Pi-hole (127.0.0.1)"

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
# 1. Stop systemd-resolved als het draait (blokkeert poort 53)
sudo systemctl stop systemd-resolved 2>/dev/null
sudo systemctl disable systemd-resolved 2>/dev/null
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# A. Maak data directory aan met juiste permissies (ALLEEN root toegang):
sudo mkdir -p /dataJF/conf /dataJF/logs
sudo chown root:root /dataJF/conf /dataJF/logs
sudo chmod 700 /dataJF/conf /dataJF/logs  # 700 = alleen root rechten

# B. Pi-hole container starten met gekoppelde volumes (bound mounts):
sudo podman run -d --network host --name piholejf \
  -v /dataJF/conf:/etc/pihole:Z \
  -v /dataJF/logs:/var/log/pihole:Z \
  -e TZ='Europe/Brussels' \
  -e PIHOLE_DNS_='8.8.8.8;8.8.4.4' \
  -e WEBPASSWORD='Pass1234' \
  -e FTLCONF_dns_listeningMode='all' \
  -e PIHOLE_UID=0 \  # Draai als root in container voor compatibiliteit
  -e PIHOLE_GID=0 \
  --cap-add=NET_ADMIN \
  --user=0:0 \  # Forceer root gebruiker in container
  docker.io/pihole/pihole:latest

# Wacht even tot container volledig opgestart is (Pi-hole heeft tijd nodig)
echo "Wachten op Pi-hole initialisatie..."
sleep 120

# C. Firewall aanpassen voor web interface (poort 80) en DNS (poort 53):
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --add-port=53/udp --permanent
sudo firewall-cmd --add-port=53/tcp --permanent
sudo firewall-cmd --reload

# D. Verificatie dat container draait:
sudo podman ps | grep piholejf

# E. Controleer dat data daadwerkelijk opgeslagen wordt in de host mappen:
echo "=== Inhoud /dataJF/conf ==="
sudo ls -la /dataJF/conf/
echo ""
echo "=== Inhoud /dataJF/logs ==="
sudo ls -la /dataJF/logs/

# F. Toon dat alleen root toegang heeft (andere gebruikers kunnen niet lezen):
echo "=== Toegang test voor niet-root gebruiker ==="
echo "Test 1: Directory permissions"
ls -ld /dataJF/conf /dataJF/logs
echo ""

echo "Test 2: Probeer te lezen als student gebruiker"
sudo -u student ls -la /dataJF/conf 2>&1 | head -1
echo ""

echo "Test 3: Probeer te lezen als nobody gebruiker"
sudo -u nobody ls -la /dataJF/logs 2>&1 | head -1
echo ""

echo "Test 4: Probeer bestand te maken als niet-root"
sudo -u nobody touch /dataJF/conf/test.txt 2>&1 | head -1
echo ""

echo "Test 5: Check eigenaar van bestanden"
sudo ls -la /dataJF/conf/ | head -3
echo ""

# G. Web interface openen (vereist DNS configuratie voor serverJF.lan):
# Eerst /etc/hosts aanpassen voor lokale DNS:
echo "127.0.0.1 serverJF.lan" | sudo tee -a /etc/hosts

# Open browser naar: http://serverJF.lan/admin
# Wachtwoord: Pass1234

# H. DNS test met nslookup:
echo "=== DNS test ==="
nslookup www.kde.org 127.0.0.1

# I. Advertentie test:
# Backup huidige DNS config:
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Stel Pi-hole in als DNS server:
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Verificatie dat Pi-hole ad blocking werkt:
echo "=== Ad blocking test ==="
nslookup doubleclick.net 127.0.0.1

# OPTIONEEL: Verwijder test bestanden
sudo rm -f /dataJF/conf/test.txt 2>/dev/null

# Open browser naar: https://fuzzthepiguy.tech/adtest/
# Controleer dat er geen advertenties worden getoond

# Extra verificatie:
echo "=== Extra volume verificatie ==="
echo "1. Check of bestanden worden gesynchroniseerd:"
sudo podman exec piholejf touch /etc/pihole/test_from_container.txt
sleep 2
echo "Bestand op host:"
sudo ls -la /dataJF/conf/test_from_container.txt

echo "2. Check container gebruiker toegang:"
sudo podman exec piholejf ls -la /etc/pihole/

echo "3. Check log schrijven:"
sudo podman exec piholejf echo "Test log entry" >> /var/log/pihole/pihole.log
sleep 2
echo "Laatste regel van log op host:"
sudo tail -1 /dataJF/logs/pihole.log 2>/dev/null || echo "Log bestand nog niet aangemaakt"

# OPTIONEEL: Herstel DNS config (alleen als je Pi-hole niet als permanente DNS wilt):
# sudo mv /etc/resolv.conf.backup /etc/resolv.conf

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
# ============================================
# STEP 1: Create named volumes
# ============================================
sudo podman volume create mediaJF
sudo podman volume create configuratieJF

# Verify volumes
sudo podman volume ls
sudo podman volume inspect mediaJF
sudo podman volume inspect configuratieJF

# ============================================
# STEP 2: Prepare network interfaces
# ============================================

# Enable promiscuous mode on parent interface
sudo ip link set ens160 promisc on

# Verify promiscuous mode is enabled
ip link show ens160 | grep PROMISC

# ============================================
# STEP 3: Create macvlan network
# ============================================
sudo podman network create \
  --driver macvlan \
  -o parent=ens160 \
  --subnet 192.168.112.0/24 \
  --gateway 192.168.112.1 \
  macvlanJF

# Verify macvlan network
sudo podman network inspect macvlanJF

# ============================================
# STEP 4: Create macvlan interface on HOST
# ============================================
# This is CRITICAL for host-to-container communication on macvlan

sudo ip link add mvlan0 link ens160 type macvlan mode bridge
sudo ip addr add 192.168.112.102/24 dev mvlan0
sudo ip link set mvlan0 up

# Verify host macvlan interface
ip addr show mvlan0

# ============================================
# STEP 5: Pull and run Jellyfin container
# ============================================
sudo podman pull docker.io/jellyfin/jellyfin:latest

sudo podman run -d \
  --name jellyfinJF \
  --network macvlanJF \
  --ip 192.168.112.101 \
  -v mediaJF:/media \
  -v configuratieJF:/config \
  --restart=always \
  docker.io/jellyfin/jellyfin:latest

# Wait for container to fully start
sleep 15

# Verify container is running
sudo podman ps

# ============================================
# STEP 6: Test connectivity
# ============================================
ping -c 3 192.168.112.101

# Test HTTP connectivity
curl -I http://192.168.112.101:8096

# ============================================
# STEP 7: Make macvlan interface persistent
# ============================================
sudo nmcli connection add type macvlan ifname mvlan0 dev ens160 mode bridge ip4 192.168.112.102/24 gw4 192.168.112.1
sudo nmcli connection up macvlan0

# ============================================
# STEP 8: Add penguin photo to media volume
# ============================================
MP=$(sudo podman volume inspect mediaJF -f '{{.Mountpoint}}')

# Create Pictures directory
sudo mkdir -p "$MP/Pictures"

# Copy penguin photo (ensure /home/student/pinguin.jpg exists)
sudo cp /home/student/pinguin.jpg "$MP/Pictures/penguin.jpg"

# Set proper permissions for Jellyfin to read
sudo chmod -R 777 "$MP/Pictures"

# Verify the file
sudo ls -lh "$MP/Pictures/"
sudo podman exec jellyfinJF ls -lh /media/Pictures/

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

# 1. Maak project directory
cd ~
rm -rf nginx-jens 2>/dev/null
mkdir -p nginx-jens/html
cd nginx-jens

# 2. Maak HTML bestand met voor- en achternaam
echo "Jens Fripont" > html/index.html

# 3. Maak Containerfile
cat > Containerfile << 'EOF'
# Start van ubi10/ubi zoals vereist in opgave
FROM registry.access.redhat.com/ubi10/ubi

# Metadata
LABEL author="Jens Fripont"
LABEL description="Nginx container voor oefening 3"

# Installeer nginx
RUN dnf install -y nginx && \
    dnf clean all

# Maak directory voor HTML content
RUN mkdir -p /usr/share/nginx/html

# Kopieer HTML content van host naar container (COPY ipv volume)
COPY html/index.html /usr/share/nginx/html/

# Zorg voor correcte permissions
RUN chmod 644 /usr/share/nginx/html/index.html

# Expose poort 80
EXPOSE 80

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
EOF

# 4. Maak docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginxjens:
    build: .
    container_name: nginxjens
    ports:
      - "9000:80"    # Poort 9000 op containerhost zoals vereist
    restart: unless-stopped
EOF

# 5. Build image via podman-compose
echo "=== Building image via podman-compose ==="
podman-compose build

# 6. Start container via podman-compose
echo "=== Starting container ==="
podman-compose up -d

# 7. Wacht voor opstart
echo "Wachten op container opstart..."
sleep 3

# 8. Test met curl (vereist in opgave)
echo ""
echo "=== TEST MET CURL ==="
curl localhost:9000

# 4. Met podman-compose.
# Pas oefening 3 aan zodat gebruik wordt gemaakt van een eigen netwerk (rootless). 
# Maak ook gebruik van Visual Studio Code.
# Stel ook in dat de webpagina beschikbaar is vanaf je Windows 11 host. De container krijgt als IP 10.10.10.10. Maak uiteraard geen gebruik van de GUI.
# Opgelet: je moet eerst een extern netwerk aanmaken!

# OPLOSSING:
# =============================================
# OEFENING 4: Podman Compose met eigen netwerk
# =============================================

# 1. Maak project directory
cd ~
rm -rf nginx-jens-network 2>/dev/null
mkdir -p nginx-jens-network/html
cd nginx-jens-network

# 2. Maak HTML bestand met voor- en achternaam
echo "Jens Fripont" > html/index.html

# 3. Maak een extern rootless netwerk aan (vereist voor opgave)
echo "=== Aanmaken rootless netwerk ==="
podman network create \
  --subnet 10.10.0.0/16 \
  --ip-range 10.10.10.0/24 \
  --gateway 10.10.0.1 \
  nginx-jens-network

# 4. Toon netwerk informatie
echo "=== Netwerk informatie ==="
podman network inspect nginx-jens-network

# 5. Maak Containerfile
cat > Containerfile << 'EOF'
# Start van ubi10/ubi
FROM registry.access.redhat.com/ubi10/ubi

# Metadata
LABEL maintainer="Jens Fripont"
LABEL description="Nginx met custom netwerk configuratie"

# Installeer nginx
RUN dnf install -y nginx && \
    dnf clean all

# Maak directory voor HTML content
RUN mkdir -p /usr/share/nginx/html

# Kopieer HTML content
COPY html/index.html /usr/share/nginx/html/

# Zorg voor correcte permissions
RUN chmod 644 /usr/share/nginx/html/index.html

# Expose poort 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

# 6. Maak docker-compose.yml met eigen netwerk en statisch IP
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginxjens:
    build: .
    container_name: nginxjens
    image: nginx-jens-network:latest
    ports:
      - "9000:80"    # Poort mapping voor Windows 11 toegang
    networks:
      nginx-jens-network:
        ipv4_address: 10.10.10.10  # Statisch IP zoals vereist
    restart: unless-stopped
    dns:
      - 8.8.8.8
      - 1.1.1.1

networks:
  nginx-jens-network:
    external: true
    name: nginx-jens-network
EOF

# 7. Build image via podman-compose
echo ""
echo "=== Building image ==="
podman-compose build

# 8. Start container via podman-compose
echo ""
echo "=== Starting container ==="
podman-compose up -d

# 9. Wacht voor opstart
echo "Wachten op container opstart..."
sleep 5

# 10. Test vanaf Linux host
echo ""
echo "=== TEST VANAF LINUX HOST ==="
echo "1. Test via localhost:"
curl -s localhost:9000 

echo ""
echo "2. Test via container IP 10.10.10.10:"
curl -s 10.10.10.10 

# 5. Schrijf een containerfile waarbij er een bestand /aanmaakdatum in de image wordt aangemaakt met als inhoud de datum wanneer het image is aangemaakt (maak gebruik van commando date) en je voor- en achternaam in het formaat zoals hieronder staat weergegeven. 

# Je zorgt er uiteraard voor dat je eigen naam wordt weergegeven.
# Baseer je op ubi10/ubi-image. De image die je aanmaakt moet dateimage<jeinitialen> noemen. 
# Een container afgeleid van deze image moet blijven draaien, ook als je de optie -it niet meegeeft aan het commando podman.
# Test dit ook uit. 

# OPLOSSING:
mkdir -p ~/oef7-5
cd ~/oef7-5
nano Dockerfile
# Dockerfile voor dateimagejf
# Base image: ubi10/ubi
# Auteur: Fripont Jens
# Datum: $(date)

# Gebruik de officiële UBI 10 base image
FROM ubi10/ubi:latest

# Metadata labels
LABEL maintainer="12403538@student.pxl.be"
LABEL description="Image met aanmaakdatum en persoonlijke informatie"
LABEL version="1.0"
LABEL created="$(date)"

# Installeer updates en benodigde packages
RUN dnf update -y --nodocs && \
    dnf install -y --nodocs procps-ng hostname && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*

# Maak het vereiste bestand aan met aanmaakdatum en naam
# De datum wordt vastgelegd tijdens het build proces
RUN echo "==========================================" > /aanmaakdatum && \
    echo "Container Image Informatie" >> /aanmaakdatum && \
    echo "==========================================" >> /aanmaakdatum && \
    echo "" >> /aanmaakdatum && \
    echo "Aanmaakdatum van de image: $(date '+%d-%m-%Y %H:%M:%S')" >> /aanmaakdatum && \
    echo "Naam: Fripont Jens" >> /aanmaakdatum && \
# Maak een healthcheck aan (optioneel maar goede practice)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ps aux | grep -q "[t]ail" || exit 1

# Stel de standaard command in die de container draaiend houdt
# Gebruik tail -f /dev/null voor een oneindige loop
CMD ["tail", "-f", "/dev/null"]

# Expose poorten indien nodig (optioneel)
# EXPOSE 80

# Werkdirectory instellen
WORKDIR /root

# Environment variables
ENV IMAGE_NAME="dateimage<jeinitialen>"
ENV CREATOR="[Jouw Naam]"
ENV CREATION_DATE="$(date)"

podman build -t dateimagejf .
podman run -d --name mijncontainerjf dateimagejf
podman exec -it mijncontainerjf cat /aanmaakdatum

#!/bin/bash
# Kubernetes Oefeningen Deel 2
# Initialen: JF (pas aan naar je eigen initialen)
# ip serverJF : 192.168.112.110

Oefening 8: iSCSI
1.	We hebben in dit hoofdstuk via iSCSI een remote block device gekoppeld, geformatteerd, gemount, en gebruikt als /mnt/iscsi. Draai dit terug zoals vóór de iSCSI-login op Server<jeinitialen>. Laat zien dat sda verdwenen is. Niet via een snapshot natuurlijk 😉.
# unmounten 
sudo umount /dev/sda1
# verwijderen 
sudo parted /dev/sda --script rm 1

3.	Maak een SMB-share met de naam <jeinitialen> aan met een lokale user met als naam <jeachternaam> op TrueNAS. Maak verbinding met deze share op Server<jeinitialen>. Maak een webpagina aan die je voor- en achternaam toont in deze SMB-share. Toon via een apache-container dat je webpagina kan getoond worden op de container host.
# dataset JF aanmaken op TrueNAS, SMB preset 
# user Fripont aanmaken op TrueNAS met wachtwoord
# share JF aanmaken op TrueNAS met toegang voor user Fripont, bij acl voeg je user Fripont toe met volledige rechten (wheel)

# === STAP 1: SMB-share mounten ===
# Maak mount directory
sudo mkdir -p /mnt/smbjf

# Unmount eerst als al gemount
sudo umount /mnt/smbjf 2>/dev/null

# Mount SMB share met WORKGROUP (belangrijk!)
sudo mount -t cifs //10.10.10.22/JF /mnt/smbjf \
  -o username=fripont,password=Pass1234,vers=3.0,domain=WORKGROUP,uid=$(id -u),gid=$(id -g)

# Alternatief als bovenstaande faalt:
# sudo mount -t cifs //10.10.10.22/JF /mnt/smbjf \
#   -o username=fripont,password=Pass1234,vers=2.1,domain=WORKGROUP

# Controleer mount
mount | grep smb
df -h | grep smb

# === STAP 2: Samba-client installeren (indien nodig) ===
sudo dnf install -y samba-client cifs-utils

# === STAP 3: Webpagina aanmaken ===
echo "<html><body><h1>Jens Fripont</h1></body></html>" | sudo tee /mnt/smbjf/index.html

# Zet correcte permissies
sudo chmod 644 /mnt/smbjf/index.html

# Controleer
ls -la /mnt/smbjf/
cat /mnt/smbjf/index.html

# === STAP 4: Apache container starten (GARANTIE WERKT) ===
# Stop bestaande containers
sudo podman stop apache 2>/dev/null
sudo podman rm apache 2>/dev/null

# Gebruik httpd:alpine (werkt altijd, klein, heeft alle tools)
sudo podman pull docker.io/library/httpd:alpine

# Start container op poort 8888 (minder kans op conflicten)
sudo podman run -d --name apache -p 8888:80 \
  -v /mnt/smbjf:/usr/local/apache2/htdocs:Z \
  docker.io/library/httpd:alpine

# Controleer container
sleep 2
sudo podman ps
sudo podman logs apache

# === STAP 5: Firewall configureren ===
# Open poort 8888 (in plaats van 8080 voor minder conflicten)
sudo firewall-cmd --add-port=8888/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports

# === STAP 6: Testen ===
# Test 1: Directe curl
curl http://localhost:8888

# Test 2: Met verbose voor debugging
curl -v http://localhost:8888 2>&1 | head -20

# Test 3: Container IP (alternatieve test)
CONTAINER_IP=$(sudo podman inspect apache --format '{{.NetworkSettings.IPAddress}}')
echo "Container IP: $CONTAINER_IP"
curl http://$CONTAINER_IP

76.	Uitbreidingsoefening 3

Verwijder het zfs-volume op TrueNAS en maak een zfs-volume aan met als naam <jevoornaam> van ongeveer 20 GiB. Dit zfs-volume mag via iSCSI enkel beschikbaar zijn via <jevoornaam> en een wachtwoord dat je zelf kiest op Server<jeintialen>. Maak hiervoor gebruik van CHAP. Laat ook zien dat je verbinding kan maken op ServerXX analoog aan hetgeen hieronder staat.
# datasets -->> gemaakte zvol klikken en delete kiezen 
# add zvol met naam Jens van 20GiB

Stap 2 – iSCSI CHAP-gebruiker aanmaken

Ga naar Sharing → Block (iSCSI) → Portals (controleer of een portal bestaat; zo niet, maak er één aan met het juiste IP-adres).

Ga naar Initiators:

Initiators: leeg laten of beperken tot het IP van ServerXX

Authorized Networks: optioneel het subnet van ServerXX

Ga naar Authorized Access.

Klik Add en vul in:

User: jens

Secret: Pass1234Pass1234

Peer User / Peer Secret: leeg laten (tenzij wederzijdse CHAP vereist is)

Opslaan.

Stap 4 – Extent aanmaken

Ga naar Extents → Add.

Vul in:

Extent Type: Device

Device: zvol/tank/<jevoornaam>

Extent Name: <jevoornaam>_extent

Opslaan.

# node updaten 
sudo iscsiadm -m node \
  -T iqn.2005-10.org.freenas.ctl:jens \
  -p 10.10.10.22:3260 \
  -o new

# chap instellen 
sudo iscsiadm -m node \
  -T iqn.2005-10.org.freenas.ctl:jens \
  -p 10.10.10.22:3260 \
  --op update -n node.session.auth.authmethod -v CHAP

sudo iscsiadm -m node \
  -T iqn.2005-10.org.freenas.ctl:jens \
  -p 10.10.10.22:3260 \
  --op update -n node.session.auth.username -v jens

sudo iscsiadm -m node \
  -T iqn.2005-10.org.freenas.ctl:jens \
  -p 10.10.10.22:3260 \
  --op update -n node.session.auth.password -v Pass1234Pass1234

sudo iscsiadm -m node \
  -T iqn.2005-10.org.freenas.ctl:jens \
  -p 10.10.10.22:3260 \
  --login


# ============================================
# OEFENING 9: K8S - CLUSTERS
# ============================================
# OPGAVE:
# 1. Stop nu de cluster dev-cluster uit de cursus.
# 2. Maak een nieuwe cluster aan genaamd PXL met één server node.
# 3. Voeg een werker node toe aan de PXL cluster.
# 4. Verwijder deze laatste aangemaakte node uit de PXL cluster.
# 5. Verwijder nu de cluster PXL.
# 6. Maak een nieuwe cluster aan genaamd SNE met 1 Control plane en 2 Worker nodes.
# 7. Zoek het commando om alle clusters op te lijsten.
# 8. Stop de cluster SNE en lijst weer alle clusters op.
# 9. Verwijder de cluster SNE
# 10. Verwijder alle clusters.
# ============================================

# OPLOSSING:

# 1. Stop de cluster dev-cluster
k3d cluster stop dev-cluster

# 2. Maak nieuwe cluster PXL met één server node
k3d cluster create PXL --servers 1

# 3. Voeg een worker node toe aan PXL cluster
k3d node create pxl-worker --cluster PXL --role agent

# 4. Verwijder de laatst aangemaakte node uit PXL cluster
k3d node delete pxl-worker-0

# 5. Verwijder de cluster PXL
k3d cluster delete PXL

# 6. Maak cluster SNE met 1 control plane en 2 worker nodes
k3d cluster create SNE --servers 1 --agents 2

# 7. Lijst alle clusters op
k3d cluster list

# 8. Stop de cluster SNE en lijst alle clusters op
k3d cluster stop SNE
k3d cluster list

# 9. Verwijder de cluster SNE
k3d cluster delete SNE

# 10. Verwijder alle clusters
k3d cluster delete --all

# ============================================
# OEFENING 10: K8S - PODS
# ============================================
# OPGAVE:
# 1. Verwijder alle aanwezige clusters en maak een nieuwe cluster aan genaamd 
#    clusterPH<jeinitialen> met 1 server en 2 worker nodes.
# 2. Maak een pod aan genaamd "pihole" door de pihole docker te gebruiken. 
#    Doe dit op een declaratieve manier.
# 3. Test of je de pihole webgui kan contacteren via curl in de container zelf.
# 4. Maak een pod aan voor een Apache website. Doe dit op een declaratieve manier.
# 5. Zorg dat de Apache server luistert op poort 8083 voor default Apache web page. 
#    Pas hiervoor het yaml-bestand aan.
# 6. Test ook of je deze default webpage kan bereiken lokaal in de container zelf.
# 7. Maak een tweede pod aan dewelke de ubi10-init image gebruikt en test of je de 
#    default pagina van de voorgaande Apache pod kan bereiken vanaf de zojuist 
#    aangemaakte container.
# ============================================

# OPLOSSING:

# 1. Verwijder alle clusters en maak nieuwe aan
k3d cluster delete --all
k3d cluster create clusterPHjf --servers 1 --agents 2

# 2. Maak pihole pod (declaratief) met health checks en env vars
cat <<EOF > pihole-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pihole
  labels:
    app: pihole
spec:
  containers:
  - name: pihole
    image: pihole/pihole:latest
    ports:
    - containerPort: 80
    env:
    - name: TZ
      value: Europe/Brussels
    - name: WEBPASSWORD
      value: "pihole-jf"
    readinessProbe:
      httpGet:
        path: /admin
        port: 80
      initialDelaySeconds: 15
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /admin
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
EOF
kubectl apply -f pihole-pod.yaml

# 3. Test pihole webgui via curl in de container
kubectl exec -it pihole -- curl http://localhost/admin

# 4 & 5. Maak Apache pod op poort 8083 (declaratief) met health checks
cat <<EOF > apache-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache
  labels:
    app: apache
spec:
  containers:
  - name: apache
    image: httpd:2.4-alpine
    ports:
    - containerPort: 8083
    command: ["httpd", "-DFOREGROUND", "-c", "Listen 8083"]
    readinessProbe:
      tcpSocket:
        port: 8083
      initialDelaySeconds: 5
      periodSeconds: 10
    livenessProbe:
      tcpSocket:
        port: 8083
      initialDelaySeconds: 10
      periodSeconds: 10
EOF
kubectl apply -f apache-pod.yaml

# 6. Test Apache default webpage lokaal in de container
kubectl exec apache -- wget -O- http://localhost:8083

# 7. Maak ubi10-init pod en test connectie naar Apache
cat <<EOF > ubi-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubi-test
spec:
  containers:
  - name: ubi
    image: registry.access.redhat.com/ubi9/ubi-init
    command: ["sleep", "infinity"]
EOF
kubectl apply -f ubi-pod.yaml

# Haal Apache pod IP op en test vanuit ubi pod
APACHE_IP=$(kubectl get pod apache -o jsonpath='{.status.podIP}')
kubectl exec -it ubi-test -c ubi -- sh -c "curl -m 5 -sS http://\$APACHE_IP:8083 || wget -qO- http://\$APACHE_IP:8083 || echo 'FAILED to fetch Apache page from \$APACHE_IP:8083'"

# ============================================
# OEFENING 11: K8S - KUBECTL
# ============================================
# OPGAVE:
# 1. Verwijder eerst alle clusters.
# 2. Maak een cluster mijncluster aan met 1 control plane en 2 worker nodes.
# 3. Toon een overzicht van alle contexten.
# 4. List al je clusters.
# 5. Maak een nieuwe context smalldev aan voor mijncluster en switch naar smalldev.
# 6. Toon een overzicht van alle contexten.
# 7. Switch naar standaard context voor mijncluster.
# 8. Toon config file details.
# ============================================

# OPLOSSING:

# 1. Verwijder alle clusters
k3d cluster delete --all

# 2. Maak cluster mijncluster met 1 control plane en 2 worker nodes
k3d cluster create mijncluster --servers 1 --agents 2

# 3. Toon overzicht van alle contexten
kubectl config get-contexts

# 4. List alle clusters
k3d cluster list

# 5. Maak nieuwe context smalldev aan en switch ernaar
kubectl config set-context smalldev --cluster=k3d-mijncluster --user=admin@k3d-mijncluster
kubectl config use-context smalldev

# 6. Toon overzicht van alle contexten
kubectl config get-contexts

# 7. Switch naar standaard context voor mijncluster
kubectl config use-context k3d-mijncluster

# 8. Toon config file details
kubectl config view

# ============================================
# OEFENING 12: K8S - NAMESPACES
# ============================================
# OPGAVE:
# 1. Maak een nieuwe cluster genaamd Namespaces.
# 2. Maak een nieuwe Namespace "dns" aan op een imperatieve wijze.
# 3. Maak een nieuwe Namespace "web" aan op een declaratieve wijze.
# 4. Herwerk de pihole pod nu zodat deze in de "DNS" namespace terecht komt.
# 5. Herwerk de apache pod nu zodat deze in de "Web" namespace terecht komt. 
#    Zorg er ook voor dat de pod op poort 8023 luistert.
# 6. Probeer eens te pingen vanaf de apache pod naar de pihole pod.
# ============================================

# OPLOSSING:

# 1. Maak nieuwe cluster Namespaces
k3d cluster create namespaces --servers 1 --agents 2

# 2. Maak namespace "dns" aan (imperatief)
kubectl create namespace dns

# 3. Maak namespace "web" aan (declaratief)
cat <<EOF > web-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: web
EOF
kubectl apply -f web-namespace.yaml

# 4. Pihole pod in dns namespace
cat <<EOF > pihole-dns.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pihole
  namespace: dns
  labels:
    app: pihole
spec:
  containers:
  - name: pihole
    image: pihole/pihole
    ports:
    - containerPort: 80
EOF
kubectl apply -f pihole-dns.yaml

# Service voor pihole (nodig voor cross-namespace communicatie)
cat <<EOF > pihole-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: pihole-svc
  namespace: dns
spec:
  selector:
    app: pihole
  ports:
  - port: 80
    targetPort: 80
EOF
kubectl apply -f pihole-svc.yaml

# 5. Apache pod in web namespace op poort 8023
cat <<EOF > apache-web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache
  namespace: web
  labels:
    app: apache
spec:
  containers:
  - name: apache
    image: httpd:latest
    ports:
    - containerPort: 8023
    command: ["/bin/sh", "-c"]
    args:
    - sed -i 's/Listen 80/Listen 8023/' /usr/local/apache2/conf/httpd.conf && httpd-foreground
EOF
kubectl apply -f apache-web.yaml

# 6. Ping van apache naar pihole (cross-namespace)
kubectl exec -n web apache -- ping -c 3 pihole-svc.dns.svc.cluster.local

# ============================================
# OEFENING 13: K8S - SERVICES
# ============================================
# OPGAVE:
# 1. Maak voor deze oefening gebruik van ClusterIP. Maak 3 verschillende Apache 
#    containers aan in 3 pods. Pas elke standaardpagina van de website aan met 
#    de inhoud <jeinitialen> web1, <jeinitialen>web2 en <jeinitialen>web3 zodat 
#    er een duidelijk verschil is tussen de 3 containers.
# 2. Koppel deze pods aan dezelfde service dewelke luistert op poort 8890.
# 3. Test nu toegang tot de service uit vanuit één van de 3 pods. Test de toegang 
#    een aantal keer. Verklaar je resultaat.
# 4. Maak twee verschillende Nginx-webservers, elk draaiend op een aparte node in 
#    je Kubernetes-cluster. Beide webservers luisteren intern op poort 80. 
#    Geef de website op de eerste server als inhoud <jevoornaam> en de website op 
#    de tweede server als inhoud <jeachternaam>.
# 5. Configureer voor elke Nginx-pod een eigen NodePort-service zodat de webservers 
#    extern bereikbaar zijn:
#    - Node 1: Intern poort 80, extern NodePort 30500
#    - Node 2: Intern poort 80, extern NodePort 30600
# ============================================

# OPLOSSING:

# 1 & 2. Maak ConfigMaps voor 3 verschillende web pagina's (BEST PRACTICE)
cat <<EOF > apache-configmaps.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web1-index
data:
  index.html: |
    <!DOCTYPE html>
    <html><body><h1>JF web1</h1></body></html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web2-index
data:
  index.html: |
    <!DOCTYPE html>
    <html><body><h1>JF web2</h1></body></html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web3-index
data:
  index.html: |
    <!DOCTYPE html>
    <html><body><h1>JF web3</h1></body></html>
EOF
kubectl apply -f apache-configmaps.yaml

# Maak 3 Apache pods met ConfigMap volumes
cat <<EOF > apache-cluster.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache-web1
  labels:
    app: apache-cluster
    tier: frontend
spec:
  containers:
  - name: apache
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: index
      mountPath: /usr/local/apache2/htdocs/index.html
      subPath: index.html
  volumes:
  - name: index
    configMap:
      name: web1-index
---
apiVersion: v1
kind: Pod
metadata:
  name: apache-web2
  labels:
    app: apache-cluster
    tier: frontend
spec:
  containers:
  - name: apache
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: index
      mountPath: /usr/local/apache2/htdocs/index.html
      subPath: index.html
  volumes:
  - name: index
    configMap:
      name: web2-index
---
apiVersion: v1
nkind: Pod
metadata:
  name: apache-web3
  labels:
    app: apache-cluster
    tier: frontend
spec:
  containers:
  - name: apache
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: index
      mountPath: /usr/local/apache2/htdocs/index.html
      subPath: index.html
  volumes:
  - name: index
    configMap:
      name: web3-index
---
apiVersion: v1
kind: Service
metadata:
  name: apache-svc
spec:
  type: ClusterIP
  selector:
    app: apache-cluster
  ports:
  - port: 8890
    targetPort: 80
EOF
kubectl apply -f apache-cluster.yaml

# ConfigMaps zorgen automatisch voor de juiste inhoud per pod

# 3. Test toegang tot service (meerdere keren - load balancing zichtbaar)
kubectl exec apache-web1 -- curl -s http://apache-svc:8890
kubectl exec apache-web1 -- curl -s http://apache-svc:8890
kubectl exec apache-web1 -- curl -s http://apache-svc:8890
kubectl exec apache-web1 -- curl -s http://apache-svc:8890
kubectl exec apache-web1 -- curl -s http://apache-svc:8890
# Verklaring: Je ziet afwisselend web1, web2, web3 omdat Kubernetes load balancing 
# toepast over de 3 pods achter de service.

# 4 & 5. Nginx ConfigMaps en pods met NodePort services
cat <<EOF > nginx-configmaps.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-node1-index
data:
  index.html: |
    <!DOCTYPE html>
    <html><body><h1>Jens</h1></body></html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-node2-index
data:
  index.html: |
    <!DOCTYPE html>
    <html><body><h1>Fripont</h1></body></html>
EOF
kubectl apply -f nginx-configmaps.yaml

cat <<EOF > nginx-nodeport.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-node1
  labels:
    app: nginx1
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: index
      mountPath: /usr/share/nginx/html/index.html
      subPath: index.html
  volumes:
  - name: index
    configMap:
      name: nginx-node1-index
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-node2
  labels:
    app: nginx2
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: index
      mountPath: /usr/share/nginx/html/index.html
      subPath: index.html
  volumes:
  - name: index
    configMap:
      name: nginx-node2-index
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc1
spec:
  type: NodePort
  selector:
    app: nginx1
    ports:
  - port: 80
    targetPort: 80
    nodePort: 30500
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc2
spec:
  type: NodePort
  selector:
    app: nginx2
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30600
EOF
kubectl apply -f nginx-nodeport.yaml

# Test extern (vanaf host)
# curl http://localhost:30500
# curl http://localhost:30600

# ============================================
# OEFENING 14: K8S - DEPLOYMENTS
# ============================================
# OPGAVE:
# 1. Maak een nieuwe cluster aan genaamd dns met 1 control plane en 3 worker nodes.
# 2. Maak in deze cluster een deployment van Pihole 2025.07.1 met 5 replicas.
# 3. Pas deze deployment nu aan zodat er een rolling update wordt gedaan naar 
#    versie 2025.10.1 en vervolgens naar 2025.11.0.
# 4. Doe op een imperatieve wijze een rollback naar de vorige versie.
# 5. Bewijs dat je deployment aan self-healing kan doen.
# ============================================

# OPLOSSING:

# 1. Maak cluster dns met 1 control plane en 3 worker nodes
k3d cluster create dns --servers 1 --agents 3

# 2. Maak Pihole deployment met versie 2025.07.1 en 5 replicas met health checks
cat <<EOF > pihole-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pihole-deploy
  labels:
    app: pihole
    owner: jf
spec:
  replicas: 5
  selector:
    matchLabels:
      app: pihole
  template:
    metadata:
      labels:
        app: pihole
        tier: dns
    spec:
      containers:
      - name: pihole
        image: pihole/pihole:2025.07.1
        ports:
        - containerPort: 80
        env:
        - name: TZ
          value: Europe/Brussels
        readinessProbe:
          httpGet:
            path: /admin
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /admin
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
EOF
kubectl apply -f pihole-deployment.yaml

# Controleer deployment
kubectl get deployment pihole-deploy
kubectl get pods -l app=pihole

# 3. Rolling update naar 2025.10.1
kubectl set image deployment/pihole-deploy pihole=pihole/pihole:2025.10.1
kubectl rollout status deployment/pihole-deploy

# Rolling update naar 2025.11.0
kubectl set image deployment/pihole-deploy pihole=pihole/pihole:2025.11.0
kubectl rollout status deployment/pihole-deploy

# 4. Rollback naar vorige versie (imperatief)
kubectl rollout undo deployment/pihole-deploy
kubectl rollout status deployment/pihole-deploy

# Controleer huidige versie
kubectl describe deployment pihole-deploy | grep Image

# 5. Bewijs self-healing: verwijder een pod en zie dat een nieuwe wordt aangemaakt
kubectl get pods -l app=pihole
POD_NAME=$(kubectl get pods -l app=pihole -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME
kubectl get pods -l app=pihole -w
# Een nieuwe pod wordt automatisch aangemaakt om 5 replicas te behouden

# ============================================
# OEFENING 15: K8S - STORAGE
# ============================================
# OPGAVE:
# 1. Maak een nieuwe cluster genaamd storage.
# 2. Bouw een volledige Wordpress. Zowel de Wordpress deployment als de MariaDB 
#    deployment moeten gebruik maken van persistant storage. Doe dit op een 
#    declaratieve manier.
# 3. Zorg dat je de wordpress site kan bereiken vanop je eigen computer. Bewijs dit 
#    door via een browser op je eigen laptop naar de site te surfen.
# 4. Maak een Apache pod. Daarnaast maak je ook een ubi10-init pod. Beide pods moeten 
#    op een declaratieve manier aangemaakt worden. Zorg dat beide pods dezelfde 
#    persistant storage delen.
# 5. Maak verschillende files aan op de ubi10-init pod en zorg dat deze ook direct 
#    bruikbaar zijn in de webserver zonder dat je ze eerst hebt moeten kopiëren.
# ============================================

# OPLOSSING:

# 1. Maak cluster storage
k3d cluster create storage --servers 1 --agents 2 -p "30080:30080@server:0"

# Maak namespace en Secret voor database credentials (BEST PRACTICE)
kubectl create namespace jf-storage

cat <<EOF > storage-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret-jf
  namespace: jf-storage
  labels:
    owner: jf
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "RootPass_JF_2025"
  MYSQL_DATABASE: "wordpress"
  MYSQL_USER: "wp_user_jf"
  MYSQL_PASSWORD: "WPPass_JF_2025"
EOF
kubectl apply -f storage-secret.yaml

# 2 & 3. Wordpress + MariaDB met persistent storage en Secrets
cat <<EOF > wordpress-full.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mariadb-pv-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/mariadb-jf
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-pvc-jf
  namespace: jf-storage
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: wordpress-pv-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/wordpress-jf
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc-jf
  namespace: jf-storage
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb-jf
  namespace: jf-storage
  labels:
    app: mariadb-jf
    owner: jf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mariadb-jf
  template:
    metadata:
      labels:
        app: mariadb-jf
        tier: database
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.11
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_ROOT_PASSWORD
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_DATABASE
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_USER
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_PASSWORD
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mariadb-storage
          mountPath: /var/lib/mysql
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}"
          initialDelaySeconds: 20
          periodSeconds: 10
      volumes:
      - name: mariadb-storage
        persistentVolumeClaim:
          claimName: mariadb-pvc-jf
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb-svc-jf
  namespace: jf-storage
  labels:
    app: mariadb-jf
    owner: jf
spec:
  type: ClusterIP
  selector:
    app: mariadb-jf
  ports:
  - port: 3306
    targetPort: 3306
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress-jf
  namespace: jf-storage
  labels:
    app: wordpress-jf
    owner: jf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress-jf
  template:
    metadata:
      labels:
        app: wordpress-jf
        tier: frontend
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.5-apache
        env:
        - name: WORDPRESS_DB_HOST
          value: mariadb-svc-jf
        - name: WORDPRESS_DB_NAME
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_DATABASE
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_USER
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret-jf
              key: MYSQL_PASSWORD
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc-jf
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-svc-jf
  namespace: jf-storage
  labels:
    app: wordpress-jf
    owner: jf
spec:
  type: NodePort
  selector:
    app: wordpress-jf
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
kubectl apply -f wordpress-full.yaml

# Toegang via browser: http://localhost:30080
# Website naam: websitejf
# Email: jens.fripont@student.pxl.be
# Bij setup voer je de gegevens in die in de Secret staan

# 4 & 5. Apache en UBI met shared storage (ReadWriteMany)
cat <<EOF > shared-storage.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: shared-pv-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/shared-jf
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc-jf
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: apache-shared-jf
  labels:
    app: apache-shared
    tier: frontend
    owner: jf
spec:
  containers:
  - name: apache
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-vol
      mountPath: /usr/local/apache2/htdocs
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
  volumes:
  - name: shared-vol
    persistentVolumeClaim:
      claimName: shared-pvc-jf
---
apiVersion: v1
kind: Pod
metadata:
  name: ubi-shared-jf
  labels:
    app: ubi-shared
    tier: utility
    owner: jf
spec:
  containers:
  - name: ubi
    image: registry.access.redhat.com/ubi9/ubi-init:latest
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: shared-vol
      mountPath: /shared
  volumes:
  - name: shared-vol
    persistentVolumeClaim:
      claimName: shared-pvc-jf
EOF
kubectl apply -f shared-storage.yaml

# 5. Maak files aan op ubi en test op apache (direct beschikbaar)
kubectl exec ubi-shared-jf -- sh -c 'echo "<h1>Hello from UBI</h1>" > /shared/index.html'
kubectl exec ubi-shared-jf -- sh -c 'echo "<h1>Page 2</h1>" > /shared/page2.html'
kubectl exec ubi-shared-jf -- sh -c 'echo "<h1>Page 3</h1>" > /shared/page3.html'

# Controleer dat files direct beschikbaar zijn op Apache (zonder kopieren)
kubectl exec apache-shared-jf -- cat /usr/local/apache2/htdocs/index.html
kubectl exec apache-shared-jf -- cat /usr/local/apache2/htdocs/page2.html
kubectl exec apache-shared-jf -- cat /usr/local/apache2/htdocs/page3.html

# Test via curl
kubectl exec apache-shared-jf -- curl -s http://localhost/index.html
kubectl exec apache-shared-jf -- curl -s http://localhost/page2.html

# ============================================
# OEFENING 16: VAN PODMAN NAAR KUBERNETES
# ============================================
# OPGAVE:
# 1. Maak een cluster met 1 control plane en 1 worker node voor Wordpress. 
#    Wordpress moet beschikbaar worden in het netwerk via poort 9999.
# 2. We zetten nu Wordpress op via Kubernetes. Maak hiervoor eerst de manifestbestanden aan.
#    Je moet bij elk yaml-bestand dat je aanmaakt <jeinitialen> toevoegen:
#    - poddatabase.jf.yaml, pvcdatabase.jf.yaml, pvdatabase.jf.yaml, servicedatabase.jf.yaml
#    - podwordpress.jf.yaml, pvcwordpress.jf.yaml, pvwordpress.jf.yaml, servicewordpress.jf.yaml
# 3. Je moet enkel de inhoud van pvdatabase, pvwordpress, pvcdatabase en pvcwordpress yaml tonen.
# 4. Elke service, pod enz. moet je dus apart aanmaken. Je moet niet werken met deployments.
# 5. Toon alle commando's die je uitvoert op alle yaml-bestanden.
# 6. Als je alle resources verwijdert (ook pvc!) moet de website opgeslagen blijven in het cluster.
# 7. Geef de website als naam website<jeinitialen> en vul je mailadres van de pxl in.
# 8. Test of de website bereikbaar blijft door eerst alle resources ongedaan te maken en 
#    ze daarna opnieuw toe te passen.
#
# DRUPAL (uitbreiding):
# 9. Installeer Drupal in een podman pod. De website moet beschikbaar zijn op poort 8080.
#    De naam van de website is website<jeinitialen>. Het e-mailadres is jouw e-mailadres van de PXL.
#    Onderhoudsaccount: gebruikersnaam is je voornaam, wachtwoord kies je zelf.
#    Gebruik volgende named volumes: drupal-mysql en drupal-files.
#    Opgelet: enkel :/var/www/html/sites/default/files koppelen en niet /var/www/html!
# 10. Leid nu een Kubernetes-manifest af van deze pod met de naam drupal<jouwinitialen>.yaml.
# 11. Verwijder de pod en maak een backup van het yaml bestand.
# 12. Verwijder zo veel mogelijk regels uit het yaml bestand en zorg voor duidelijke namen voor PVC.
# 13. Wijzig ook de containerpoort door de juiste van mariadb.
# 14. Zorg er nu voor dat Drupal werkt via Kubernetes via pod.
# ============================================

# OPLOSSING:

# 1. Maak cluster voor Wordpress op poort 9999
k3d cluster create wordpress-cluster --servers 1 --agents 1 -p "9999:9999@server:0"

# Maak Secret voor database credentials (BEST PRACTICE)
cat <<EOF > wordpress-secret.jf.yaml
apiVersion: v1
kind: Secret
metadata:
  name: wordpress-db-secret-jf
  labels:
    owner: jf
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "RootPass_WP_JF_2025"
  MYSQL_DATABASE: "wordpress"
  MYSQL_USER: "wp_user_jf"
  MYSQL_PASSWORD: "WPPass_JF_2025"
EOF
kubectl apply -f wordpress-secret.jf.yaml

# 2. Maak alle yaml bestanden apart aan

# pvdatabase.jf.yaml
cat <<EOF > pvdatabase.jf.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-database-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/database-jf
EOF

# pvcdatabase.jf.yaml
cat <<EOF > pvcdatabase.jf.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-database-jf
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# pvwordpress.jf.yaml
cat <<EOF > pvwordpress.jf.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-wordpress-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/wordpress-jf
EOF

# pvcwordpress.jf.yaml
cat <<EOF > pvcwordpress.jf.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-wordpress-jf
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# poddatabase.jf.yaml
cat <<EOF > poddatabase.jf.yaml
apiVersion: v1
kind: Pod
metadata:
  name: database-jf
  labels:
    app: database
    tier: database
    owner: jf
spec:
  containers:
  - name: mariadb
    image: mariadb:10.11
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_ROOT_PASSWORD
    - name: MYSQL_DATABASE
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_DATABASE
    - name: MYSQL_USER
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_USER
    - name: MYSQL_PASSWORD
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_PASSWORD
    ports:
    - containerPort: 3306
    volumeMounts:
    - name: db-storage
      mountPath: /var/lib/mysql
    readinessProbe:
      exec:
        command:
        - /bin/sh
        - -c
        - mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}"
      initialDelaySeconds: 20
      periodSeconds: 10
  volumes:
  - name: db-storage
    persistentVolumeClaim:
      claimName: pvc-database-jf
EOF

# servicedatabase.jf.yaml
cat <<EOF > servicedatabase.jf.yaml
apiVersion: v1
kind: Service
metadata:
  name: database-svc-jf
  labels:
    app: database
    owner: jf
spec:
  type: ClusterIP
  selector:
    app: database
  ports:
  - port: 3306
    targetPort: 3306
EOF

# podwordpress.jf.yaml
cat <<EOF > podwordpress.jf.yaml
apiVersion: v1
kind: Pod
metadata:
  name: wordpress-jf
  labels:
    app: wordpress
    tier: frontend
    owner: jf
spec:
  containers:
  - name: wordpress
    image: wordpress:6.5-apache
    env:
    - name: WORDPRESS_DB_HOST
      value: database-svc-jf
    - name: WORDPRESS_DB_NAME
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_DATABASE
    - name: WORDPRESS_DB_USER
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_USER
    - name: WORDPRESS_DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: wordpress-db-secret-jf
          key: MYSQL_PASSWORD
    ports:
    - containerPort: 80
    volumeMounts:
    - name: wp-storage
      mountPath: /var/www/html
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 20
      periodSeconds: 10
  volumes:
  - name: wp-storage
    persistentVolumeClaim:
      claimName: pvc-wordpress-jf
EOF

# servicewordpress.jf.yaml
cat <<EOF > servicewordpress.jf.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-svc-jf
  labels:
    app: wordpress
    owner: jf
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
    nodePort: 9999
EOF

# 5. Alle commando's om yaml bestanden toe te passen
kubectl apply -f pvdatabase.jf.yaml
kubectl apply -f pvcdatabase.jf.yaml
kubectl apply -f pvwordpress.jf.yaml
kubectl apply -f pvcwordpress.jf.yaml
kubectl apply -f poddatabase.jf.yaml
kubectl apply -f servicedatabase.jf.yaml
kubectl apply -f podwordpress.jf.yaml
kubectl apply -f servicewordpress.jf.yaml

# Controleer resources
kubectl get pv,pvc,pods,svc

# 7. Configureer website: websitejf met PXL mailadres
# Ga naar http://localhost:9999 en volg de installatie wizard
# Website naam: websitejf
# Email: jens.fripont@student.pxl.be

# 8. Test persistentie: verwijder alle resources en hermaak
kubectl delete -f podwordpress.jf.yaml
kubectl delete -f poddatabase.jf.yaml
kubectl delete -f servicewordpress.jf.yaml
kubectl delete -f servicedatabase.jf.yaml
kubectl delete -f pvcwordpress.jf.yaml
kubectl delete -f pvcdatabase.jf.yaml
# PV's blijven bestaan door Retain policy, data blijft behouden

# Hermaak alles
kubectl apply -f pvdatabase.jf.yaml
kubectl apply -f pvcdatabase.jf.yaml
kubectl apply -f pvwordpress.jf.yaml
kubectl apply -f pvcwordpress.jf.yaml
kubectl apply -f poddatabase.jf.yaml
kubectl apply -f servicedatabase.jf.yaml
kubectl apply -f podwordpress.jf.yaml
kubectl apply -f servicewordpress.jf.yaml

# Website is nog steeds beschikbaar op http://localhost:9999

# ============================================
# DRUPAL MET PODMAN
# ============================================

# 9. Installeer Drupal in podman pod (BEST PRACTICE: gebruik Secret voor credentials)

# Maak Secret voor Drupal
podman volume create drupal-mysql
podman volume create drupal-files

podman pod create --name drupaljf -p 8080:80

# Start MariaDB container met named volume
podman run -d --pod drupaljf --name drupal-mysql \
  -e MYSQL_ROOT_PASSWORD=RootPass_Drupal_JF \
  -e MYSQL_DATABASE=drupal_jf \
  -e MYSQL_USER=drupal_user_jf \
  -e MYSQL_PASSWORD=DrPass_JF_2025 \
  -v drupal-mysql:/var/lib/mysql \
  mariadb:10.11

# Start Drupal container (alleen files folder koppelen!)
podman run -d --pod drupaljf --name drupal-web \
  -v drupal-files:/var/www/html/sites/default/files \
  drupal:latest

# Configureer via browser: http://localhost:8080
# Website naam: websitejf
# Email: jens.fripont@student.pxl.be
# Gebruikersnaam: Jens
# Wachtwoord: (zelf kiezen)

# 10. Genereer Kubernetes manifest van podman pod
podman generate kube drupaljf > drupaljf.yaml

# 11. Maak backup en verwijder pod
cp drupaljf.yaml drupaljf.jf.yaml~
podman pod rm -f drupaljf

# 12 & 13. Opgeruimde drupal manifest met Secrets
cat <<EOF > drupal-secret.jf.yaml
apiVersion: v1
kind: Secret
metadata:
  name: drupal-db-secret-jf
  labels:
    owner: jf
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "RootPass_Drupal_JF"
  MYSQL_DATABASE: "drupal_jf"
  MYSQL_USER: "drupal_user_jf"
  MYSQL_PASSWORD: "DrPass_JF_2025"
EOF
kubectl apply -f drupal-secret.jf.yaml

cat <<EOF > drupaljf.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: drupal-mysql-pv-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/drupal-mysql-jf
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: drupal-mysql-pvc-jf
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: drupal-files-pv-jf
  labels:
    owner: jf
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/drupal-files-jf
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: drupal-files-pvc-jf
  labels:
    owner: jf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: drupaljf
  labels:
    app: drupal
    tier: application
    owner: jf
spec:
  containers:
  - name: mariadb
    image: mariadb:10.11
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_ROOT_PASSWORD
    - name: MYSQL_DATABASE
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_DATABASE
    - name: MYSQL_USER
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_USER
    - name: MYSQL_PASSWORD
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_PASSWORD
    ports:
    - containerPort: 3306
    volumeMounts:
    - name: mysql-storage
      mountPath: /var/lib/mysql
  - name: drupal
    image: drupal:9-apache
    ports:
    - containerPort: 80
    env:
    - name: DRUPAL_MYSQL_HOST
      value: localhost:3306
    - name: DRUPAL_MYSQL_NAME
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_DATABASE
    - name: DRUPAL_MYSQL_USER
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_USER
    - name: DRUPAL_MYSQL_PASSWORD
      valueFrom:
        secretKeyRef:
          name: drupal-db-secret-jf
          key: MYSQL_PASSWORD
    volumeMounts:
    - name: files-storage
      mountPath: /var/www/html/sites/default/files
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 20
      periodSeconds: 10
  volumes:
  - name: mysql-storage
    persistentVolumeClaim:
      claimName: drupal-mysql-pvc-jf
  - name: files-storage
    persistentVolumeClaim:
      claimName: drupal-files-pvc-jf
---
apiVersion: v1
kind: Service
metadata:
  name: drupal-svc-jf
  labels:
    app: drupal
    owner: jf
spec:
  type: NodePort
  selector:
    app: drupal
  ports:
  - port: 80
    targetPort: 80
    nodePort: 8080
EOF

# 14. Deploy Drupal naar Kubernetes
kubectl apply -f drupaljf.yaml

# Toegang via http://localhost:8080
# Website naam: websitejf
# Email: jens.fripont@student.pxl.be

echo "Alle oefeningen zijn voltooid!"
echo "Vergeet niet 'jf' te vervangen door je eigen initialen."
echo "Best practices toegepast:"
echo "✓ Health checks (readinessProbe, livenessProbe)"
echo "✓ ConfigMaps voor statische content"
echo "✓ Secrets voor database credentials"
echo "✓ Labels en owner tags"
echo "✓ Namespaces voor organisatie"
echo "✓ Persistentie met Retain policy"
echo "✓ DNS service discovery"
echo "✓ Specifieke image versies"

# ============================================
Oefening 17: Proxmox VE 
# ============================================

# OPGAVE
# 1.	Je wil dat de ISO van Alpine Linux beschikbaar wordt via gedeelde Ceph-opslag. Hoe stel je dit in via de GUI? Bij uitval van één server moet de ISO nog beschikbaar blijven. Je moet niet laten zien hoe je Alpine Linux installeert maar enkel hoe je de ISO installeert in de gedeelde opslag.
Ceph --> install ceph 
# 2.	- Voeg een SCSI-schijf van 3000 GB toe aan elke server. 
# - Voeg deze toe aan de Ceph-opslag. 
# - Je mag na de installatie van de schijven Proxmox niet herstarten. 
# - Laat de grootte voor en na van Pool1 zien.

# 3.	Maak een back-up van een VM die je de naam alpine<jeintialen> geeft (hoe die ingesteld is maakt niet uit) naar een Cephfs-storage. Kies voor snelle compressie.

# 4.	- Maak een fedora 42 CT container aan met de naam fedlinux<jeinitialen>. 
# - Maak enkel een screenshot van het venster voordat je Finish klikt over de installatie van fedlinux<jeintialen>. 
# - Waar je deze container aanmaakt speelt geen rol.
# - Start de container op en maar er een webserver van. 
# - De webpagina toont jouw voornaam.
# - Laat je resultaat zien.
# - Stel proxmox zodanig in dat ENKEL poort 80 wordt doorgelaten voor de container. 
# - Laat ook zien hoe dat je alles blokkeert (ook poort 80) en dat de webpagina dan niet beschikbaar is.

