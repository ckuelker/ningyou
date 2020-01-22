---
title: CHANGES
author: Christian Külker
date: 2020-01-21
---

# Changes

## 0.1.3

* add dependency libfile-sharedir-install-perl to bin/ningyou-install
* [class] section now in bootstrapped configuration
* fix rsync usage of --group --owner
* support rsync --exclude option
* add bootstrap info to INSTALL.md
* improve error message for pakage provider
* bootrap --with-main-configuration will now add host.ini and .gitconfig
* host.ini will have correct owner/group set

## 0.1.2

* new font deployment support
* new script version 0.1.2: print now more information in the header: script
  version, date, time
* source as new DEVELOMENT.md document
* fixes some error messages

## 0.1.1

* for some actions print version and date on startup (Deploy::Ningyou)
* VERSION not longer handled by dzil (all)
* new error hint 'attrvalue' (Deploy::Ningyou::Util)
* fix some error messages (Deploy::Ningyou::Provider::File)
* + dependency libconfig-inifiles-perl (checksum action) (bin/ningyou-install)
* checksum explanation (ningyou, MANUAL.md, MANUAL.pdf, USAGE.md)

## 0.1.0

### Ningyou

* Initial commit of rewrite

### README.md

* 0.1.2: add links to CPAN, Template::Toolkit
* 0.1.2: fix last commit badge
* 0.1.1: add version number for README.md and Ningyou
* 0.1.1: add badge for: license, code size, repo size, last commit
* 0.1.0: initial version for Ningyou 0.1.0

### MANUAL.md

* 0.1.1: add version number for MANUAL.md and Ningyou
* 0.1.0: initial version for Ningyou 0.1.0

