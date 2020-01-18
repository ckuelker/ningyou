---
title: Ningyou DEVELOPMENT
author: Christian Külker
date: 2020-01-16
---

# Change Ningyou Version (ningyou_project_version)

  * changes `"VERSION" => "x.y.z"` in file `Makefile.PL`
  * chanage return value in sub `get_project_version` in file
    `lib/Deploy/Ningyou/Util.pm` like so:
    `sub get_project_version { return '0.1.2'; }`

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





