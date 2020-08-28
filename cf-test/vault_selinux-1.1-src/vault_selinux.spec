# vim: sw=4:ts=4:et


%define relabel_files() \
restorecon -R /usr/sbin/vault; \
restorecon -R /etc/vault.d; \
restorecon -R /opt/vault; \
restorecon -R /var/log/vault; \

%define selinux_policyver 3.13.1-266

Name:   vault_selinux
Version:	1.1
Release:	1%{?dist}
Summary:	SELinux policy module for vault

Group:	System Environment/Base		
License:	MPLv2
# This is an example. You will need to change it.
URL:		https://www.vaultproject.io/
Source0:	vault.pp
Source1:	vault.if
Source2:	vault_selinux.8


Requires: policycoreutils, libselinux-utils
Requires(post): selinux-policy-base >= %{selinux_policyver}, policycoreutils
Requires(postun): policycoreutils
BuildArch: noarch

%description
This package installs and sets up the  SELinux policy security module for vault.

%install
install -d %{buildroot}%{_datadir}/selinux/packages
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/selinux/packages
install -d %{buildroot}%{_datadir}/selinux/devel/include/contrib
install -m 644 %{SOURCE1} %{buildroot}%{_datadir}/selinux/devel/include/contrib/
install -d %{buildroot}%{_mandir}/man8/
install -m 644 %{SOURCE2} %{buildroot}%{_mandir}/man8/vault_selinux.8
install -d %{buildroot}/etc/selinux/targeted/contexts/users/


%post
semodule -n -i %{_datadir}/selinux/packages/vault.pp
if /usr/sbin/selinuxenabled ; then
    /usr/sbin/load_policy
    %relabel_files

fi;
exit 0

%postun
if [ $1 -eq 0 ]; then
    semodule -n -r vault
    if /usr/sbin/selinuxenabled ; then
       /usr/sbin/load_policy
       %relabel_files

    fi;
fi;
exit 0

%files
%attr(0600,root,root) %{_datadir}/selinux/packages/vault.pp
%{_datadir}/selinux/devel/include/contrib/vault.if
%{_mandir}/man8/vault_selinux.8.*


%changelog
* Fri Aug 28 2020 Christian Frichot <cfrichot@hashicorp.com> 1.1-1
- Update to allow for outbound comms

* Wed Aug 12 2020 Christian Frichot <cfrichot@hashicorp.com> 1.0-1
- Initial version

