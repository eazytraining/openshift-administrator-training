Basic server
============

This role manage user and sudoers file on linux servers.

Requirements
------------

None.

Role Variables
--------------

Default variables are defined in defaults/ and vars/ directory :

 * **Users** configuration :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `users_groups` | [] | List of groups to create |
| `user_default_shell`| /bin/bash | Default user shell |
| `users` | [] | List of users to create |
| `users.state` | present | Ensure user are `absent` or `present` on system |
| `users.login` | **mandatory** | User login name |
| `users.comment` |  | User comment / mail |
| `users.group` | `users.login` | User default group. Default is same as login name |
| `users.groups` |  | User additionnal groups |
| `users.opt_groups` |  | User optional groups only append to user group list if exists |
| `users.shell` |  | User shell |
| `users.sshkeys` | [] | List of user SSH Keys to deploy |
| `users.sshkeys_revoke` | [] | List of user SSH Keys to revoke |

 * **Users groups** configuration :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `users_groups` | [] | List of groups to create |
| `users_groups.state` | present | Ensure group are `absent` or `present` on system |
| `users_groups.name` | **mandatory** | Group name |

 * **Sudoers** configuration :

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| `sudoers` | {} | Dict of sudo configuration to deploy on the server |
| `sudoers.key` |  | Name of sudoers configuration file in _/etc/sudoers.d/_ directory |
| `sudoers.state` | present | Ensure sudoers are `absent` or `present` on system |
| `sudoers.lines` | [] | Array of sudo configuration to deploy on the server |


Sample playbooks
---------------

Create users and groups

```yaml
- hosts: all
  vars:
    lookup_ldapkey_url: "ldaps://directory.vitry.intranet/ou=users,dc=lab,dc=lan?sshPublicKey?sub?(&(!(pwdAccountLockedTime=000001010000Z))(uid=%s))"\
    lookup_ldapkey_binddn: "cn=admin,dc=lab,dc=lan"
    lookup_ldapkey_bindpw: "password"
  roles:
    - role: basic-user
      users_groups:
        - name: exploit
      users:
        - name: jekas
          groups: exploit
          sshkeys:
            - "{{ lookup('ldapkey', 'jekas') }}"
```

Create Groups
------------

```yaml
users_groups:
  - name: exploit
    state: present # default
```

Create Users
--------------

You can ask the script to create a list of users for your applications

```yaml
users:
  - name: centreon
    sshkey:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDg6eXbe6l6PLmjOpm9/4CRAMsg78JYKcxijw7YdMWcF1GD5n0mwjiY1ebd/yWWXaL3HM5vlc3NEsowO6dWU/1EqilQbfsxlSnTckUrHW1VlaJOGGeK5W3CewiJ/For663vks9Wxgnv3QqaWG74Yt6WxO9b16Le2S0hqpW7py3WsHSz06UhXsYbXYnv+5+INxYvESYBiqp37byymIVUY+9PQ6rMYorMZDGs+VJYhJCPuCJ7lqpbGBXVB74CWdqkHKzMSPYzmyBDaZtKY7hGaxUF7FRcqVqeEA2nfprcRufLf5xiOzo3tOwQiLtFWUcjSF0Emm6uKAW2igSavCH3b4AV centreon@centreon.boass.lan
```

`authorized_keys` is not mandatory, if present, you should give it a list of SSH keys that should be enabled for the user


Create Sudoers
--------------

You can ask the script to create a list of sudoers file in _/etc/sudoers.d/_ to define user privileges escalation :

```yaml
sudoers:
  default:
    state: absent
  exploit:
    state: present
    lines:
      - "%exploit ALL=(ALL) NOPASSWD: ALL"
  centreon:
    state: present
    lines:
      - "centreon ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins-ssh/check_bind_stats"
      - "centreon ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins-ssh/check_mysql_health"
```


SSH Key LDAP lookups
--------------------

This role adds a new lookup plugin called `ldapkey`, you can use it to lookup SSH keys by login from the Lab LDAP.
In order to use this feature, you need to install `python-ldap` on the machine running Ansible
Anywhere in your playbook, you can use :

```yaml
{{ lookup('ldapkey', 'login') }}
```


Or you can use it in tasks

```yaml
- authorized_key: user=charlie key="{{ item }}"
  with_ldapkey:
    - mabes
    - rogon
```

### Configuration (optional)

By default, it will fetch keys from `directory.vitry.intranet`. If this server isn't accessible to you, of if you want to change some parameters, you can define the URL yourself :

```yaml
    vars:
        lookup_ldapkey_url: ldaps://ldap.prod.vitry.intranet/
```

The `lookup_ldapkey_url` takes a RFC4516 LDAP URL.

You may also override the search filter, base DN, scope, or return attribute

```yaml
vars:
    lookup_ldapkey_url: "ldaps://directory.vitry.intranet/ou=users,dc=lab,dc=lan?sshPublicKey?sub?(&(!(pwdAccountLockedTime=000001010000Z))(uid=%s))"\
    lookup_ldapkey_binddn: "cn=admin,dc=lab,dc=lan"
    lookup_ldapkey_bindpw: "password"
```

`%s` in the search filter will be replaced by the lookup key
