package Ningyou::Manual
our $VERSION = '0.0.2';

1;
__END__

=pod

=head1 NAME

Ningyou::Manual

=head1 INSTALLATION

Use the usual Perl ways to install. For example:

    tar xvzf Ningyou-0.0.1.tar.gz
    cd Ningyou
    perl Makefile.PL
    make

As root

    make install

=head1 USAGE

If you have a basic configuraton (for example from the previous
section) then you just need to execute:

 ningyou show

=head1 MOTIVATION

Why you should use Ningyou? That is hard to tell. However I will try to
summarize why I use Ningyou inside this section. And maybe it is also good for
you.

I tried out some deployment frameworks so far. And basically I encounterd two
different flavours. 1) deterministic tools - which do exactly the same all the
time, like shell scripts. And 2) object orientated tools which defines
dependencies and which do not behave deterministically.

While the first is easy to understand how and what it do and what result to
expect, it will get a nightmare for complex installations. On the otherhand the
second is by far more easy to handle in big scenarious. However it is sometimes
impossible to predict what is the outcome and if then the order of installation
is randomly you end up in situations which are hard to debug if you have not
huge statistical data.

Ningyou tries to merge the best out of this two worlds: a) it is somewhat
object oriented and dependency based with an easy configuration similar to
existing tools. While it produces exactly the same actions from the same
configuration on the same machine. Say, it is predictable. On top of it Ningyou
can provide from this a shell script that you can use on a same second machine
without Ningyou, or just look at it to understand what will be done in a
predictible way.

Some tools hide the underlying package manager. While this is good for some
people, it is not good for me. The work flow with those tools for me is: a)
test with a graphical client like synaptic (or aptitude) what would be done on
client A and what effect it has. For example, how many packages will be
installed, are there conflicts, broken packages? And b) then configure the tool
and do it on client B again to see if it works. An very time cosuming verify
it. Make sure that machine A is the same as B. If it works c) deploy it so that
client C,... will be updated. Until now after some month machine A was always
different then B, at least for me.

The Ningyou workflow can be different if you want. You first create the
configuration of lets say a new package in the configuration space of Ningyou.
Ningyou come with the 'test mode' as default run mode. That means, it is used
withyout hiding the command line of the package manger form you, so that you
can see if all goes well. If not you can say 'no' and stop the action. If you
answer all questions with 'yes' (all went fine), then it will be the same as if
you run Ningyou in 'quite mode' where the package manager tries to answer all
questions with 'yes' as in other tools too. Test it with Ningyou in 'test mode'
on client A and then you can already deploy it on client B in 'quite mode',...
and save one step. And you are sure that there is no difference if A and B
was equal before.

So what is the basic rule for Ningyou to be deterministic? Lets show this on
a simple expample configuration and its interpretation:

 [package:zsh]
 [package:vim]
 [package:tree]

This will produce the following actions in a defined order if we asume that
non of thoses packages are installed:

 aptitude install tree
 aptitude install vim
 aptitude install zsh

Ningyou will use the alphabetical order to install the packages. Of course the
package manager can overrule this decision if he thinks a dependency is not
met. However this still is deterministic. And you will see this in the 'test
mode'.





=cut

