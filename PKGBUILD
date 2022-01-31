# Maintainer: Yatima Santamorena <yatima at santamorena dot me>
pkgname=('drill-search-cli' 'drill-search-gtk')
pkgbase=drill-search
pkgver=local
pkgrel=1
pkgdesc="Search files without indexing, but clever crawling"
arch=('x86_64')
url="https://drill.software"
license=('GPL2')
makedepends=('dmd' 'dub' 'gtk3')


pkgver() {
  git rev-parse --short HEAD
}


build() {

  echo SRCDIR: $srcdir
  echo PKGDIR: $pkgdir
  echo PKGBASE: $pkgbase

  echo "[CLEAN]"
  dub clean 

  echo "[BUILD CLI]"
  dub build -b release -c CLI --force --parallel --verbose --arch="$CARCH"
  echo "CLI version compiled"
  
  echo "[BUILD GTK]"
  dub build -b release -c GTK --force --parallel --verbose --arch="$CARCH"
  echo "GTK version compiled"
}

package_drill-search-cli() {
  pkgdesc+=" (CLI version)"
  depends=('bash')

  cd "Build/Drill-CLI-linux-$CARCH-release"

  echo "[STRIP CLI SYMBOLS]"
  install -d "$pkgdir/"{opt/$pkgname,usr/bin}

  echo "[INSTALL CLI ASSETS]"
  cp -r Assets "$pkgdir/opt/$pkgname"

  echo "[INSTALL CLI OPT]"
  install -Dm755 "$pkgname" -t "$pkgdir/opt/$pkgname"
  
  echo "[INSTALL CLI USR BIN REDIRECT]"
  echo "/opt/$pkgname/$pkgname" "\$@" > "$pkgdir/usr/bin/$pkgname"
  chmod +x "$pkgdir/usr/bin/$pkgname"

  echo "CLI version packaged"
}

package_drill-search-gtk() {

  pkgdesc+=" (GTK version)"
  depends=('gtk3' 'xdg-utils')

  cd "Build/Drill-GTK-linux-$CARCH-release"

  echo "[STRIP GTK SYMBOLS]"
  install -d "$pkgdir/"{opt/$pkgname,usr/bin}

  echo "[INSTALL GTK ASSETS]"
  cp -r Assets "$pkgdir/opt/$pkgname"

  echo "[INSTALL GTK OPT]"
  install -Dm755 "$pkgname" -t "$pkgdir/opt/$pkgname"

  echo "[INSTALL GTK BIN REDIRECT]"
  echo "#!/bin/bash" > "$pkgdir/usr/bin/$pkgname"
  echo "/opt/$pkgname/$pkgname" "\$@" >> "$pkgdir/usr/bin/$pkgname"
  chmod +x "$pkgdir/usr/bin/$pkgname"

  echo "[INSTALL GTK ICON]"
  install -Dm644 Assets/icon.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/$pkgname.svg"

  echo "[INSTALL GTK .DESKTOP]"
  install -Dm644 "Assets/$pkgname.desktop" -t "$pkgdir/usr/share/applications"

  echo "GTK version packaged"
}


check()
{
  cd "Build/Drill-CLI-linux-$CARCH-release"
  ./drill-search-cli --help
}
