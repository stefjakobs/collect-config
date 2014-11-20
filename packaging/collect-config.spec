%define           colldir /opt/config/

Name:             collect-config
Version:          1.13
Release:          1%{?dist}
Summary:          Configuration collector

Group:            System/Management
License:          GPL-3.0
Source0:          %{name}-%{version}.tar.gz
BuildRoot:        %{_tmppath}/%{name}-%{version}-build
BuildArch:        noarch

Requires:         bash > 4.0
Requires:         rcs bc
%if 0%{?suse_version}
Recommends:       cron
%endif


%description
Copy all config files to a fix location and check them in.


%prep
%setup -q


%build


%install
install -Dm644 %{name}.conf %{buildroot}/%{_sysconfdir}/%{name}.conf
install -Dm755 %{name}.sh   %{buildroot}/%{_bindir}/%{name}.sh
install -d %{buildroot}/%{_sysconfdir}/cron.daily
ln -sf %{_bindir}/%{name}.sh %{buildroot}/%{_sysconfdir}/cron.daily/%{name}
install -Dm644 Makefile %{buildroot}%{colldir}/Makefile
install -Dm644 %{name}.sh.1 %{buildroot}/%{_mandir}/man1/%{name}.sh.1


%clean
%__rm -rf "%{buildroot}"


%files
%defattr(-,root,root,-)
%doc README
%doc %{_mandir}/man1/%{name}.sh.1*
%{_bindir}/%{name}.sh
%config(noreplace) %{_sysconfdir}/%{name}.conf
%{_sysconfdir}/cron.daily/%{name}
%attr(0750,root,root) %dir %{colldir}
%{colldir}/Makefile

%changelog
* Thu Oct 1 2012 Stefan Jakobs <projects AT localside.net> - 1.7
- Initial version
