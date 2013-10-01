package Ningyou::Out;

use utf8;                        # so literals and identifiers can be in UTF-8
use v5.12;                       # or later to get "unicode_strings" feature
use strict;                      # quote strings, declare variables
use warnings;                    # on by default
use warnings qw(FATAL utf8);     # make encoding glitches fatal
use open qw(:std :utf8);         # undeclared streams in UTF-8
use charnames qw(:full :short);  # unneeded in v5.16
use Data::Dumper;
use Moose::Role;
use namespace::autoclean;
our $VERSION = '0.0.2';

sub o {
    my ( $s, $i ) = @_;
    chomp $i;
    my $o = $s->get_options;
    my $v = q{ } x $o->{indentation};
    $i = $v . $i . "\n";
    if ( exists $o->{debug} and $o->{debug}) {
        my $fn = $o->{debug};
        open my $f, q{>>}, $fn or die "Can not open [$fn]";
        print $f $i;
    }
    print $i if not exists $o->{quite};
}
1;
__END__

=pod

=head1 NAME

Ningyou::Out - prints to STDOUT and/or debug files

=cut

