Basic server
============

This role describes a basic server, and contains all best practices with regards to locales, default packages, shell and editor config

Requirements
------------

None.

Role Variables
--------------

Default variables are defined in defaults/ and vars/ directory :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `default_locale` | en_US.UTF-8 | Default locale |
| `rootpromptcolor` | red | Prompt color root user |
| `userpromptcolor` | green | Prompt color default user |
| `promptsite_tag` | NULL | Site information to display in prompt |
| `promptsite_sep` | "#" | Prompt separator |
| `users_groups` | [] | List of groups to create |
| `user_default_shell`| /bin/bash | Default user shell |
| `yum_disabled_plugins` | ['fastestmirror'] | Disable yum plugins |
| `yum_enabled_plugins` | [] | Enable yum plugins |
| `users` | [] | List of users to create |
| `users.sshkeys` | [] | List of sshkeys of users to deploy |
| `extra_packages` | [] | Array of packages to install on the system |
| `extra_remove_packages` | [] | Array of packages to remove on the system |
| `install_epel` | true | Enable EPEL repository on RedHat family |
| `root_password` |  | Set root password in crypt form with following command **mkpasswd --method=sha-512** |
| `install_sudoers` | true | Deploy sudoers |
| `manage_locales` | true | Manage locales
| `manage_firewalld` | true | Ensure firewalld is installed, enabled and started |
| `disable_network_manager` | false | Ensure NetworkManager is removed and systemd-netowrkd is enabled and started |
| `historytime_format` | '%Y/%m/%d - %H:%M:%S ' | Configure default history time format
| `manage_hostname` | true | Update /etc/hosts by adding entry with default IP address |
| `remove_loopback_hostname_entry` | true | Remove 127.0.0.1 entry associated to host name fqdn (i.e 127.0.0.1.*hostname.fqdn)  |
| `sudo_lines`   | [] | Array of sudo lines to deploy on the server |
| `copy_admin_scripts` | false | Deploy powerfull admin scripts |
| `service_disabled` | [] | List to service to stopped and disabled at boot |
| `main_interface` | ansible_default_ipv4.interface | Default main interface | | `update_all_packages` | false | Upgrade all installed packages |

DNS options :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `dns_search` | [] | Array of search domain |
| `dns_servers` | ['8.8.8.8'] | Array of dns servers |
| `dns_domain` | NULL | Dns domain of the server |

SSH options :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `ssh_enable_passwd_auth` | yes | Enable/disable password authentication |
| `ssh_enable_root_login` | yes | Enable/disable root login  |
| `ssh_use_dns` | yes | Enable/disable DNS resolution |

ATOP options :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `atop_enable` | yes | Enable/disable atop installation |
| `atop_interval` | 600 | Log interval |
| `atop_retention_day` | 21 | Logs retention |

Logrotate options :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `logrotate_enable` | true | Enable/disable logrotate installation and specific configuration |
| `logrotate_compress` | true | Enable/disable logrotate compression |
| `logrotate_period` | weekly | Set default logrotate period (daily, weekly, monthly) |
| `logrotate_rotate` | 4 | Period retention before removing log files |

/etc/hosts entry :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `hosts_entry.ip` |  | Host IP address |
| `hosts_entry.fqdn` | | Host Fully Qualify Domain Name |
| `hosts_entry.hostname` | | Host name |

Sample playbooks
---------------

Deploy configuration with epel-release installed as an extra package

```yml
- hosts: all
  roles:
    - role: basicserver
      extra_packages:
        - epel-release
```

Prompt configuration
--------------------

The following variable allows you to alter the default prompt (light green) :

* `rootpromptcolor: red`

You can choose the prompt color among ANSI colors : black, red, green, yellow, blue, magenta, cyan, white

Install additionnal packages
----------------------------

The following variable allows you to install additionnal packages :

* `extra_packages`

It takes a list of packages to install
