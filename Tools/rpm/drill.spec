Summary: Search files without indexing, but clever crawling
Name: Drill
Version: 2.8
Release: 1%{?dist}
Source0: %{name}-%{version}.tar.gz
License: GPLv2
Group: Utility/Tools

Requires(post): info
Requires(preun): info

%description 
Search files without indexing, but clever crawling:
- At least 1 thread per mount point
- Use as much RAM as possible for caching stuff
- Try to avoid "black hole folders" using a regex based blocklist in which the crawler will never come out and never scan useful files (`node_modules`,`Windows`,etc)
- **Intended for desktop users**, no obscure Linux files and system files scans
- Use priority lists to first scan important folders.
- Betting on the future: slowly being optimized for SSDs/M.2 or fast RAID arrays

%prep
%setup -q

%build
%configure
make %{?_smp_mflags}

%install
%make_install
%find_lang %{name}
rm -f %{buildroot}/%{_infodir}/dir

%post
/sbin/install-info %{_infodir}/%{name}.info %{_infodir}/dir || :

%preun
if [ $1 = 0] ; then
/sbin/install-info --delete %{_infodir}/%{name}.info %{_infodir}/dir || :
fi

%files -f %{name}.lang
%doc AUTHORS ChangeLog COPYING NEWS README THANKS TODO
%{_mandir}/man1/hello.1.gz
%{_infodir}/%{name}.info.gz
%{_bindir}/hello

%changelog
* Tue Sep 06 2011 The Coon of Ty <Ty@coon.org> 2.8-1
- Initial version of the package
ORG-LIST-END-MARKER