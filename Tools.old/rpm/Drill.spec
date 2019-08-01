%define name Drill
%define version 100
%define unmangled_version 100
%define release 1

Summary: yadda yadda
Name: %{name}
Version: %{version}
Release: %{release}
Source0: %{name}-%{unmangled_version}.tar.gz
License: GPL-2.0
Group: Utility
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Prefix: %{_prefix}
BuildArch: x86_64
Vendor: myself and I <email@someplace.com>
Url: https://github.com/yatima1460/Drill

%description
- At least 1 thread per mount point
- Use as much RAM as possible for caching stuff
- Try to avoid "black hole folders" using a regex based blocklist in which the crawler will never come out and never scan useful files (`node_modules`,`Windows`,etc)
- **Intended for desktop users**, no obscure Linux files and system files scans
- Use priority lists to first scan important folders.
- Betting on the future: slowly being optimized for SSDs/M.2 or fast RAID arrays
                      

%prep
%setup -n %{name}-%{unmangled_version}

%build
python gtk_spec.py build

%install
python gtk_spec.py install -O1 --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES

%clean
rm -rf $RPM_BUILD_ROOT

%files -f INSTALLED_FILES
%defattr(-,root,root)
