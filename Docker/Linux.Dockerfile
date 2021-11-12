FROM ubuntu:18.04

# Install prerequisites
RUN apt-get update && apt-get install --no-install-recommends -y  curl wget p7zip-full gcc libgtk-3-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Customizable DMD version
ARG DMD_VERSION=2.098.0

# Install D compiler from website
RUN wget -c "http://downloads.dlang.org/releases/2.x/$DMD_VERSION/dmd.$DMD_VERSION.linux.tar.xz"
RUN 7z x -aos "dmd.$DMD_VERSION.linux.tar.xz" && 7z x -aos "dmd.$DMD_VERSION.linux.tar"
RUN chmod +x /dmd2/linux/bin64/dub && chmod +x /dmd2/linux/bin64/dmd

ENV PATH="/dmd2/linux/bin64:${PATH}"
