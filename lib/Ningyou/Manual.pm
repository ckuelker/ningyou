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



=cut

