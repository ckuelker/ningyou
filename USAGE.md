---
title: Ningyou Usage
author: Christian Külker
date: 2020-01-05
version: 0.1.1
---

# Abstract

This document describes __one__ simple usage case to get started with
__Ningyou__. To see the full range of usage, please read
[MANUAL.md](MANUAL.md), section __Usage__.

# Usage

## Add A Ningyou Module

Assuming the `worktree` is `/srv/deploy` and the `vim` Debian packages (`vim`
and `vim-runtime`) should be added to the system and this Debian packages
should be updated as soon as a new package is available. (`ensure=latest`).

~~~
cd /srv/deploy/global/modules
ningyou module vim
~~~

This will print some lines

~~~
setting up module [vim]
we are in cwd [/srv/deploy/global/modules]
the current working directory is OK
create module [vim] ...
make directory [vim] ...
[PASS] mkdir -p vim
make directory [vim/files] ...
[PASS] mkdir -p vim/files
make directory [vim/manifests] ...
[PASS] mkdir -p vim/manifests
created file [vim/manifests/vim.ini], please edit
~~~

As the last line suggest, change the file `vim/manifests/vim.ini`: (comments
are omitted)

~~~
[version:vim]
project=0.1.0
configuration=0.1.0
file=0.1.0

[package:vim]
ensure=latest

[package:vim-runtime]
ensure=latest
~~~

After this test the status is:

~~~
root@h:/srv/deploy/global/modules# ningyou status
# Ningyou v0.1.0 at h.exmaple.com with /srv/deploy/h.example.com.ini
# Status modules(s) all in /srv/deploy
class:module                                                      enabled status
================================================================================
global:ningyou                                                    [YES]   [DONE]
global:vim                                                        [ NO]   [TODO]
~~~

This means the configuration is `OK`, but the `vim` module is not __enabled__
as the column says `[ NO]`.  Enable it by adding `vim=1` to the `[global]`
section of the host configuration `/srv/deploy/h.example.com.ini` like so:
(comments omitted)

~~~
[global]
ningyou=1
vim=1
~~~

Run status again:

~~~
root@h:/srv/deploy# ningyou status
# Ningyou v0.1.0 at h.example.com with /srv/deploy/h.example.com.ini
# Status modules(s) all in /srv/deploy
class:module                                                      enabled status
================================================================================
global:ningyou                                                    [YES]   [DONE]
global:vim                                                        [YES]   [TODO]
~~~

Now the output is `enabled [YES]` and `status [TODO]`. To change the status
the configuration need to be __applied__.

To understand what and how it will be applied `ningyou script` gives the
answer.

~~~
#!/bin/bash
# +---------------------------------------------------------------------------+
# | Ningyou script                                                            |
# |                                                                           |
# | This script was created with the Ningyou script action                    |
# |                                                                           |
# | Date: 2019-07-15                                                          |
# |                                                                           |
# +---------------------------------------------------------------------------+
#
# Ningyou project version: 0.1.0
# Ningyou script version:  0.1.0
# Worktree:                /srv/deploy
# Configuration:           /srv/deploy/h.example.com.ini
# Command Line (approx):   /usr/local/bin/ningyou  script all
#
# Script commands for w2.c8i.org:
aptitude --assume-yes install vim-runtime
aptitude --assume-yes install vim
~~~

From this it is obvious what __Ningyou__ will do. It is now possible to
copy and run this script by itself, or let __Ningyou__ __apply__ it.

To __apply__ the configuration and install the software now: execute `ningyou
apply`.

~~~
root@h:/srv/deploy# ningyou apply
Reading package lists...
Building dependency tree...
Reading state information...
Reading extended state information...
Initializing package states...
Writing extended state information...
Building tag database...
The following NEW packages will be installed:
  vim-runtime
0 packages upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 0 B/5,775 kB of archives. After unpacking 30.3 MB will be used.
Writing extended state information...
Selecting previously unselected package vim-runtime.
(Reading database ... 313256 files and directories currently installed.)
Preparing to unpack .../vim-runtime_2%3a8.1.0875-5_all.deb ...
Adding 'diversion of /usr/share/vim/vim81/doc/help.txt to
/usr/share/vim/vim81/doc/help.txt.vim-tiny by vim-runtime'
Adding 'diversion of /usr/share/vim/vim81/doc/tags to
/usr/share/vim/vim81/doc/tags.vim-tiny by vim-runtime'
Unpacking vim-runtime (2:8.1.0875-5) ...
Setting up vim-runtime (2:8.1.0875-5) ...
Processing triggers for man-db (2.8.5-2) ...
Reading package lists...
Building dependency tree...
Reading state information...
Reading extended state information...
Initializing package states...
Writing extended state information...
Building tag database...
Reading package lists...
Building dependency tree...
Reading state information...
Reading extended state information...
Initializing package states...
Writing extended state information...
Building tag database...
The following NEW packages will be installed:
  vim
0 packages upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 0 B/1,280 kB of archives. After unpacking 2,867 kB will be used.
Writing extended state information...
Selecting previously unselected package vim.
(Reading database ... 315051 files and directories currently installed.)
Preparing to unpack .../vim_2%3a8.1.0875-5_amd64.deb ...
Unpacking vim (2:8.1.0875-5) ...
Setting up vim (2:8.1.0875-5) ...
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/vim (vim) in auto mode
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/vimdiff (vimdiff) in auto mode
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/rvim (rvim) in auto mode
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/rview (rview) in auto mode
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/vi (vi) in auto mode
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/view (view) in auto mode
update-alternatives: using /usr/bin/vim.basic to provide /usr/bin/ex (ex) in auto mode
Reading package lists...
Building dependency tree...
Reading state information...
Reading extended state information...
Initializing package states...
Writing extended state information...
Building tag database...
~~~

This has installed vim (vim + vim-runtime).

When new `vim` packages are available `ningyou apply` will update the packages.
This can be done by hand every now and then or copy
`cron.daily/ningyou-apply-daily` to `/etc/cron.daily`.

Test this as `root` with

    run-parts -v /etc/cron.daily

Have a look at `/var/log/ningyou-apply-daily.log`, the content should be
similar like:

~~~
# Not updating package manager cache
--- [ global:version:vim ] ------------------------------------------------------------
  configuration: 0.1.0
  file         : 0.1.0
  project      : 0.1.0
# nothing to apply
~~~

## Update A Checksum

Given the file `/srv/deploy/client/modules/default/manifest/default.ini` with
the content:

~~~
[file:/root/.screenrc]
source=/srv/deploy/client/modules/default/files/screenrc
checksum=0658744c8cee2b7ba6728dc7696abcdd
owner=root
group=root
mode=640
ensure=latest
~~~

Then execute:

~~~
cd /srv/deploy/client/modules/default/files
ningyou checksum screenrc
~~~

This will update the checksum of the corresponding section of the manifest

~~~
# Ningyou 0.1.0 2020-01-05T13:04:52
WARNING: this command changes the configuration. It depends on
         Config::IniFiles to write the configuration back.
         While this module is quite smart and preserves order
         and comments, it is not bullet prove. It might
         produce invalid configuration. For example it will
         merge attributes of duplicated sections. Make a backup
         or commit to git before using this experimental
         command.
found the following section(s):
- section [file:/root/.screenrc]
  before [0658744c8cee2b7ba6728dc7696abcdd]
  after [0658744c8cee2b7ba6728dc7696abcdb]
updated [1] attribute(s)
~~~

# DISCLAIMER OF WARRANTY

    BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR
    THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
    OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
    PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
    OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
    MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO
    THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE
    SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
    REPAIR, OR CORRECTION.

    IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL
    ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE
    THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE LIABLE TO YOU FOR
    DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
    DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING
    BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES
    SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE
    WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN
    ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.



# Author

Christian Külker <c@c8i.org>

# Copyright And License

This software is Copyright (c) 2013, 2014, 2019 by Christian Külker.

This is free software, licensed under:

    The GNU General Public License, Version 2, June 1991



