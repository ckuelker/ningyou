---
title: Ningyou INSTALL
author: Christian Külker
date: 2020-01-23
version: 0.1.4
---

# Abstract

There are different types of installation methods. This document describes only
__one__ simple method. For other methods, please refer to
[MANUAL.md](MANUAL.md).

# Installing A Ningyou Release On A Fresh Installed OS

See the `WARNING` message in [README.md](README.md) if you have data to loose.

## Download The Ningyou Release

    wget https://github.com/ckuelker/ningyou/archive/v0.1.4.tar.gz
    tar xvzf v0.1.4.tar.gz

## Installing Dependencies And Ningyou

Use the system administrator account, usually `root`, for the following.

    ningyou-0.1.4/bin/ningyou-install

Depending on the local Perl configuration it will install in `/usr/local`.

# Configuring Ningyou For The First Time

Use the system administrator account, usually `root`, for the following.

    cd /srv
    ningyou bootstrap

This will create the file `~/.ningyou.ini`, `~/.gitconfig` (if not present) and
a git repository `/srv/deploy`, if not already there. Or specify the
repository, if you do not like the default name `deploy`:

    ningyou bootstrap /path/to/git/repository

The same applies if the directory should be at a different location

    cd
    ningyou bootstrap /srv/deploy

The recommended method is to use a __dedicated__ git repository for the deploy
configuration managed by a USER and not by root:

    cd
    mkdir -p /srv/deploy
    chown USER.GROUP /srv/deploy
    su - USER
    cd /srv
    git clone user@server:deploy.git
    exit
    ningyou --main-configuration-only bootstrap /srv/deploy

This will print

~~~
About to bootstrap Ningyou to [/srv/deploy]
Using configuration file name [/root/.ningyou.ini]
Created configuration file [/root/.ningyou.ini]
Applied bootstrap
~~~

Consider swapping the ningyou configuration for the USER (so that booth are
using the same ningyou configuration/ worktree):

    mv /root/.ningyou.ini /home/USER
    ln -s /home/USER/.ningyou.ini /root


To understand other options on how to install __Ningyou__, please refer
to [MANUAL.md](MANUAL.md). On how to go from here, see [USAGE.md](USAGE.md)
for further reading.

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

# Copyright and License

This software is Copyright (c) 2013, 2014, 2019, 2020 by Christian Külker.

This is free software, licensed under:

    The GNU General Public License, Version 2, June 19

