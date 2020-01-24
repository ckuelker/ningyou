---
title: Ningyou DEVELOPMENT
author: Christian Külker
date: 2020-01-24
---

# Change Ningyou Version (ningyou_project_version)

  * `lib/Deploy/Ningyou/Env.pm`:
    change `our $NINGYOU = 'x.y.z'; # Ningyou version`

  * `Makefile.PL`: change `"VERSION" => "x.y.z"`

  * `lib/Deploy/Ningyou/Util.pm`: change return value in the subroutine
     `sub get_project_version { return 'x.y.z'; }`

  * `README.md`: change version in meta data

  * `INSTALL.md`: change version at multiple places

# Use Ningyou Version (ningyou_project_version)

    use Moose;
    with qw(Deploy::Ningyou::Util);
    my $v = $s->get_project_version;

# How To See Debug Messages for Only One Module?

terminal 0:

    export NINGYOU_DEBUG=/tmp/n.log
    ningyou script

terminal 1:

    tail -f /tmp/n.log|grep Deploy::Ningyou::Provider::Font





