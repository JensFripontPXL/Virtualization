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

#!/bin/bash
# Kubernetes Oefeningen Deel 2
# Initialen: JF (pas aan naar je eigen initialen)
# OPLOSSING: toepassen van de werkende manifests uit deze directory
# Zorg dat namespace 'web' bestaat en gebruik de eerder aangemaakte YAML-bestanden
kubectl create namespace web >/dev/null 2>&1 || true
kubectl apply -f /home/student/Documenten/apache-web-cms.yaml
kubectl apply -f /home/student/Documenten/apache-web-pods.yaml
kubectl apply -f /home/student/Documenten/apache-web-svc.yaml
kubectl apply -f /home/student/Documenten/nginx-index.yaml
kubectl apply -f /home/student/Documenten/nginx-pods.yaml
kubectl apply -f /home/student/Documenten/nginx-nodeports.yaml

# Wacht tot pods klaar zijn
kubectl -n web wait --for=condition=ready pod --all --timeout=120s || true

# Test ClusterIP vanuit web1 (5 requests om loadbalancing te observeren)
kubectl -n web exec web1 -- sh -c "apk add --no-cache curl >/dev/null 2>&1 || true; for i in 1 2 3 4 5; do curl -sS http://web-svc:8890; echo; done"

# Test NodePorts vanaf host (vereist dat de cluster met gepubliceerde poorten is aangemaakt)
echo "Testing NodePorts from host:" 
curl -sS --max-time 5 http://localhost:30500 || echo "NodePort 30500 unreachable"
curl -sS --max-time 5 http://localhost:30600 || echo "NodePort 30600 unreachable"
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

# 6. Ping van apache naar pihole (cross-namespace) - juiste werkwijze
# Stap A: haal het IP-adres van de pihole pod op
kubectl -n dns get pods -o wide

# Stap B: log in op de apache pod met een shell (gebruik `sh`, niet `bash`)
# Voor interactieve debugging:
# kubectl -n web exec -it apache -- sh
# Binnen de shell: voer uit:
# ping <IP-van-pihole-pod>

# Stap C: één-regel alternatief (haalt IP op en voert ping uit; installeert ping
# in de container als dat nodig is en als er een package manager aanwezig is)
kubectl -n web exec apache -- ping -c3 $(kubectl -n dns get pod pihole -o jsonpath='{.status.podIP}')

# Opmerking: sommige containers antwoorden niet op ICMP of hebben geen ping
# beschikbaar. Als ICMP faalt, test dan TCP/HTTP (bijv. met een tijdelijke curl-pod):
# kubectl run -n web curlpod --image=curlimages/curl --restart=Never --command -- sleep 3600
# kubectl exec -n web curlpod -- curl -v http://pihole-svc.dns.svc.cluster.local
# kubectl delete pod -n web curlpod

Oefening 13: K8S - Services

Opmerking
Les eerst de volledige opgave voor je begint!

Inlevering
-	U dient de oplossing van deze oefening zelf te maken en mee te brengen naar PE en (her)examen. Bewaar uw oefeningen in de cloud.

-	Screenshots instellingen én screenshots resultaat zijn verplicht: in elk screenshot moeten jouw initialen staan tenzij het niet anders kan

o	Screenshots moeten duidelijk zijn!

-	Maak gebruik van Server<je_eigen_initialen> en Client<je_eigen_intialen>.

-	Fraude kan leiden tot 0 op PE/(her)examen.


OPGAVE
1.	Maak voor deze oefening gebruik van ClusterIP. 
Maak 3 verschillende Apache containers aan in 3 pods. Pas elke standaardpagina van de website aan met de inhoud <jeinitialen> web1, <jeintialen>web2 en <jeintialen>web3  zodat er een duidelijk verschil is tussen de 3 containers. Koppel deze pods aan dezelfde service dewelke luistert op poort 8890. 
# Maak een ClusterIP Service met 3 Apache Pods
1) ConfigMaps voor de 3 indexpagina's aanmaken
# Maak yaml bestand aan.
apache-web-cms.yaml:

apiVersion: v1
kind: ConfigMap
metadata:
  name: web1-index
  namespace: web
data:
  index.html: |
    <!doctype html>
    <html><body><h1>JF web1</h1></body></html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web2-index
  namespace: web
data:
  index.html: |
    <!doctype html>
    <html><body><h1>JF web2</h1></body></html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web3-index
  namespace: web
data:
  index.html: |
    <!doctype html>
    <html><body><h1>JF web3</h1></body></html>

# Maak de ConfigMaps aan
kubectl apply -f web-index-cms.yaml
2) Maak 3 APache Pods met elk hun eigen index pagina
# Maak yaml bestand aan.
apache-web-pods.yaml:

apiVersion: v1
kind: Pod
metadata:
  name: web1
  namespace: web
  labels:
    app: myweb
    tier: frontend
    site: web1
    owner: JF
spec:
  containers:
    - name: httpd
      image: httpd:2.4-alpine
      # Luister intern op poort 80 (default)
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
  name: web2
  namespace: web
  labels:
    app: myweb
    tier: frontend
    site: web2
    owner: JF
spec:
  containers:
    - name: httpd
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
kind: Pod
metadata:
  name: web3
  namespace: web
  labels:
    app: myweb
    tier: frontend
    site: web3
    owner: JF
spec:
  containers:
    - name: httpd
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
# Maak de Pods aan
kubectl apply -f apache-web-pods.yaml
3) Maak de ClusterIP Service aan
# Maak yaml bestand aan.
apache-web-svc.yaml:

apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: web
spec:
  type: ClusterIP
  selector:
    app: myweb
  ports:
    - name: http
      port: 8890       # service-poort
      targetPort: 80   # container-poort in pods
# Maak de Service aan
kubectl apply -f apache-web-svc.yaml


# Een ClusterIP service balanceert verkeer over alle gezonde pods die aan de selctor voldoen.
# Standaard heeft kubernetes geen sticky session. Kube-proxy doet round-robin per nieuwe verbinding.
# Elke nieuwe request kan op een ander backend uitkomen je ziet afwisselnd JF web1,..
# Als er keep-alive wordt gebruikt, kan meerdere http requests naar dezelfde backend gaan, waardoor het minder wisselt

Test nu toegang tot de service uit vanuit één van de 3 pods. Test de toegang een aantal keer. Verklaar je resultaat.
4) Test en verklaar resultaat
kubectl -n web get pods -o wide
kubectl -n web exec -it web1 -- sh
# Installeer curl indien nodig
apk add curl
curl -sI http://web-svc:8890

2. Maak twee verschillende Nginx-webservers, elk draaiend op een aparte node in je Kubernetes-cluster. Beide webservers luisteren intern op poort 80. Geef de website op de eerste server als inhoud <jevoornaam> en de website op de tweede server als inhoud <jeachternaam>
Configureer voor elke Nginx-pod een eigen NodePort-service zodat de webservers extern bereikbaar zijn via verschillende poorten.:
# Maak de ConfigMaps met de indexpagina's aan
nginx-index.yaml:

apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-a-index
  namespace: web
data:
  index.html: |
    <!doctype html><html><body><h1>Jens</h1></body></html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-b-index
  namespace: web
data:
  index.html: |
    <!doctype html><html><body><h1>Fripont</h1></body></html>
# Maak de ConfigMaps aan
kubectl apply -f nginx-index.yaml
# Maak de Nginx pods aan elk op een aparte node
nginx-pods.yaml:

apiVersion: v1
kind: Pod
metadata:
  name: nginx-a
  namespace: web
  labels:
    app: nginx-a
    owner: JF
spec:
  nodeSelector:
    kubernetes.io/hostname: k3d-namespaces-agent-0   # ← PAS AAN
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
        name: nginx-a-index
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-b
  namespace: web
  labels:
    app: nginx-b
    owner: JF
spec:
  nodeSelector:
    kubernetes.io/hostname: k3d-namespaces-agent-1   # ← PAS AAN
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
        name: nginx-b-index
# Maak de Nginx pods aan
kubectl apply -f nginx-pods.yaml
# Maak de NodePort services aan
nginx-nodeports.yaml:

apiVersion: v1
kind: Service
metadata:
  name: nginx-a-svc
  namespace: web
spec:
  type: NodePort
  selector:
    app: nginx-a
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30500  
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-b-svc
  namespace: web
spec:
  type: NodePort
  selector:
    app: nginx-b
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30600
# Maak de NodePort services aan
kubectl apply -f nginx-nodeports.yaml

a. Node 1
Intern luistert de webserver op poort 80.
Extern is de server toegankelijk via NodePort-poort 30500.
b. Node 2
Intern luistert de webserver op poort 80.
Extern is de server toegankelijk via NodePort-poort 30600.

# Toegang testen tot beide Nginx-webservers via NodePort vanaf je host machine
# Haal het IP-adres van een van de nodes op
kubectl get nodes -o wide
# Test toegang tot Nginx-a
# Ga in de node terminal
kubectl -n web exec -it nginx-a --  sh
curl -sI http://<NODE1_IP>:30500
# Test toegang tot Nginx-b
kubectl -n web exec -it nginx-b --  sh
curl -sI http://<NODE2_IP>:30600

Oefening 14: K8S - Deployments

Opmerking
Les eerst de volledige opgave voor je begint!

Inlevering
-	U dient de oplossing van deze oefening zelf te maken en mee te brengen naar PE en (her)examen. Bewaar uw oefeningen in de cloud.

-	Screenshots instellingen én screenshots resultaat zijn verplicht: in elk screenshot moeten jouw initialen staan tenzij het niet anders kan

o	Screenshots moeten duidelijk zijn!

-	Maak gebruik van Server<je_eigen_initialen> en Client<je_eigen_intialen>.

-	Fraude kan leiden tot 0 op PE/(her)examen.


OPGAVE
1.	Maak een nieuwe cluster aan genaamd dns met 1 control plane en 3 worker nodes.

2.	Maak in deze cluster een deployment van Pihole 2025.07.1 met 5 replicas.

3.	Pas deze deployment nu aan zodat er een rolling update wordt gedaan naar versie 2025.10.1 en vervolgens naar 2025.11.0.

4.	Doe op een imperatieve wijze een rollback naar de vorige versie.

5.	Bewijs dat je deployment aan self-healing kan doen.


OPLOSSING

# Stap 1: Maak cluster aan (of gebruik bestaande cluster)
# Opmerking: Het aanmaken van een nieuwe cluster kan problemen geven.
# Simpelste oplossing: gebruik bestaande cluster (bijv. 'namespaces')

# Als je toch een nieuwe cluster wilt maken:
# k3d cluster create dns --servers 1 --agents 3 --wait

# Gebruik bestaande cluster
kubectl config use-context k3d-namespaces
kubectl get nodes

# Stap 2: Maak Deployment YAML bestand aan
# Bestand: pihole-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: pihole-deployment
  labels:
    app: pihole
    owner: JF
spec:
  replicas: 5
  selector:
    matchLabels:
      app: pihole
  template:
    metadata:
      labels:
        app: pihole
        owner: JF
    spec:
      containers:
      - name: pihole
        image: pihole/pihole:2025.07.1
        ports:
        - containerPort: 80

# Maak deployment aan
kubectl apply -f pihole-deployment.yaml

# Verifieer deployment en pods
kubectl get deployment pihole-deployment
kubectl get pods -l app=pihole

# Wacht tot alle pods Running zijn (kan tot 60s duren)
kubectl wait --for=condition=ready pod -l app=pihole --timeout=120s

# Stap 3a: Rolling update naar versie 2025.10.1
kubectl set image deployment/pihole-deployment pihole=pihole/pihole:2025.10.1 --record

# Monitor de rolling update
kubectl rollout status deployment/pihole-deployment

# Verifieer nieuwe versie
kubectl describe deployment pihole-deployment | grep Image:

# Stap 3b: Rolling update naar versie 2025.11.0
kubectl set image deployment/pihole-deployment pihole=pihole/pihole:2025.11.0

# Monitor de rolling update
kubectl rollout status deployment/pihole-deployment

# Verifieer nieuwe versie
kubectl describe deployment pihole-deployment | grep Image:

# Stap 4: Imperatieve rollback naar vorige versie
# Bekijk rollout history
kubectl rollout history deployment/pihole-deployment

# Doe rollback naar vorige versie (2025.10.1)
kubectl rollout undo deployment/pihole-deployment

# Monitor rollback
kubectl rollout status deployment/pihole-deployment

# Verifieer dat we terug zijn op versie 2025.10.1
kubectl describe deployment pihole-deployment | grep Image:
kubectl get pods -l app=pihole -o wide

# Stap 5: Bewijs self-healing
# Kubernetes deployment zorgt ervoor dat altijd het gewenste aantal replicas (5) actief is

# Verwijder 1 pod
POD_NAME=$(kubectl get pods -l app=pihole --no-headers | head -1 | awk '{print $1}')
kubectl delete pod $POD_NAME

# Wacht even en bekijk pods opnieuw
sleep 3
kubectl get pods -l app=pihole

# Je ziet dat er automatisch een nieuwe pod is aangemaakt om de verwijderde pod te vervangen
# De AGE van de nieuwe pod is jonger dan de andere pods - dit bewijst self-healing!

# SCREENSHOTS VOOR INLEVERING:

# Screenshot 1: Deployment overzicht met JF initialen
kubectl get deployment pihole-deployment -o wide

# Screenshot 2: Alle 5 pods Running
kubectl get pods -l app=pihole -o wide

# Screenshot 3: Rollout history met verschillende versies
kubectl rollout history deployment/pihole-deployment

# Screenshot 4: Huidige image versie na rollback
kubectl describe deployment pihole-deployment | grep -A 3 "Image:"

# Screenshot 5: Self-healing bewijs - pod ages
# Na het verwijderen en herstellen zie je dat 1 pod een jongere AGE heeft
kubectl get pods -l app=pihole

# Screenshot 6: Deployment YAML met JF initialen
cat pihole-deployment.yaml

UITLEG CONCEPTEN:

1. Deployment vs Pod:
   - Pod: Kleinste eenheid in Kubernetes, draait 1 of meer containers
   - Deployment: Beheert een set van identieke pods (replicas)
   - Deployment zorgt voor:
     * Self-healing (vervangt crashed pods)
     * Rolling updates (geleidelijke updates zonder downtime)
     * Rollback (terugkeren naar vorige versie)
     * Scaling (aantal replicas aanpassen)

2. Rolling Update:
   - Update strategie die pods geleidelijk vervangt
   - Standaard: max 25% unavailable, max 25% surge
   - Tijdens update: oude en nieuwe versie draaien tegelijk
   - Geen downtime voor de applicatie

3. Self-Healing:
   - Kubernetes monitort continu de pod status
   - Als een pod crashed of wordt verwijderd:
     * ReplicaSet detecteert dat aantal < gewenste aantal
     * Nieuw pod wordt automatisch aangemaakt
     * Gewenste staat (5 replicas) wordt hersteld

4. Rollback:
   - Kubernetes bewaart rollout history
   - kubectl rollout undo keert terug naar vorige versie
   - Nuttig bij problemen met nieuwe versie

VEELGEMAAKTE FOUTEN:

1. Cluster hangt vast bij aanmaken
   → Oplossing: gebruik bestaande cluster

2. Pods blijven in ContainerCreating
   → Wacht langer, pihole images zijn groot (1+ GB)

3. Rollback lijkt niet te werken
   → Verifieer met: kubectl describe deployment | grep Image

4. Self-healing niet duidelijk
   → Let op AGE kolom, nieuwe pod is jonger dan anderen

Oefening 15: K8S - Storage

Opmerking
Les eerst de volledige opgave voor je begint!

Inlevering
-	U dient de oplossing van deze oefening zelf te maken en mee te brengen naar PE en (her)examen. Bewaar uw oefeningen in de cloud.

-	Screenshots instellingen, screenshots yaml files én screenshots resultaat zijn verplicht: in elk screenshot moeten jouw initialen staan tenzij het niet anders kan

o	Screenshots moeten duidelijk zijn!

-	Maak gebruik van Server<je_eigen_initialen> en Client<je_eigen_intialen>.

-	Fraude kan leiden tot 0 op PE/(her)examen.


OPGAVE
1.	Maak een nieuwe cluster genaamd storage.

2.	Bouw een volledige Wordpress. Zowel de Wordpress deployment als de MariaDB deployment moeten gebruik maken van persistant storage. Doe dit op een declaratieve manier.

3.	Zorg dat je de wordpress site kan bereiken vanop je eigen computer. Bewijs dit door via een browser op je eigen laptop naar de site te surfen.

4.	Maak een Apache pod. Daarnaast maak je ook een ubi10-init pod. Beide pods moeten op een declaratieve manier aangemaakt worden. Zorg dat beide pods dezelfde persistant storage delen.

5.	Maak verschillende files aan op de ubi10-init pod en zorg dat deze ook direct bruikbaar zijn in de webserver zonder dat je ze eerst hebt moeten kopiëren


OPLOSSING

# Stap 1: Maak nieuwe cluster genaamd storage
k3d cluster create storage --servers 1 --agents 2 -p "30080:30080@server:0" --wait

# Verifieer cluster
kubectl get nodes

# Stap 2: WordPress + MariaDB met Persistent Storage

# Bestand: mariadb-pvc.yaml
cat <<EOF > mariadb-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-pvc
  labels:
    owner: JF
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f mariadb-pvc.yaml

# Bestand: wordpress-pvc.yaml
cat <<EOF > wordpress-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
  labels:
    owner: JF
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f wordpress-pvc.yaml

# Bestand: mariadb-deployment.yaml
cat <<EOF > mariadb-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
  labels:
    app: mariadb
    owner: JF
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
        owner: JF
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.6
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword"
        - name: MYSQL_DATABASE
          value: "wordpress"
        - name: MYSQL_USER
          value: "wpuser"
        - name: MYSQL_PASSWORD
          value: "wppassword"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mariadb-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-storage
        persistentVolumeClaim:
          claimName: mariadb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb-service
  labels:
    owner: JF
spec:
  selector:
    app: mariadb
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
EOF

kubectl apply -f mariadb-deployment.yaml

# Wacht tot MariaDB ready is
kubectl wait --for=condition=ready pod -l app=mariadb --timeout=120s

# Bestand: wordpress-deployment.yaml
cat <<EOF > wordpress-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
    owner: JF
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
        owner: JF
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        env:
        - name: WORDPRESS_DB_HOST
          value: "mariadb-service:3306"
        - name: WORDPRESS_DB_USER
          value: "wpuser"
        - name: WORDPRESS_DB_PASSWORD
          value: "wppassword"
        - name: WORDPRESS_DB_NAME
          value: "wordpress"
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
  labels:
    owner: JF
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

kubectl apply -f wordpress-deployment.yaml

# Wacht tot WordPress ready is
kubectl wait --for=condition=ready pod -l app=wordpress --timeout=120s

# Stap 3: Verifieer toegang tot WordPress
kubectl get svc wordpress-service
echo "WordPress bereikbaar op: http://localhost:30080"

# Test met curl
curl -I http://localhost:30080

# Stap 4 & 5: Apache + ubi10-init met gedeelde storage

# Bestand: shared-pvc.yaml
cat <<EOF > shared-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc
  labels:
    owner: JF
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Mi
EOF

kubectl apply -f shared-pvc.yaml

# Bestand: apache-pod.yaml
cat <<EOF > apache-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache-jf
  labels:
    app: apache
    owner: JF
spec:
  containers:
  - name: apache
    image: httpd:2.4-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-storage
      mountPath: /usr/local/apache2/htdocs
  volumes:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: shared-pvc
EOF

kubectl apply -f apache-pod.yaml

# Bestand: ubi10-init-pod.yaml
cat <<EOF > ubi10-init-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ubi10-init-jf
  labels:
    app: ubi10-init
    owner: JF
spec:
  containers:
  - name: ubi10
    image: registry.access.redhat.com/ubi10/ubi-init:latest
    command: ["/sbin/init"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
  volumes:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: shared-pvc
EOF

kubectl apply -f ubi10-init-pod.yaml

# Wacht tot pods ready zijn
kubectl wait --for=condition=ready pod/apache-jf --timeout=60s
kubectl wait --for=condition=ready pod/ubi10-init-jf --timeout=60s

# Stap 5: Maak files aan op ubi10-init pod
# Exec in ubi10-init pod en maak files aan
kubectl exec -it ubi10-init-jf -- sh -c "echo '<h1>JF - Test bestand van ubi10-init</h1>' > /shared/index.html"
kubectl exec -it ubi10-init-jf -- sh -c "echo '<h2>JF - Tweede bestand</h2>' > /shared/test.html"
kubectl exec -it ubi10-init-jf -- sh -c "echo 'JF - Text bestand' > /shared/readme.txt"

# Verifieer dat files bestaan op ubi10-init
kubectl exec ubi10-init-jf -- ls -la /shared

# Verifieer dat dezelfde files beschikbaar zijn in Apache pod
kubectl exec apache-jf -- ls -la /usr/local/apache2/htdocs

# Expose Apache pod via service voor externe toegang
cat <<EOF > apache-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: apache-service
  labels:
    owner: JF
spec:
  type: NodePort
  selector:
    app: apache
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
EOF

kubectl apply -f apache-service.yaml

# Test Apache toegang
curl http://localhost:30081
curl http://localhost:30081/test.html


# SCREENSHOTS VOOR INLEVERING:

# Screenshot 1: Cluster nodes
kubectl get nodes -o wide

# Screenshot 2: PVCs (Persistent Volume Claims)
kubectl get pvc

# Screenshot 3: WordPress deployment en pods
kubectl get deployment,pods -l app=wordpress -o wide
kubectl get deployment,pods -l app=mariadb -o wide

# Screenshot 4: WordPress service en toegang
kubectl get svc wordpress-service
curl -I http://localhost:30080

# Screenshot 5: Apache en ubi10-init pods met gedeelde storage
kubectl get pods apache-jf ubi10-init-jf -o wide

# Screenshot 6: Files op ubi10-init pod
kubectl exec ubi10-init-jf -- ls -la /shared

# Screenshot 7: Dezelfde files op Apache pod
kubectl exec apache-jf -- ls -la /usr/local/apache2/htdocs

# Screenshot 8: Apache service toegang
kubectl get svc apache-service
curl http://localhost:30081

# Screenshot 9: Bewijs WordPress werkt (browser screenshot)
# Open in browser: http://localhost:30080

# Screenshot 10: YAML bestanden met JF initialen
cat mariadb-pvc.yaml
cat wordpress-pvc.yaml
cat shared-pvc.yaml


UITLEG CONCEPTEN:

1. Persistent Storage in Kubernetes:
   - PersistentVolume (PV): Storage resource in cluster
   - PersistentVolumeClaim (PVC): Request voor storage door pod
   - AccessModes:
     * ReadWriteOnce (RWO): 1 node kan lezen/schrijven
     * ReadWriteMany (RWX): Meerdere nodes kunnen lezen/schrijven
     * ReadOnlyMany (ROX): Meerdere nodes kunnen lezen

2. WordPress + MariaDB Setup:
   - MariaDB: Database voor WordPress
   - Environment variables voor DB credentials
   - Services voor communicatie tussen pods
   - Persistent storage voor data en uploads

3. Gedeelde Storage tussen Pods:
   - Zelfde PVC in meerdere pods mounten
   - ReadWriteMany access mode vereist
   - In k3d: local-path provisioner ondersteunt RWX
   - Files op 1 pod zijn direct zichtbaar in andere pod

4. NodePort Service:
   - Exposeert service op statische poort (30000-32767)
   - Toegankelijk via <NodeIP>:<NodePort>
   - Voor k3d: localhost:<NodePort>

5. Volume Mounts:
   - volumeMounts: waar volume in container gemount wordt
   - volumes: definitie van volume (PVC, ConfigMap, etc)
   - mountPath: pad in container


VEELGEMAAKTE FOUTEN:

1. ReadWriteMany niet ondersteund
   → k3d local-path provisioner ondersteunt RWX sinds v1.20+
   → Voor oudere versies: gebruik NFS of andere storage class

2. WordPress kan MariaDB niet bereiken
   → Wacht tot MariaDB pod ready is voor WordPress te deployen
   → Controleer service naam in WORDPRESS_DB_HOST

3. Files niet zichtbaar tussen pods
   → Controleer of zelfde PVC gebruikt wordt
   → Verifieer mount paths in beide pods

4. NodePort niet bereikbaar
   → Zorg dat cluster gemaakt is met -p flag
   → Controleer firewall/security settings

5. Pods blijven in Pending
   → Controleer PVC status: kubectl describe pvc
   → Zorg dat storage class beschikbaar is


################################################################################
# OEFENING 16: VAN PODMAN NAAR KUBERNETES
################################################################################

Oefening 16: Van Podman naar Kubernetes - DEEL 1

OPGAVE:
Maak een WordPress website aan in Kubernetes met persistente opslag.
De site moet bereikbaar zijn op poort 9999 en data moet bewaard blijven 
na het verwijderen van alle resources (inclusief PVCs).

Website naam: websiteJF
Email: je PXL email adres

STAPPEN:

1) Maak een nieuw k3d cluster aan voor WordPress
# Cluster met 1 server (control plane) en 1 agent (worker node)
# Poort 9999 wordt direct gemapped (zoals in opgave gevraagd)
k3d cluster create wordpress-cluster \
  -s 1 \
  -a 1 \
  --port 9999:30999@server:0

# Controleer cluster
kubectl config use-context k3d-wordpress-cluster
kubectl get nodes


2) Maak PersistentVolumes aan met hostPath storage

# Database PersistentVolume
cat <<'EOF' > pvdatabase.jf.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-database-jf
  labels:
    app: wordpress-jf
    owner: JF
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /srv/k8s-jf/mysql
    type: DirectoryOrCreate
EOF

# WordPress PersistentVolume
cat <<'EOF' > pvwordpress.jf.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-wordpress-jf
  labels:
    app: wordpress-jf
    owner: JF
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /srv/k8s-jf/wordpress
    type: DirectoryOrCreate
EOF

kubectl apply -f pvdatabase.jf.yaml
kubectl apply -f pvwordpress.jf.yaml


3) Maak PersistentVolumeClaims aan

# Database PVC (met lege storageClassName en selector voor manual binding)
cat <<'EOF' > pvcdatabase.jf.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-database-jf
  labels:
    owner: JF
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      app: wordpress-jf
EOF

# WordPress PVC
cat <<'EOF' > pvcwordpress.jf.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-wordpress-jf
  labels:
    owner: JF
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  selector:
    matchLabels:
      app: wordpress-jf
EOF

kubectl apply -f pvcdatabase.jf.yaml
kubectl apply -f pvcwordpress.jf.yaml


4) Maak MariaDB Pod en Service

# MariaDB Pod met persistente storage
cat <<'EOF' > poddatabase.jf.yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-jf
  labels:
    app: wordpress-jf
    tier: database
    owner: JF
spec:
  containers:
  - name: mariadb
    image: mariadb:10.11
    ports:
    - containerPort: 3306
    env:
    - name: MARIADB_ROOT_PASSWORD
      value: "rootpassword"
    - name: MARIADB_DATABASE
      value: "wordpress"
    - name: MARIADB_USER
      value: "wpuser"
    - name: MARIADB_PASSWORD
      value: "wppassword"
    volumeMounts:
    - name: mysql-storage
      mountPath: /var/lib/mysql
  volumes:
  - name: mysql-storage
    persistentVolumeClaim:
      claimName: pvc-database-jf
EOF

# Database Service (ClusterIP voor interne communicatie)
cat <<'EOF' > servicedatabase.jf.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-jf
  labels:
    app: wordpress-jf
    tier: database
    owner: JF
spec:
  type: ClusterIP
  selector:
    app: wordpress-jf
    tier: database
  ports:
  - protocol: TCP
    port: 3306
    targetPort: 3306
EOF

kubectl apply -f servicedatabase.jf.yaml
kubectl apply -f poddatabase.jf.yaml


5) Maak WordPress Pod en Service

# WordPress Pod met persistente storage
cat <<'EOF' > podwordpress.jf.yaml
apiVersion: v1
kind: Pod
metadata:
  name: wordpress-jf
  labels:
    app: wordpress-jf
    tier: frontend
    owner: JF
spec:
  containers:
  - name: wordpress
    image: wordpress:latest
    ports:
    - containerPort: 80
    env:
    - name: WORDPRESS_DB_HOST
      value: "mysql-jf:3306"
    - name: WORDPRESS_DB_USER
      value: "wpuser"
    - name: WORDPRESS_DB_PASSWORD
      value: "wppassword"
    - name: WORDPRESS_DB_NAME
      value: "wordpress"
    volumeMounts:
    - name: wordpress-storage
      mountPath: /var/www/html
  volumes:
  - name: wordpress-storage
    persistentVolumeClaim:
      claimName: pvc-wordpress-jf
EOF

# WordPress Service (NodePort voor externe toegang op poort 9999)
cat <<'EOF' > servicewordpress.jf.yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-jf
  labels:
    app: wordpress-jf
    tier: frontend
    owner: JF
spec:
  type: NodePort
  selector:
    app: wordpress-jf
    tier: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30999
EOF

kubectl apply -f servicewordpress.jf.yaml
kubectl apply -f podwordpress.jf.yaml


6) Wacht tot alle pods ready zijn en test de setup
# Wacht op pods
kubectl wait --for=condition=Ready pod/mysql-jf --timeout=120s
kubectl wait --for=condition=Ready pod/wordpress-jf --timeout=120s

# Controleer status
kubectl get pv,pvc,pod,svc

# Test WordPress toegang (vanaf VM)
curl -I http://192.168.112.10:9999

# Vanaf Windows host: open browser en ga naar:
# http://192.168.112.10:9999


7) Configureer WordPress via browser (VANAF WINDOWS HOST)
# Open browser op je Windows laptop en ga naar:
# http://192.168.112.10:9999
#
# WordPress installatie:
# - Taal: Nederlands (of Engels)
# - Site titel: websiteJF
# - Gebruikersnaam: admin
# - Wachtwoord: (sterk wachtwoord)
# - Email: <jouw-pxl-email>@pxl.be
# - Klik "WordPress installeren"
#
# Log in en maak een testpost aan om te verifiëren dat alles werkt


8) Test persistentie door resources te verwijderen en opnieuw aan te maken
# BELANGRIJK: Verwijder in deze volgorde!
# Eerst pods verwijderen
kubectl delete -f poddatabase.jf.yaml
kubectl delete -f podwordpress.jf.yaml

# Dan services verwijderen
kubectl delete -f servicedatabase.jf.yaml
kubectl delete -f servicewordpress.jf.yaml

# Dan PVCs verwijderen (data blijft behouden op PV!)
kubectl delete -f pvcdatabase.jf.yaml
kubectl delete -f pvcwordpress.jf.yaml

# PVs blijven behouden met Retain policy en status wordt "Released"
kubectl get pv

# PROBLEEM: PVs zijn nu "Released" en hebben nog oude claimRef
# OPLOSSING: Verwijder de claimRef uit beide PVs

# Patch database PV om claimRef te verwijderen
kubectl patch pv pv-database-jf -p '{"spec":{"claimRef": null}}'

# Patch wordpress PV om claimRef te verwijderen  
kubectl patch pv pv-wordpress-jf -p '{"spec":{"claimRef": null}}'

# Verifieer dat PVs nu "Available" zijn
kubectl get pv

# Maak alles opnieuw aan in juiste volgorde
# Eerst PVCs (binden opnieuw aan bestaande PVs met data)
kubectl apply -f pvcdatabase.jf.yaml
kubectl apply -f pvcwordpress.jf.yaml

# Wacht even tot PVCs binden
sleep 5
kubectl get pvc

# Dan services
kubectl apply -f servicedatabase.jf.yaml
kubectl apply -f servicewordpress.jf.yaml

# Ten slotte pods
kubectl apply -f poddatabase.jf.yaml
kubectl apply -f podwordpress.jf.yaml

# Wacht tot pods ready zijn
kubectl wait --for=condition=Ready pod/mysql-jf --timeout=120s
kubectl wait --for=condition=Ready pod/wordpress-jf --timeout=120s

# Verifieer dat je website nog steeds bestaat op http://192.168.112.10:9999
# Je WordPress site met alle posts en instellingen moet nog aanwezig zijn!


# SCREENSHOTS VOOR INLEVERING DEEL 1:

echo "=== Screenshot 1: Cluster nodes ==="
kubectl get nodes -o wide

echo "=== Screenshot 2: YAML bestanden met JF initialen ==="
ls -l pv*.jf.yaml pvc*.jf.yaml pod*.jf.yaml service*.jf.yaml

echo "=== Screenshot 3: PersistentVolumes met Retain policy ==="
kubectl get pv -o wide

echo "=== Screenshot 4: PersistentVolumeClaims gebonden aan PVs ==="
kubectl get pvc -o wide

echo "=== Screenshot 5: Database pod en service ==="
kubectl get pod mysql-jf -o wide
kubectl get svc mysql-jf

echo "=== Screenshot 6: WordPress pod en service ==="
kubectl get pod wordpress-jf -o wide
kubectl get svc wordpress-jf

echo "=== Screenshot 7: Alle resources samen ==="
kubectl get pv,pvc,pod,svc

echo "=== Screenshot 8: WordPress toegankelijk via curl ==="
curl -I http://192.168.112.10:9999

echo "=== Screenshot 9: WordPress configuratie (WINDOWS BROWSER) ==="
# Open browser op je WINDOWS laptop: http://192.168.112.10:9999
# Screenshot van WordPress dashboard met websiteJF als titel
# Dit bewijst dat de site bereikbaar is vanaf je Windows host!

echo "=== Screenshot 10: Test na verwijderen resources ==="
# Na stap 8: screenshot dat website nog steeds werkt
# Toon ook kubectl get pv om te zien dat PVs behouden zijn

echo "=== Screenshot 11: Bewijs van persistentie ==="
kubectl describe pv pv-database-jf | grep -A 3 "Status:"
kubectl describe pv pv-wordpress-jf | grep -A 3 "Status:"


BELANGRIJKE CONCEPTEN:

1. PersistentVolume Reclaim Policy:
   - Retain: PV blijft bestaan na verwijderen van PVC (data behouden)
   - Delete: PV wordt verwijderd samen met PVC (data verloren)
   - Recycle: PV wordt hergebruikt na basic cleanup (deprecated)

2. Manual PV/PVC Binding:
   - storageClassName: "" in PVC zorgt voor manual binding
   - selector met matchLabels in PVC matched met labels op PV
   - Dit voorkomt automatische provisioning door default storage class
   - PV moet label "app: wordpress-jf" hebben voor binding te werken

3. hostPath Volumes:
   - Gebruikt directory op de node als storage
   - type: DirectoryOrCreate maakt directory aan als deze niet bestaat
   - Data blijft op node staan, ook na pod deletion
   - Niet geschikt voor productie (node-specific, geen HA)

4. Pod vs Deployment:
   - Deze oefening gebruikt Pods (niet Deployments)
   - Pods worden niet automatisch herstart bij falen
   - Deployment zou meerdere replicas en auto-restart bieden
   - Voor demo/test: Pods zijn voldoende

5. Service Types:
   - ClusterIP (mysql-jf): alleen binnen cluster bereikbaar
   - NodePort (wordpress-jf): bereikbaar van buitenaf via node IP + port


VEELGEMAAKTE FOUTEN:

1. PVCs blijven Pending
   → Zorg dat storageClassName: "" is ingesteld in PVC
   → Controleer of selector matchLabels matched met PV labels
   → PV moet label "app: wordpress-jf" hebben
   → Verify: kubectl describe pvc <naam>

2. Pods kunnen PVC niet claimen
   → PV en PVC moeten zelfde accessModes hebben
   → PV moet genoeg capacity hebben voor PVC request
   → Check: kubectl get pv,pvc -o wide

3. WordPress kan database niet bereiken
   → Wacht tot mysql-jf pod Running is voor wordpress-jf te starten
   → Controleer service naam in WORDPRESS_DB_HOST (moet mysql-jf zijn)
   → Test: kubectl exec wordpress-jf -- ping mysql-jf

4. Data verdwijnt na verwijderen resources
   → Verify persistentVolumeReclaimPolicy: Retain in PV
   → PV status wordt "Released" na PVC deletion (niet "Available")
   → Bij opnieuw binden: PVC selector moet matchen met PV labels
   → Data blijft op /srv/k8s-jf/mysql en /srv/k8s-jf/wordpress

5. NodePort niet bereikbaar van buitenaf (vanaf Windows)
   → k3d cluster moet aangemaakt zijn met -p "9999:30999@server:0"
   → Gebruik VM IP, NIET localhost: http://192.168.112.10:9999
   → Controleer VM firewall: sudo ufw status
   → Test vanaf VM: curl http://192.168.112.10:9999
   → Test vanaf Windows browser: http://192.168.112.10:9999

6. WordPress blijft installation scherm tonen na herstel
   → Dit is normaal als wp-config.php nog niet bestaat
   → Na eerste install wordt config in PV opgeslagen
   → Bij tweede install: config wordt geladen, WordPress werkt direct


TROUBLESHOOTING COMMANDO'S:

# Check pod logs voor errors
kubectl logs mysql-jf
kubectl logs wordpress-jf

# Beschrijf resources voor details
kubectl describe pod mysql-jf
kubectl describe pvc pvc-database-jf
kubectl describe pv pv-database-jf

# Exec in pod voor debugging
kubectl exec -it mysql-jf -- bash
kubectl exec -it wordpress-jf -- bash

# Check welke node gebruikt wordt
kubectl get pods -o wide

# Verifieer data op node (als je SSH toegang hebt)
# ssh naar node en check:
# ls -la /srv/k8s-jf/mysql
# ls -la /srv/k8s-jf/wordpress


################################################################################
# OEFENING 16: VAN PODMAN NAAR KUBERNETES - DEEL 2 & 3
################################################################################

Oefening 16: Van Podman naar Kubernetes - DEEL 2: DRUPAL IN PODMAN

OPGAVE:
Installeer Drupal in een Podman pod met persistente opslag.
De website moet bereikbaar zijn op poort 8080.

Website naam: websiteJF
Email: je PXL email adres
Onderhoudsaccount: voornaam (bijv. Jens) met zelfgekozen wachtwoord
Named volumes: drupal-mysql en drupal-files
BELANGRIJK: Alleen /var/www/html/sites/default/files koppelen!

STAPPEN:

1) Maak named volumes aan voor Drupal
# Database volume
podman volume create drupal-mysql

# Files volume (voor uploads en configuratie)
podman volume create drupal-files

# Verifieer volumes
podman volume ls


2) Maak een Podman pod voor Drupal
# Pod met poort mapping (8080 host → 80 container)
podman pod create \
  --name drupal-pod-jf \
  -p 8080:80


3) Start MariaDB container in de pod
podman run -d \
  --name drupal-mariadb-jf \
  --pod drupal-pod-jf \
  -e MARIADB_ROOT_PASSWORD="rootpass123" \
  -e MARIADB_DATABASE=drupal \
  -e MARIADB_USER=drupal \
  -e MARIADB_PASSWORD="drupalpass123" \
  -v drupal-mysql:/var/lib/mysql:Z \
  docker.io/library/mariadb:11

# Wacht even tot MariaDB klaar is
sleep 10


4) Start Drupal container in de pod
podman run -d \
  --name drupal-web-jf \
  --pod drupal-pod-jf \
  -v drupal-files:/var/www/html/sites/default/files:Z \
  docker.io/library/drupal:10-apache


5) Fix permissies voor Drupal files directory
# Drupal draait als www-data (UID 33)
# Unshare geeft toegang tot host filesystem vanuit rootless podman context
podman unshare chown -R 33:33 \
  $(podman volume inspect drupal-files --format '{{.Mountpoint}}')

podman unshare chmod -R 775 \
  $(podman volume inspect drupal-files --format '{{.Mountpoint}}')


6) Verifieer dat Drupal draait
# Check pod status
podman pod ps

# Check containers in pod
podman ps --pod

# Test toegang
curl -I http://localhost:8080


7) Configureer Drupal via browser
# Vanaf Windows: SSH tunnel opzetten
# Op Windows PowerShell/CMD:
# ssh -L 8081:localhost:8080 student@192.168.112.10
# 
# LET OP: Als je "Permission denied" error krijgt op poort 8080:
# - Poort 8080 is al in gebruik op Windows
# - Gebruik een andere poort zoals 8081, 8082, etc.
# - Pas onderstaande URL aan naar de gekozen poort

# Open browser op Windows en ga naar: http://localhost:8081

# Drupal installatie wizard:
# 1. Kies taal: English (of Nederlands)
# 2. Installatieprofiel: Standard
# 3. Database configuratie:
#    - Database type: MySQL, MariaDB, Percona Server, or equivalent
#    - Database name: drupal
#    - Database username: drupal
#    - Database password: drupalpass123
#    - ADVANCED OPTIONS (klik om uit te klappen):
#      * Host: 127.0.0.1  ← BELANGRIJK: gebruik IP, NIET localhost!
#      * Port: 3306
#
#    LET OP: "localhost" probeert Unix socket te gebruiken en faalt!
#    Gebruik altijd 127.0.0.1 voor TCP/IP verbinding tussen containers.
# 4. Site configuratie:
#    - Site name: websiteJF
#    - Site email: <jouw-studentnummer>@student.pxl.be
#    - Username: Jens (je voornaam)
#    - Password: (kies zelf een sterk wachtwoord)
#    - Email: <jouw-studentnummer>@student.pxl.be
# 5. Klik "Save and continue"

# Maak een test-artikel aan om te verifiëren dat alles werkt


# SCREENSHOTS VOOR INLEVERING DEEL 2:

echo "=== Screenshot 1: Podman volumes ==="
podman volume ls

echo "=== Screenshot 2: Drupal pod ==="
podman pod ps

echo "=== Screenshot 3: Containers in pod ==="
podman ps --pod --filter pod=drupal-pod-jf

echo "=== Screenshot 4: Volume mountpoints ==="
podman volume inspect drupal-mysql --format '{{.Mountpoint}}'
podman volume inspect drupal-files --format '{{.Mountpoint}}'

echo "=== Screenshot 5: Drupal toegankelijk ==="
curl -I http://localhost:8080

echo "=== Screenshot 6: Drupal configuratie (browser) ==="
# Screenshot van Drupal dashboard met websiteJF als site naam


################################################################################
# OEFENING 16: VAN PODMAN NAAR KUBERNETES - DEEL 3 & 4
################################################################################

Oefening 16: Van Podman naar Kubernetes - DEEL 3: KUBERNETES MANIFEST GENEREREN

OPGAVE:
Genereer een Kubernetes manifest uit de Podman pod en pas het aan voor gebruik.

STAPPEN:

1) Genereer Kubernetes YAML uit Podman pod
# Podman kan automatisch een Kubernetes manifest genereren
podman generate kube drupal-pod-jf > drupaljf.yaml

# Bekijk het gegenereerde bestand
cat drupaljf.yaml


2) Analyseer het gegenereerde manifest
# Het gegenereerde bestand bevat:
# - Pod definitie met beide containers (mariadb en drupal)
# - Volume definities (maar nog niet als PVCs!)
# - Environment variables
# - Port mappings

# PROBLEEM: Podman volumes worden als hostPath gegenereerd
# We moeten dit handmatig aanpassen naar PersistentVolumeClaims


3) Maak PersistentVolumeClaims aan voor Kubernetes
cat <<'EOF' > pvc-drupal-mysql.jf.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-drupal-mysql-jf
  labels:
    app: drupal-jf
    owner: JF
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

cat <<'EOF' > pvc-drupal-files.jf.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-drupal-files-jf
  labels:
    app: drupal-jf
    owner: JF
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

# Apply de PVCs (in kubernetes cluster)
kubectl apply -f pvc-drupal-mysql.jf.yaml
kubectl apply -f pvc-drupal-files.jf.yaml


4) Maak een opgeruimde Drupal pod manifest
# Handmatig aangepaste versie met correcte PVCs en labels
cat <<'EOF' > pod-drupal.jf.yaml
apiVersion: v1
kind: Pod
metadata:
  name: drupal-jf
  labels:
    app: drupal-jf
    owner: JF
spec:
  containers:
  - name: mariadb
    image: mariadb:11
    ports:
    - containerPort: 3306
    env:
    - name: MARIADB_ROOT_PASSWORD
      value: "rootpass123"
    - name: MARIADB_DATABASE
      value: drupal
    - name: MARIADB_USER
      value: drupal
    - name: MARIADB_PASSWORD
      value: "drupalpass123"
    volumeMounts:
    - name: mysql-storage
      mountPath: /var/lib/mysql
  
  - name: drupal
    image: drupal:10-apache
    ports:
    - containerPort: 80
    volumeMounts:
    - name: files-storage
      mountPath: /var/www/html/sites/default/files
  
  volumes:
  - name: mysql-storage
    persistentVolumeClaim:
      claimName: pvc-drupal-mysql-jf
  - name: files-storage
    persistentVolumeClaim:
      claimName: pvc-drupal-files-jf
EOF


5) Maak Services aan voor Drupal
# MariaDB service (ClusterIP, intern gebruik)
cat <<'EOF' > service-mariadb.jf.yaml
apiVersion: v1
kind: Service
metadata:
  name: mariadb-jf
  labels:
    app: drupal-jf
    owner: JF
spec:
  type: ClusterIP
  selector:
    app: drupal-jf
  ports:
  - port: 3306
    targetPort: 3306
EOF

# Drupal service (NodePort, externe toegang op poort 8080)
cat <<'EOF' > service-drupal.jf.yaml
apiVersion: v1
kind: Service
metadata:
  name: drupal-jf
  labels:
    app: drupal-jf
    owner: JF
spec:
  type: NodePort
  selector:
    app: drupal-jf
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30808
EOF


6) Deploy Drupal naar Kubernetes (OPTIONEEL - voor testen)
# Let op: dit is optioneel, want we moeten eerst Podman pod verwijderen
# kubectl apply -f pvc-drupal-mysql.jf.yaml
# kubectl apply -f pvc-drupal-files.jf.yaml
# kubectl apply -f service-mariadb.jf.yaml
# kubectl apply -f service-drupal.jf.yaml
# kubectl apply -f pod-drupal.jf.yaml

# Wacht tot pod ready is
# kubectl wait --for=condition=Ready pod/drupal-jf --timeout=120s

# Test toegang
# curl -I http://192.168.112.10:8080


# SCREENSHOTS VOOR INLEVERING DEEL 3:

echo "=== Screenshot 1: Gegenereerd Kubernetes manifest ==="
cat drupaljf.yaml

echo "=== Screenshot 2: Opgeruimde manifest bestanden ==="
ls -l pvc-drupal*.jf.yaml pod-drupal.jf.yaml service*.jf.yaml

echo "=== Screenshot 3: PVCs aangemaakt ==="
kubectl get pvc -l app=drupal-jf

echo "=== Screenshot 4: Drupal pod YAML ==="
cat pod-drupal.jf.yaml


################################################################################
# OEFENING 16: VAN PODMAN NAAR KUBERNETES - DEEL 5 & 6
################################################################################

Oefening 16: Van Podman naar Kubernetes - DEEL 5: CLEANUP & BACKUP

OPGAVE:
Verwijder de Podman pod en maak backup van de manifests.

STAPPEN:

1) Stop en verwijder de Podman pod
# Stop de pod (stopt alle containers in de pod)
podman pod stop drupal-pod-jf

# Verwijder de pod (verwijdert ook alle containers)
podman pod rm drupal-pod-jf

# Verifieer dat pod weg is
podman pod ps

# BELANGRIJK: Volumes blijven bestaan!
podman volume ls


2) Optioneel: Verwijder ook de volumes (als je clean slate wilt)
# LET OP: Dit verwijdert alle Drupal data!
# podman volume rm drupal-mysql drupal-files


3) Maak backup van het originele gegenereerde manifest
# Kopieer drupaljf.yaml naar backup
cp drupaljf.yaml drupaljf.yaml.backup

# Hernoem origineel naar ~ extensie (zoals gevraagd in opgave)
mv drupaljf.yaml drupaljf.yaml~

# Verifieer backup
ls -la drupal*.yaml*


4) De opgeruimde bestanden zijn klaar voor gebruik
# Deze bestanden zijn production-ready:
# - pvc-drupal-mysql.jf.yaml
# - pvc-drupal-files.jf.yaml
# - pod-drupal.jf.yaml
# - service-mariadb.jf.yaml
# - service-drupal.jf.yaml

# Toon alle bestanden
ls -l *drupal*.yaml*


# SCREENSHOTS VOOR INLEVERING DEEL 5:

echo "=== Screenshot 1: Podman pod verwijderd ==="
podman pod ps -a

echo "=== Screenshot 2: Volumes nog aanwezig ==="
podman volume ls

echo "=== Screenshot 3: Backup bestanden ==="
ls -la drupaljf.yaml*

echo "=== Screenshot 4: Alle Drupal manifests ==="
ls -l pvc-drupal*.jf.yaml pod-drupal.jf.yaml service*.jf.yaml


################################################################################
# OEFENING 16: VAN PODMAN NAAR KUBERNETES - DEEL 7: DEPLOY NAAR KUBERNETES
################################################################################

Oefening 16: Van Podman naar Kubernetes - DEEL 7: FINALE DEPLOYMENT

OPGAVE:
Deploy de opgeruimde Drupal manifests naar Kubernetes en test persistentie.

STAPPEN:

1) Zorg dat je in de juiste cluster context bent
# Gebruik de wordpress-cluster
kubectl config use-context k3d-wordpress-cluster
kubectl get nodes


2) Deploy alle Drupal resources naar Kubernetes
# PVCs eerst
kubectl apply -f pvc-drupal-mysql.jf.yaml
kubectl apply -f pvc-drupal-files.jf.yaml

# Dan services
kubectl apply -f service-mariadb.jf.yaml
kubectl apply -f service-drupal.jf.yaml

# Ten slotte de pod
kubectl apply -f pod-drupal.jf.yaml


3) Wacht tot Drupal pod ready is
kubectl wait --for=condition=Ready pod/drupal-jf --timeout=180s

# Check status
kubectl get pod,svc,pvc


4) Configureer Drupal (als nog niet gedaan)
# Open browser: http://192.168.112.10:30808
# (NodePort 30808 is gemapped naar host poort 8080 in opgave)

# Volg dezelfde installatie stappen als bij Podman:
# - Site name: websiteJF
# - Database: drupal / drupal / drupalpass123 @ 127.0.0.1:3306
#   BELANGRIJK: gebruik 127.0.0.1, NIET localhost!
# - Admin account: Jens (je voornaam) + zelfgekozen wachtwoord
# - Email: <jouw-studentnummer>@student.pxl.be


5) Test persistentie (OPTIONEEL)
# Verwijder pod en PVCs
kubectl delete -f pod-drupal.jf.yaml
kubectl delete -f service-drupal.jf.yaml
kubectl delete -f service-mariadb.jf.yaml
kubectl delete -f pvc-drupal-mysql.jf.yaml
kubectl delete -f pvc-drupal-files.jf.yaml

# Maak opnieuw aan
kubectl apply -f pvc-drupal-mysql.jf.yaml
kubectl apply -f pvc-drupal-files.jf.yaml
kubectl apply -f service-mariadb.jf.yaml
kubectl apply -f service-drupal.jf.yaml
kubectl apply -f pod-drupal.jf.yaml

# Wacht en test
kubectl wait --for=condition=Ready pod/drupal-jf --timeout=180s
curl -I http://192.168.112.10:30808


# SCREENSHOTS VOOR INLEVERING DEEL 7:

echo "=== Screenshot 1: Drupal resources in Kubernetes ==="
kubectl get pod,svc,pvc -l app=drupal-jf

echo "=== Screenshot 2: Drupal pod details ==="
kubectl describe pod drupal-jf

echo "=== Screenshot 3: Drupal toegankelijk ==="
curl -I http://192.168.112.10:30808

echo "=== Screenshot 4: Drupal configuratie (browser) ==="
# Open browser: http://192.168.112.10:30808
# Screenshot van Drupal site met websiteJF als naam


SAMENVATTING OEFENING 16:

DEEL 1: WordPress in Kubernetes
✓ Cluster: wordpress-cluster (1 server, 1 agent)
✓ Poort: 9999 → NodePort 30999
✓ PVs met Retain policy op /srv/k8s-jf/
✓ PVCs met selector binding
✓ MariaDB 10.11 pod + WordPress pod
✓ Data blijft behouden na verwijderen resources

DEEL 2: Drupal in Podman
✓ Podman pod: drupal-pod-jf
✓ Named volumes: drupal-mysql, drupal-files
✓ Poort: 8080 (host) → 80 (container)
✓ MariaDB 11 + Drupal 10-apache containers
✓ Permissies gefixed met podman unshare

DEEL 3: Kubernetes manifest genereren
✓ podman generate kube → drupaljf.yaml
✓ PVCs aangemaakt voor persistent storage
✓ Opgeruimde manifests: pod-drupal.jf.yaml + services

DEEL 4: Cleanup
✓ Podman pod verwijderd
✓ Backup: drupaljf.yaml → drupaljf.yaml~
✓ Volumes blijven bestaan

DEEL 5: Kubernetes deployment
✓ Deploy naar k3d cluster
✓ NodePort 30808 voor externe toegang
✓ Test persistentie van data

YOUTUBE VIDEO REQUIREMENTS:
- 2 video's van elk 5 minuten
- Video 1: WordPress workflow (Deel 1)
  * Cluster aanmaken
  * Manifests toepassen
  * Website configureren (websiteJF)
  * Persistentie testen (verwijderen + herstellen)
  
- Video 2: Drupal workflow (Deel 2-5)
  * Podman pod aanmaken
  * Drupal configureren (websiteJF)
  * Kubernetes manifest genereren
  * Cleanup en deployment naar Kubernetes


BELANGRIJKE CONCEPTEN:

1. Podman vs Docker:
   - Podman is rootless (veiliger)
   - Podman pods ≈ Kubernetes pods (multi-container)
   - podman generate kube: native Kubernetes export

2. Podman Volumes:
   - Named volumes voor data persistentie
   - :Z flag voor SELinux context (rootless)
   - podman unshare voor permissie management

3. Podman to Kubernetes:
   - Generated manifest bevat hostPath (niet production-ready)
   - Moet handmatig aangepast naar PVCs
   - Services moeten apart aangemaakt worden

4. Multi-container Pods:
   - Containers delen network namespace (localhost werkt!)
   - Drupal en MariaDB in zelfde pod
   - Geen aparte service nodig voor database binnen pod


VEELGEMAAKTE FOUTEN:

1. Drupal files permissie errors
   → Gebruik podman unshare chown -R 33:33
   → UID 33 = www-data user in Drupal container

2. Drupal kan database niet vinden
   → Beide containers127.0.0.1 (NIET localhost - dat probeert Unix socket!)
   → "localhost" geeft "No such file or directory" error
   → In Kubernetes: gebruik service name (bijv. mariadb-jf) network namespace)
   → In Kubernetes: gebruik service name

3. Generated manifest werkt niet in Kubernetes
   → hostPath volumes moeten vervangen door PVCs
   → Services ontbreken (moeten apart gemaakt worden)
   → Labels en selectors moeten consistent zijn

4. NodePort 30808 niet bereikbaar
   → Cluster moet aangemaakt zijn met juiste port mapping
   → Of gebruik LoadBalancer/Ingress (buiten scope)

5. Wrong volume mount in Drupal
   → ALLEEN /var/www/html/sites/default/files mounten
   → NIET hele /var/www/html (breekt Drupal core files)


TROUBLESHOOTING COMMANDO'S:

# Podman debugging
podman pod logs drupal-pod-jf
podman logs drupal-mariadb-jf
podman logs drupal-web-jf
podman exec -it drupal-web-jf bash

# Kubernetes debugging
kubectl logs drupal-jf -c mariadb
kubectl logs drupal-jf -c drupal
kubectl exec -it drupal-jf -c drupal -- bash
kubectl describe pod drupal-jf

# Volume inspection
podman volume inspect drupal-mysql
podman volume inspect drupal-files
kubectl describe pvc pvc-drupal-mysql-jf
