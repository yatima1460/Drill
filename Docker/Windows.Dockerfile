#escape=`
FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Install Chocolatey
RUN powershell -Command `
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')); `
        choco feature disable --name showDownloadProgress

RUN choco install -y dub

RUN choco install -y dmd