# NAME

Deploy::Ningyou::Manual - Manual

# VERSION

version 0.1.0

# WARNING

    //=======================================================================\\
    || This software is in ALPHA state, not tested and contains many bugs.   ||
    || You are encouraged to help and report them. However be aware, that    ||
    || this software is intended to run as root and as such it can DAMAGE    ||
    || your system. You may experience the LOSS OF DATA. You are using the   ||
    || software at your own risk! Please read also this document.            ||
    \\=======================================================================//

![https://img.shields.io/github/issues/ckuelker/ningyou.svg?style=popout-square](https://img.shields.io/github/issues/ckuelker/ningyou.svg?style=popout-square)

# INTRODUCTION

Deploy frameworks are usually one of two kinds: deterministic or object
orientated. The feature of object oriented frameworks is that dependencies can
be inherited. The drawback is often that it is very hard to predict the outcome
and correctness of the deployment.

**Ningyou** tries to merge the best out of this two worlds: a) it is group
oriented and dependency based with an easy configuration similar to existing
tools. It produces exactly the same actions from the same configuration
on the same machine. Say, it is predictable. On top of it **Ningyou** can
provide from this a shell script that you can use on a similar second machine
without **Ningyou**, or just look at it to understand what will be done in a
predictable way.

# Features

- Simple configuration files
- Optional Template::Toolkit language support in configuration files
- CPAN deploy support
- Git  deploy support

# INSTALLATION

## Installation from a release

Get the source code for **Ningyou** via git or a tar archive. This example uses
a tar archive.  Replace <VERSION> with the latest version.

    tar xvzf Deploy-Ningyou-<VERSION>.tar.gz
    cd Deploy-Ningyou
    perl Makefile.PL
    make test
    make install

## Installation from git

Get the source code from git.

    git clone https://github.com/ckuelker/ningyou.git

You can choose to install it via `Makefile.PL` or `dist.ini`. In
case you prefer `Makefile.PL` see section above.

Install `Dist::Zilla` if it not already installed. For Debian do:

    aptitude install libdist-zilla-perl

Enter the directory, make tests and install **Ningyou**

    cd ningyou
    dzil test
    dzil install

This will install the `ningyou` executable and libraries into default
locations.

# BOOTSTRAP

To kick start the installation configuration **Ningyou** can help you. As root
execute

    cd /srv
    ningyou bootstrap

This will install basic configuration in `/srv/ningyou` for your current
operating system as well create the file `~/.ningyou.ini` in your home
directory that points to the new **Ningyou** configuration. This will also
create a git repository in `/srv/ningyou`. You should configure this directory
to point to a remote location.

If you already have one host deployed by **Ningyou** you can reuse the
repository (named `ningyou.git` for example).

    cd /srv/
    mkdir ningyou                                                # optional
    git clone GIT_URL_TO_YOUR_NINGYOU_REPOSITORY
    cd ningyou
    ningyou --main-configuration-only bootstrap

The above command only creates `$HOME/.ningyou.ini` pointing to
`/srv/ningyou`.

After this you have to create the host configuration in `/srv/ningyou`
according to your first host configuration by adding a new host file unless you
clone hosts with the same name. (example:
`/srv/ningyou/myhost.mydomain.tld.ini`)

A simple host.ini may look like this:

    [version]
    project=0.1.0
    configuration=0.1.0
    file=0.1.0

    [global]
    vim=1

    [debian-gnu-linux-9.8-stretch-amd64-x86_64]

    [w1.c8i.org]

The above file assumes you have a **Ningyou** vim _module_. If you have not
create one with `cd /srv/ningyou/global/modules;ningyou module vim` or add the
following file to let **Ningyou** install the vim package.

    mkdir -p /srv/ningyou/global/modules/vim/{files,manifests}
    echo "[package:vim]" > /srv/ningyou/global/modules/vim/manifests/vim.ini
    echo "ensure=latest" >>/srv/ningyou/global/modules/vim/manifests/vim.ini

## Examples

    ningyou bootstrap                           : initialize all

    ningyou bootstrap --main-configuration-only : initialize ~/.ningyou.ini only

    cd /srv/ningyou/global/modules/
    ningyou module vim                          : create vim module boiler plate

# CONFIGURATION

You need a configuration for the current operating system. The description of
the current installed OS is derived from `facter's` `lsbdistdescription`. The
description of `Debian GNU/Linux 8.11 (jessie)` gives
`debian-gnu-linux-8.11-jessie` as OS description.

In case you host is called `host.domain.tld`, you have 3 classes for
configuration: `[global]`, `host.domain.tld` and for example
`debian-gnu-linux-9.8-stretch-amd64-x86_64`. This sections can be found in
`host.domain.tld.ini` and correspond to the directories with the same name.

OS specific configuration should go into
`debian-gnu-linux-9.8-stretch-amd64-x86_64` and host specific should go into
`host.domain.tld`.

Under each directories there is - or you need to create - a `modules`
directory where **Ningyou** _modules_ live. Each _module_ has its own
directory, for example the `zsh` _module_ directory tree might look like
this:

    zsh
    ├── files
    │   └── zshrc
    └── manifests
        └── zsh.ini

The `zsh.ini` is the module configuration. This configuration can control
weather and what files from the `files` directory are distributed. This is the
`zsh` content:

    [version:zsh]
    ; Ningyou Project version - changed by Ningyou
    project=0.1.0
    ; Ningyou Configuration Space version - changed by Ningyou
    configuration=0.1.0
    ; version of this file - change this when you update the file
    file=0.1.0

    [package:zsh]
    ensure=latest

    [file:/root/.zshrc]
    source=ningyou:///global/modules/zsh/files/zshrc
    mode=640
    owner=root
    group=root
    ensure=latest
    require=global:package:zsh
    checksum=80afb055812d5449dc3c25e317f52654

As of **Ningyou** 0.1.0 the `[version:zsh]` section is optional. If present it
will be printed if the `--verbose` flag is used. The section `[package:zsh]`
together with the attribute `ensure` and its value `latest` makes sure that
the latest `zsh` package is installed.

The next section `[file:/root/.zshrc]` makes sure that the `zsh`
configuration `global/modules/zsh/files/zshrc` will be copied to `/root/.zsh`.

# DEPENDENCIES

## Development Dependencies

    libdevel-nytprof-perl

## Build Dependencies

    make
    libdist-zilla-perl

## Runtime Dependencies

    libapt-pkg-perl              # comment=Deploy::Ningyou::Provider::Package
    libmodule-pluggable-perl
    perl-doc
    facter                       # maybe replaced by Sys::Facter in the future
    libfile-touch-perl
    libtemplate-perl
    libconfig-ini-perl
    libcapture-tiny-perl
    libfile-dircompare-perl
    libgraph-perl
    liblist-compare-perl

### Dependencies for Provider cpan

    cpanminus

## Runtime Recommendations

    libmodule-runtime-perl (libmodule-pluggable-perl)
    libmodule-require-perl (libmodule-pluggable-perl)

# SYNTAX

**Ningyou** can be invoked from the command line

    ningyou [OPTIONS] <ARGUMENT>  [<SCOPE>]

    OPTIONS:
      ningyou [--main-configuration-only] bootstrap
      ningyou [--help|--man|--version]
      ningyou [--verbose] list|show|script|apply [<SCOPE>]
      ningyou module <NAME>

    SCOPE:
       |all|<NAME_OF_MODULE>|<NAME_OF_MODULE> <NAME_OF_MODULE> ...

## Examples

    ningyou --version                   : print Ningyou project version number

    ningyou help                        : show brief help message (same as --help)
    ningyou --help                      : show brief help message
    ningyou man                         : show man page (same as --man)
    ningyou --man                       : show man page

    ningyou bootstrap                   : install in `cwd` and ~/.ningyou.ini
                                          intialize ~/.ningou.ini and worktree

    ningyou list                        : list enabled modules

    ningyou status                      : print brief information about modules
    ningyou --verbose status            : print information about all section
    ningyou --verbose status global:zsh : print information about zsh module only

    ningyou script                      : print bash script
    ningyou --verbose script            : print bash script with explanations

    ningyou apply                       : execute commands (see ningyou script)
    ningyou --verbose apply             : execute commands with expanations

# CONFIGURATION EXPLAINED

The configuration space resides in the _worktree_. The _worktree_ is set when
executing `ningyou bootstrap` and it's value is recorded in `~/.ningyou.ini`.

    ; +-------------------------------------------------------------------------+
    ; | ningyou.ini => ~/.ningyou.ini                                           |
    ; |                                                                         |
    ; | Main configuration for Ningyou                                          |
    ; |                                                                         |
    ; | Version: 0.1.0 (Change also inline: [version] file=)                    |
    ; |                                                                         |
    ; | Changes:                                                                |
    ; |                                                                         |
    ; | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                          |
    ; |     - initial release                                                   |
    ; |                                                                         |
    ; +-------------------------------------------------------------------------+
    ;
    [version]
    ; Ningyou Project version - changed by Ningyou
    project=0.1.0
    ; Ningyou Configuration Space version - changed by Ningyou
    configuration=0.1.0
    ; version of this file - change this when you update the file
    file=0.1.0

    [global]
        worktree=/srv/ningyou

    [system]
        fqhn=h.example.com

    [os]
        distribution=debian-gnu-linux-9.8-stretch-amd64-x86_64
        ; package manager cache time to live, default 3600 = 1h
        pm_cache_ttl=3600

If the _worktree_ lives for example in `/srv/ningyou` than a minimal working
tree with a **global:zsh** _module_ on the host `h.example.com` with a Debian
**Stretch** operating system would be:

    /srv/ningyou
       ├── debian-gnu-linux-9.8-stretch-amd64-x86_64
       ├── global
       │   └── modules
       │       └── zsh
       │           ├── files
       │           │   └── zshrc
       │           └── manifests
       │               └── zsh.ini
       ├── h.example.com
       └── h.example.com.ini

The directories `h.example.com`, `debian-gnu-linux-9.8-stretch-amd64-x86_64`
and `global/modules` are created by `ningyou bootstrap`.

The configuration for the **global:zsh** _module_ can be created like this:

    cd /srv/ningyou/global/modules
    ningyou module zsh

This will create the files and directories: `zsh/files` and
`zsh/manifests/zsh.ini`.

The content of `zsh.ini` looks like this:

    ; +-------------------------------------------------------------------------+
    ; | modules/zsh/manifests/zsh.ini                                           |
    ; |                                                                         |
    ; | Configuration for a Ningyou module.                                     |
    ; |                                                                         |
    ; | Version: 0.1.0 (Change also inline: [version] file=)                    |
    ; |                                                                         |
    ; | Changes:                                                                |
    ; |                                                                         |
    ; | 0.1.0 2019-04-19 Christian Kuelker <c@c8i.org>                          |
    ; |     - initial release                                                   |
    ; |                                                                         |
    ; +-------------------------------------------------------------------------+
    ;
    [version:zsh]
    ; Ningyou Project version - changed by Ningyou
    project=0.1.0
    ; Ningyou Configuration Space version - changed by Ningyou
    configuration=0.1.0
    ; version of this file - change this when you update the file
    file=0.1.0

    [nop:zsh]
    ; the 'nop' provider provides a 'no operation' - nothing
    ; can be used to check (via debug) if configuration section is actually used
    debug=NOP zsh

    ;[package:zsh]

To enable this _module_ configuration aka to install the `zsh` package: fist
uncomment `;[package:zsh]` like so `[package:zsh]` and add the line to the
`[global]` section of `h.example.com.ini`.

    zsh=1

Comment out the `[nop:zsh]` and `debug=NOP zsh`

The `h.example.com.ini` configuration is simple:

    ; +-------------------------------------------------------------------------+
    ; | w1.c8i.ini                                                              |
    ; |                                                                         |
    ; | Configuration for one host                                              |
    ; |                                                                         |
    ; | Version: 0.1.1 (Change also inline: [version] file=)                    |
    ; |                                                                         |
    ; | Changes:                                                                |
    ; |                                                                         |
    ; | 0.1.1 2019-04-19 Christian Kuelker <c@c8i.org>                          |
    ; |     - enable global:zsh                                                 |
    ; |                                                                         |
    ; | 0.1.0 2019-04-11 Christian Kuelker <c@c8i.org>                          |
    ; |     - initial release                                                   |
    ; |                                                                         |
    ; +-------------------------------------------------------------------------+
    [version]
    ; Ningyou Project version - changed by Ningyou
    project=0.1.0
    ; Ningyou Configuration Space version - changed by Ningyou
    configuration=0.1.0
    ; version of this file - change this when you update the file
    file=0.1.1

    [global]
    ; distribution independent modules
    ; active modules = 1
    ; inactive modules = 0
        zsh=1
    [debian-gnu-linux-9.8-stretch-amd64-x86_64]
    ; distribution debian-gnu-linux-9.8-stretch-amd64-x86_64 dependent modules

    [h.example.com]
    ; host h.example.com dependent modules

As `zsh` needs a configuration file `~/.zshrc` you need to add a `zsh`
configuration file to `/srv/ningyou/gobal/modules/zsh/files/` and a _file
provider_ to the configuration. The complete configuration looks like this:

    ; +-------------------------------------------------------------------------+
    ; | modules/zsh/manifests/zsh.ini                                           |
    ; |                                                                         |
    ; | Configuration for a Ningyou module.                                     |
    ; |                                                                         |
    ; | Version: 0.1.1 (Change also inline: [version] file=)                    |
    ; |                                                                         |
    ; | Changes:                                                                |
    ; |                                                                         |
    ; | 0.1.1 2019-04-19 Christian Kuelker <c@c8i.org>                          |
    ; |     - add package:zsh                                                   |
    ; |     - add file:/root/.zshrc                                             |
    ; |                                                                         |
    ; | 0.1.0 2019-04-19 Christian Kuelker <c@c8i.org>                          |
    ; |     - initial release                                                   |
    ; |                                                                         |
    ; +-------------------------------------------------------------------------+
    ;
    [version:zsh]
    ; Ningyou Project version - changed by Ningyou
    project=0.1.0
    ; Ningyou Configuration Space version - changed by Ningyou
    configuration=0.1.0
    ; version of this file - change this when you update the file
    file=0.1.1

    ;[nop:zsh]
    ; the 'nop' provider provides a 'no operation' - nothing
    ; can be used to check (via debug) if configuration section is actually used
    ;debug=NOP zsh

    [package:zsh]
    [file:/root/.zshrc]
        source=ningyou:///global/modules/zsh/files/zshrc
        mode=640
        owner=root
        group=root
        ensure=latest
        require=global:package:zsh
        checksum=80afb055812d5449dc3c25e317f52653

# ADVANCED CONFIGURATION

## Package

The main attribute for packages is **ensure=**, with either the value 'present'
or 'latest', while 'missing' is also possible. Additional attributes 'version'
and 'source' are possible and mutual exclusive. For 'version' the packages of
that version needs to be in the package repository. The same functionality can
be archived by 'ensure=present' if the latest version is the desired version.
If the latest version is not the desired version and if this package is not in
the repository it can be provided by the 'source' attribute. However this is
not recommended and should be considered a method of last resort. The reason is
that the installation is not done via `aptitude` it is via `dpkg` that do not
check for dependencies nor records its installation.

## Cpan

    [% TAR='Dist-Zilla-Plugin-PerlTidy-0.21.tar.gz' %]

    [cpan:Dist::Zilla::Plugin::PerlTidy]
    source=ningyou:///global/modules/devel/files/[% TAR %]
    ensure=latest
    require=global:package:libpath-iterator-rule-perl
    environment=/srv/env/perl
    download=https://cpan.metacpan.org/authors/id/F/FA/FAYLAND/[% TAR %]

This will download the source from the address provided with the 'download'
attribute, if not already downloaded, and store it under the path provided
by the attribute 'source'. If 'source' by it self is a URL it will be
downloaded and installed each time and not stored.

    perl-5.24.1
    ├── bin
    ├── lib
    │   ├── i486-linux-gnu-thread-multi
    │   └── perl5
    │       ├── Dist
    │       │   └── Zilla
    │       │       ├── App
    │       │       │   └── Command
    │       │       │       └── perltidy.pm
    │       │       └── Plugin
    │       │           └── PerlTidy.pm
    │       └── x86_64-linux-gnu-thread-multi
    │           ├── auto
    │           │   └── Dist
    │           │       └── Zilla
    │           │           └── Plugin
    │           │               └── PerlTidy
    │           └── perllocal.pod
    └── man
        └── man3
            ├── Dist::Zilla::App::Command::perltidy.3pm
            └── Dist::Zilla::Plugin::PerlTidy.3pm

The 'source' attribute can be a **Ningyou** URL, module name, distribution file,
local file path, HTTP URL or git repository URL. The following will work as
expected:

    source=Plack                                                                 1)a)
    source=Plack/Request.pm                                                      1)a)
    source=MIYAGAWA/Plack-1.0000.tar.gz                                          1)b)
    source=/path/to/Plack-1.0000.tar.gz                                          2)b)
    source=ningyou://global/modules/NINGYOU_MODULE/file/Plack-1.0000.tar.gz      2)b)
    source=ningyou://~/Plack-1.0000.tar.gz                                       2)b)
    source=http://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/Plack-0.9990.tar.gz 1)b)
    source=git://github.com/plack/Plack.git                                      3)b)

    1) will be downloaded from CPAN.
    2) will be fetched from local file system. The 'download' attribut can be used
       to store the archive at the source place
    3) will be cloned from git
    a) will install the latest version and update current version if
       'ensure=latest' otherwise not
    b) will install the latest version and update current version even if
       'ensure=present'

Additionally, you can use the notation using "~" and "@" to specify version for
a given module. "~" specifies the version requirement in the CPAN::Meta::Spec
format, while "@" pins the exact version, and is a shortcut for "~"==
VERSION"".

    source=Plack~1.0000                 # 1.0000 or later
    source=Plack~">= 1.0000, < 2.0000"  # latest of 1.xxxx
    source=Plack@0.9990                 # specific version. same as Plack~"== 0.9990"

The version query including specific version or range will be sent to MetaCPAN
to search for previous releases. The query will search for BackPAN archives by
default, unless you specify "--dev" option, in which case, archived versions
will be filtered out.

For a git repository, you can specify a branch, tag, or commit SHA to build.
The default is "master"

    source=git://github.com/plack/Plack.git@1.0000        # tag
    source=git://github.com/plack/Plack.git@devel         # branch

In case the latest module is wanted use this configuration:

    [cpan:Dist::Zilla::Plugin::PerlTidy]
    source=Dist::Zilla::Plugin::PerlTidy
    ensure=latest

In case the specific version is wanted:

    [cpan:Dist::Zilla::Plugin::PerlTidy]
    source=Dist::Zilla::Plugin::PerlTidy@0.20
    ensure=present

However sometimes the specific version is not possible to fetch, in this case:

    [cpan:Dist::Zilla::Plugin::PerlTidy]
    source=ningyou:///global/modules/devel/files/Dist-Zilla-Plugin-PerlTidy-0.20.tar.gz
    ensure=present
    download=https://cpan.metacpan.org/authors/id/B/BI/BINARY/Dist-Zilla-Plugin-PerlTidy-0.20.tar.gz

Limitation: When changing the 'source' and 'download' to newer versions while
'ensure=present' remains, **Ningyou** will not update the package, because one
old version is still present. If you want to update to a specific version you
have to define specific 'source' and 'download' and set 'ensure=latest', this
will update the package to the version specified in the source file, but not
higher, even though there might be a newer version on CPAN.

If 'ensure=missing' the CPAN module will be uninstalled. This works only
for some sources. For files it do not work. The following works:

    [cpan:Dist::Zilla::Plugin::PerlTidy]
    source=Dist::Zilla::Plugin::PerlTidy
    ensure=missing

Make sure that your environment sets the `PERL_LOCAL_LIB_ROOT` variable.

### Non Standard Perl Locations

It is possible to give an 'environment' attribute. The environment specified in
this file will be sourced in before installation, update or remove. By this
more than one Perl distribution can be managed.

    environment=/srv/env/perl-5.24.1

The file  `/srv/env/perl-5.24.1` contains:

    path_add_before(){
      if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
          path=($1 $path)
      fi
    }
    DIR=/srv/perl-5.24.1
    for d in bin  lib  man; do
       if [ ! -d $DIR/$d ]; then mkdir -p $DIR/$d; fi
    done

    PL=lib/perl5
    if [ ! -d $DIR/$PL ]; then mkdir -p $DIR/$PL; fi

    PV=lib/i486-linux-gnu-thread-multi
    if [ ! -d $DIR/$PV ]; then mkdir -p $DIR/$PV; fi

    export PERL_MB_OPT="--install_base $DIR"
    export PERL_MM_OPT="INSTALL_BASE=$DIR"
    export PERL5LIB="$DIR/$PL:$DIR/$PV:$PERL5LIB"
    path_add_before $DIR/bin
    export PERL_LOCAL_LIB_ROOT=$DIR

# PROVIDER

This section describes the module configuration space for each _provider_.
This information is needed if you would write your own _module_ configuration
or change existing.

## Cpan

    SECTION
        [cpan:PERL_MODULE]

    MANDATORY ATTRIBUTES
        ensure=latest|present|missing
        source=PATH_TO_TAR_ARCHIVE|...

    OPTIONAL ATTRIBUTES
        download=URL
        environment=<PATH_TO_SOURCE_IN_ENVIRONMENT>
        require=CLASS:PROVIDER:DESTINATION

## Directory

    SECTION
        [directory:/path/to/directory]

    MANDATORY ATTRIBUTES
        ensure=present|missing|purged

    OPTIONALLY ATTRIBUTES
        owner=USER                    REM:default root
        group=GROUP                   REM:default root
        mode=0755|755                 REM:default 0700
        require=CLASS:PROVIDER:DESTINATION

WARNING: The 'ensure' _attribute_ with the value 'purged' removes the directory
recursively. You have been warned.

## File

    SECTION
        [file:/path/to/file]

    MANDATORY ATTRIBUTES
        ensure=latest|present|missing  REM:for latest checksum is mandatory

    OPTIONALLY ATTRIBUTES
        REM:if source do not exists an empty file will be created
        source=/tmp/FILE                                       - absolute
        source=ningyou://zshrc                                 - module
        source=ningyou:///global/modules/zsh/files/zshrc       - worktree
        source=~/.zshrc                                        - home
        owner=USER                    REM:default root
        group=GROUP                   REM:default root
        mode=0644|644                 REM:default 0600
        require=CLASS:PROVIDER:DESTINATION
        checksum=md5                     REM:for checksum source and latest
                                               is mandatory

## Git

The check for unclean repositories will not trigger on unchecked files on
purpose: adding files to non managed git repositories is possible.

    SECTION
        [git:/path/to/directory]

    MANDATORY ATTRIBUTES
        source=git repository location
        ensure=present|latest|missing

    OPTIONALLY ATTRIBUTES
        comment=test
        group=GROUP                   REM:default root (recursive)
        mode=0750|750                 REM:default 0750 dir only
        owner=USER                    REM:default root (recursive)
        require=CLASS:PROVIDER:DESTINATION

## Link

     SECTION
         [link:/path/to/link]

     MANDATORY ATTRIBUTES
         type=symbolic|hard            REM:default symbolic
         ensure=present|missing        REM:default present
         source=path/to/(file|directory)

    OPTIONALLY ATTRIBUTES
         comment=text
         require=CLASS:PROVIDER:DESTINATION

## Nop

    SECTION
        [nop:<MODULE>]

    MANDATORY ATTRIBUTES
        debug=<MESSAGE> | define a debug message

## Package

    SECTION
        [package:PACKAGE_NAME]

    MANDATORY ATTRIBUTES
        ensure=present|missing|latest        REM:default present

    OPTIONALLY ATTRIBUTES
        source=path/to/package
        require=CLASS:PROVIDER:DESTINATION

## Rsync

    SECTION
        [rsync:/path/to/directory]

    MANDATORY ATTRIBUTES
        source=/path/to/DIRECTORY

    OPTIONALLY ATTRIBUTES
        comment=some text about rsync
        dry=1
        group=GROUP                   REM:default Ningyou group
        itemize=1
        mode=0755|755                 REM:default from system
        owner=USER                    REM:default Ningyou user
        purge=1
        require=global:package:vim
        require=CLASS:PROVIDER:DESTINATION

## Version

    SECTION
         [version:<MODULE>]     | provider head

     MANDATORY ATTRIBUTES
         project=<NUMBER>       | project version number handled by Ningyou
         configuration=<NUMBER> | condiguration version number handled by Ningyou
         file=><NUMBER>         | file version number handled by user

## LIMITATIONS

- As of now **Ningyou** only supports git repositories for its working tree and do
not interact via git with its working tree. There is the git provider for
Ningyou. There are no experiences to use it for working tree itself.
- The amount of classes are limited to 3: global, hostname, distribution
- Users and home directories are not handled as meta data in **Ningyou**, but as
a workaround you can have this feature on a per module basis with
Template::Toolkit.
- While most changes are applied in the first invocation of `ningyou`, there are
corner cases in which a configuration triggers other actions in a second run.
Ideas are welcome.

# POSSIBLE FUTURE IMPROVEMENTS

- Add classes to fqhn.ini (host \[class\] desktop=1)
- Write Provider::Tar

# DEVELOPMENT

## Profiling

The New York Times profiler is an easy start to understand the bottle necks of
**Ningyou**.

    aptitude install libdevel-nytprof-perl>
    mkdir /tmp/pf
    cd /tmp/pf
    NINGYOU_DEBUG=/tmp/ningyou.debug perl -d:NYTProf ningyou --verbose apply
    BROWSER=firefox nytprofhtml --open
    firefox /tmp/pf/nytprof/index.html

# MORE INFORMATION ABOUT GNU GENERAL PUBLIC LICENSE

    This software is copyright (C) 2013 by Christian Külker
    This software is copyright (C) 2014 by Christian Külker
    This software is copyright (C) 2019 by Christian Külker

This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2.

This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details.

You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc., 59
    Temple Place, Suite 330, Boston, MA 02111-1307 USA

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

# AUTHOR

Christian Külker <c@c8i.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2019 by Christian Külker.

This is free software, licensed under:

    The GNU General Public License, Version 2, June 1991
