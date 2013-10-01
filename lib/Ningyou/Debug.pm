package Ningyou::Debug;

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
our $VERSION = '0.0.3';

sub d {
    my ( $s, $i ) = @_;
    my $o = $s->get_options;

    chomp $i;
    $i = $i . "\n";
    if ( exists $o->{debug} and $o->{debug} ) {
        my $fn = $o->{debug};
        open my $f, q{>>}, $fn or die "Can not open [$fn]";
        print $f $i;
    }
    elsif ( exists $o->{debug} ) {
        print $i;
    }
}
1;
__END__

=pod

=head1 NAME

Ningyou::Debug - prints debug to STDOUT or file

=cut
