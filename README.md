---
title: Ningyou README
author: Christian Külker
date: 2019-12-22
readme-version: 0.1.2
ningyou-version: 0.1.0
---

# Abstract

__Ningyou__ handles software, directory, link and file deployment in a
deterministic way.  On request it can produce scripts for update tasks.

![Github license](https://img.shields.io/github/license/ckuelker/ningyou.svg)
![Github issues](https://img.shields.io/github/issues/ckuelker/ningyou.svg?style=popout-square)
![Github code size in bytes](https://img.shields.io/github/languages/code-size/ckuelker/ningyou.svg)
![Git repo size](https://img.shields.io/github/repo-size/ckuelker/ningyou.svg)
![Last commit](https://img.shields.io/github/last-commit/ckuelker/ningyou.svg)

# Features

* Debian package deployment
* Git repository deploy support
* [`CPAN`] module deploy support
* Simple configuration files
* [`Template::Toolkit`] language support in configuration files
* Deployment of directories, files, links
* Deployment of directory content via `rsync`

# WARNING

This software is in ALPHA state, not tested and contains many bugs. You are
encouraged to help and report them. However be aware, that this software is
intended to run as `root` and as such it can and probably will DAMAGE your
system. You may experience the LOSS OF DATA. You are using the software at your
own risk!

# Introduction

Deploy frameworks are usually one of two kinds: deterministic or object
orientated. The feature of object oriented frameworks is that dependencies can
be inherited. The drawback is often that it is very hard to predict the outcome
and correctness of the deployment.

__Ningyou__ tries to merge the best out of this two worlds: a) it is group
oriented and dependency based with an easy configuration similar to existing
tools. It produces exactly the same actions from the same configuration on the
same machine architecture. Say, it is predictable. On top of it __Ningyou__ can
provide from this a shell script that you can use on a similar second machine
without __Ningyou__, or just look at it to understand what will be done in a
predictable way.

# Documentation

* [README.md](README.md) - this document
* [INSTALL.md](INSTALL.md) - simple installation and setup
* [USAGE.md](USAGE.md) - basic usage
* [MANUAL.md](MANUAL.md) - advanced installation, setup, usage, development

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


[`CPAN`]:  https://www.cpan.org/
[`Template::Toolkit`]: https://metacpan.org/pod/Template::Toolkit
