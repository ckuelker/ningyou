package Ningyou::Out;

use utf8;                        # so literals and identifiers can be in UTF-8
use v5.12;                       # or later to get "unicode_strings" feature
use strict;                      # quote strings, declare variables
use warnings;                    # on by default
use warnings qw(FATAL utf8);     # make encoding glitches fatal
use open qw(:std :utf8);         # undeclared streams in UTF-8
use charnames qw(:full :short);  # unneeded in v5.16
use Carp;
use Data::Dumper;
use Moose::Role;
use namespace::autoclean;
our $VERSION = '0.0.9';
use Term::ANSIColor;

# Idea from  Data::Dump::Color
use vars qw(%COLOR_THEMES %COLORS $COLOR $COLOR_THEME $COLOR_DEPTH);
%COLOR_THEMES = (
    default16 => {
        colors => {
            undef => 'white',

            version => 'green',
            host    => 'bright_blue',
            yes     => 'bright_green',
            no      => 'bright_red',
            mode    => 'blue',
            ready   => 'green',
            execute => 'red',
            todo    => 'bright_red',
            error   => 'bright_red',
            done    => 'bright_green',
            module  => 'yellow',
            comment => 'blue',
            command => 'yellow',
            file    => 'magenta',
            module  => 'bright_yellow',

            string => 'bright_yellow',
            string => 'bright_cyan',
            object => 'bright_green',
            symbol => 'cyan',
            linum  => 'black on_white',
        },
    },
    default256 => {
        color_depth => 256,
        colors      => {
            version => 135,
            undef   => 124,
            host    => 27,
            file    => 51,
            string  => 226,
            object  => 10,
            module  => 10,
            key     => 202,
            comment => 34,
            keyword => 21,
            symbol  => 51,
            linum   => 10,
        },
    },
);
$COLOR_THEME = ( $ENV{TERM} // "" ) =~ /256/ ? 'default256' : 'default16';
$COLOR_DEPTH = $COLOR_THEMES{$COLOR_THEME}{color_depth} // 16;
%COLORS = %{ $COLOR_THEMES{$COLOR_THEME}{colors} };
my $_colreset = color('reset');

sub c {
    my ( $s, $c, $i ) = @_;
    my $col = defined $c ? $c : 'undef';
    my $colval = $COLORS{$col};
    if ( $COLOR // $ENV{COLOR} // ( -t STDOUT ) ) {
        if ( $COLOR_DEPTH >= 256 && $colval =~ /^\d+$/ ) {
            return "\e[38;5;${colval}m" . $i . $_colreset;
        }
        else {
            return color($colval) . $i . $_colreset;
        }
    }
    else {
        return $i;
    }
}

sub o {
    my ( $s, $i ) = @_;
    confess "ERROR: empty string in output" if not defined $i;

    #chomp $i;
    my $o           = $s->get_options;
    my $indentation = exists $o->{indentation}
        and defined $o->{indentation} : $o->{indentation} : 0;
    my $v = q{ } x $indentation;

    #$i = $v . $i . "\n";
    $i = $v . $i;
    if ( exists $o->{debug} and $o->{debug} ) {
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

