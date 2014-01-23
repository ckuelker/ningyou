package Ningyou::Verbose;

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
our $VERSION = '0.0.9';

sub v {
    my ( $s, $i ) = @_;
    chomp $i;
    my $o = $s->get_options;
    return if not exists $o->{verbose};
    my $v = q{ } x $o->{indentation};
    $i = $v . $i . "\n";
    if ( exists $o->{debug} and $o->{debug} ) {
        my $fn = $o->{debug};
        open my $f, q{>>}, $fn or die "Can not open [$fn]";
        print $f $i;
    }
    elsif ( not exists $o->{quite} and exists $o->{verbose} ) {
        print $i;
    }
    return 1;
}
1;

=pod

=head1 NAME 

Ningyou::Verbose

=head1 DESCRIPTION

This class prints verbose messages to STDOUT if --verbose is given on command
line, unless --quite is provided. In case of --debug and --verbose it will
print to STDOUT verbose, unless --quite is provided.  In case of
--debug=/filename and --verbose it will print all message to the file
regardless if --quite is provided or not and to STDOUT, unless --quite is
provided.

=cut

