# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Util                                                     |
# |                                                                           |
# | Utilities                                                                 |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-03-27 Christian Külker <c@c8i.org>                             |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Util;

# ABSTRACT: Utilities

use strict;
use warnings;
use Config::Tiny;
use Data::Dumper;
use Digest::MD5;
use File::Basename;
use File::DirCompare;
use List::Compare;
use Moose::Role;
use namespace::autoclean;
use Template;
use Term::ANSIColor;

# Idea from  Data::Dump::Color
use vars qw(%COLOR_THEMES %COLORS $COLOR $COLOR_THEME $COLOR_DEPTH);

with qw(Deploy::Ningyou::Env Deploy::Ningyou::Cfg Deploy::Ningyou::Host);

our $version = '0.1.0';
our $L       = "=" x 80;
%COLOR_THEMES = (
    default16 => {
        colors => {
            attribute => 'cyan',
            class     => 'yellow',
            directory => 'bright_magenta',
            error     => 'bright_red',
            fail      => 'bright_red',
            file      => 'magenta',
            group     => 'magenta',
            module    => 'bright_yellow',
            no        => 'bright_red',
            ng        => 'bright_red',
            undef     => 'white',
            ok        => 'bright_green',
            owner     => 'magenta',
            pass      => 'bright_green',
            section   => 'bright_yellow',
            warning   => 'bright_cyan',
            yes       => 'bright_green',
            #
            version => 'green',
            host    => 'bright_blue',
            mode    => 'blue',
            ready   => 'green',
            execute => 'red',
            todo    => 'bright_red',
            done    => 'bright_green',
            comment => 'blue',
            command => 'yellow',
            action  => 'yellow',
            scope   => 'bright_yellow',
            string  => 'bright_cyan',
            object  => 'bright_green',
            symbol  => 'cyan',
            linum   => 'black on_white',
        },
    },
    default256 => {
        color_depth => 256,
        colors      => {
            yes => 10,
            no  => 1  ,
            #
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

sub exists_color {
    my ( $s, $k ) = @_;
    my $r
        = ( exists $COLORS{$k} and defined $COLORS{$k} and $COLORS{$k} )
        ? 1
        : 0;
    return $r;
}

# === [ fixed ] ===============================================================
sub get_project_version       { return '0.1.0'; }
sub get_configuration_version { return '0.1.0'; }
sub get_date { my $date = qx(date +'%F'); chomp $date; return $date; }

# === [ output ] ==============================================================
sub get_line    { return $L; }
sub get_line_nl { return "$L\n"; }

# debug
sub d {
    my ( $s, $m ) = @_;    # automatic \n
    my ( $package, $filename, $line, $subroutine ) = caller(1);
    return if not defined $m;
    return if not $s->get_debug;
    chomp $m;
    my $t  = time;
    my $fn = $s->get_debug_filename;
    open my $fh, q{>>}, $fn or die "ERR: can not open [$fn]";
    printf $fh "%s {%s} %s %s\n", $t, $subroutine, $line, $m;
    close $fh;
    return $m;
}

# print and debug
sub p {    # manual \n
    my ( $s, $m ) = @_;
    return q{} if not defined $m;
    $s->d($m);
    print $m;
    return $m;
}

# color
sub c {    # manual \n
    my ( $s, $c, $m ) = @_;
    my $col       = defined $c ? $c : 'undef';
    $s->d("col [$col]");
    my $colval    = defined $COLORS{$col} ? $COLORS{$col} : 'white';
    $s->d("colval [$colval]");
    #$s->d(Dumper(\%COLORS));
    my $_colreset = color('reset');
    if ( $COLOR // $ENV{COLOR} // ( -t STDOUT ) ) {
        if ( $COLOR_DEPTH >= 256 && $colval =~ /^\d+$/ ) {
            return "\e[38;5;${colval}m" . $m . $_colreset;
        }
        else {
            return color($colval) . $m . $_colreset;
        }
    }
    else {
        return $m;
    }
}

# warning: print and debug
sub w {
    my ( $s, $m ) = @_;
    chomp $m;
    my $str = q{};
    foreach my $n ( 0 .. 10 ) {
        my ( $p, $f, $l, $s ) = caller($n);
        $str .= "$p $l\n"
            if defined $l
            and defined $p
            and $l ne q{}
            and $p ne q{};
    }
    $s->p( "$L\n" . $s->c( 'warning', "WARNING" ) . ": $m\n$str\n$L\n" );
    # TODO if debug exit 1;
}

our $chkc = "\nPlease check the configuration";
our $chkl = "\nPlease check the loation or configuration";
our $pta  = "\nPlease try again";
our $pfsc = "\nThis is a bug, please fix the source code ...";
our $hint = {
    action     => 'Try --help or --man',
    attribute  => "A mandatory attribute is missing in the configuration",
    bootstrap  => 'Consider executing `ningyou bootstrap`',
    bug        => $pfsc,
    cfg        => "Wrong configuration? $chkc",
    dir_exists => "Check the name, configuration or remove it. $chkc. $pta",
    dublicate  => "Attributes differ in duplicate sections. $chkc",
    file       => 'File do not exist. Check the file name',
    facter     => '/usr/bin/facter is missing. Install it?',
    no_dir     => 'You tried invoking ningyou from a non existing directory?',
    permission => 'Do you have the right permissions?',
    removing   => "Consider removing it first. $pta",
    selfref    => "Section is requiring itself. $chkc",
    sp         => "Parameter was not given to the subroutine. $pfsc",
    usage      => 'Wrong usage, see --help or --man',
    worktree   => $chkl,
    wrong_dir  => 'Executing ningyou from the wrong directory?',
};

# error: print and debug
sub e {
    my ( $s, $msg, $k ) = @_;
    $s->e( "ERROR: k not defined", "bug" ) if not defined $k;
    my $h = exists $hint->{$k} ? "HINT: $hint->{$k}" : q{};

    my $str = q{}; # debug information
    my $di  = q{Debug information:};
    foreach my $n ( 0 .. 10 ) {
        my ( $p, $f, $l, $s ) = caller($n);
        $str .= "\t$p $l\n"
            if defined $l
            and defined $p
            and $l ne q{}
            and $p ne q{};
    }
    die "\n$L\n" . $s->c( 'error', "ERROR" ) . ": $msg\n$h\n$L\n$di\n$str\n";
}

# get provider configuration and subroutines
sub get_providers {
    my ( $s, $i ) = @_;
    my $np        = Deploy::Ningyou::Provider->new();
    my $providers = $np->get_plugins();
    foreach my $c ( sort keys %{$providers} ) {
        $s->d("found attribute plugin class [$c]");
    }
    return $providers;
}

sub get_distribution { # [os]
    my ( $s, $i ) = @_;
    my $ini = exists $i->{ini} ? $i->{ini} : $s->e( 'no [ini]', 'sp' );
    my $os
        = exists $ini->{os}
        ? $ini->{os}
        : $s->e( "no [os] section at [~/.ningyou.ini]", 'cfg' );
    my $distribution
        = exists $os->{distribution}
        ? $os->{distribution}
        : $s->e( "no [distribution] under [os] at [~/.ningyou.ini]", 'cfg' );
    return $distribution;
}

sub get_fqhn { # [system]
    my ( $s, $i ) = @_;
    my $ini = exists $i->{ini} ? $i->{ini} : $s->e( 'no [ini]', 'sp' );
    my $sys
        = exists $ini->{system}
        ? $ini->{system}
        : $s->e( "no [system] section at [~/.ningyou.ini]", 'cfg' );
    my $fqhn
        = exists $sys->{fqhn}
        ? $sys->{fqhn}
        : $s->e( "no [fqhn] under [system] at [~/.ningyou.ini]", 'cfg' );
    return $fqhn;
}
sub get_class { # [class]
    my ( $s, $i ) = @_;
    my $ini = exists $i->{ini} ? $i->{ini} : $s->e( 'no [ini]', 'sp' );
    my $class
        = exists $ini->{class}
        ? $ini->{class}
        : $s->e( "no [class] section at [~/.ningyou.ini]", 'cfg' );
    my @class = ();
    foreach my $c (sort keys %{$class}){ # name = [0|1]
        $s->d("consider class [$c]");
        push @class, $c if $class->{$c};
        $s->d("add class [$c]") if  $class->{$c};
    }
    return @class;
}

# get package manager cache time to live
sub get_pm_cache_ttl {
    my ( $s, $i ) = @_;
    my $ini = exists $i->{ini} ? $i->{ini} : $s->e( 'no [ini]', 'sp' );
    my $os
        = exists $ini->{os}
        ? $ini->{os}
        : $s->e( "no [os] section at [~/.ningyou.ini]", 'cfg' );
    my $pm_cache_ttl
        = exists $os->{pm_cache_ttl}
        ? $os->{pm_cache_ttl}
        : $s->e( "no [pm_cache_ttl] under [os] at [~/.ningyou.ini]", 'cfg' );
    return $pm_cache_ttl;
}

#  global, vim => worktree/global/modules/vim/manifests/vim.ini
sub module_to_ini {    # module 2 module configuration
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { class => 1, module => 1 }, $i, {} );
    my $wt = $s->get_worktree;
    my $fn = join q{/},
        (
        $wt, $i->{class}, 'modules', $i->{module}, 'manifests',
        $i->{module} . ".ini"
        );
    return $fn;
}

# ini section: [provider:destination]
# class:provider:destination;
# examples:
#   package
#                                    w1.c8iorg:package:vim
#    debian-gnu-linux-9.8-stretch-amd64-x86_64:package:vim
#                                       global:package:vim
#                                              package:vim
#  file
#                                    w1.c8iorg:file:/etc/cron.daily/logrotate
#    debian-gnu-linux-9.8-stretch-amd64-x86_64:file:/etc/cron.daily/logrotate
#                                       global:file:/etc/cron.daily/logrotate
#                                              file:/etc/cron.daily/logrotate
# IN:
#     i : global:cpan:Dist::Zilla::Plugin::PerlTidy
sub parse_section {
    my ( $s, $i ) = @_;
    my ( $c, $p, $d ) = ( '', '', '' );
    ( $c, $p, $d ) = ( '', $1, $2 ) if $i =~ m/(.*?):(.*?)/;
    ( $c, $p, $d ) = ( $1, $2, $3 ) if $i =~ m/(.*?):(.*?):(.*)/;
    return ( $c, $p, $d );
}

# package:vim => global:package:vim
sub section_to_full_section {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { sec => 1, req => 1 }, $i, {} );
    my ( $c0, $p0, $d0 ) = $s->parse_section( $i->{sec} );
    my ( $c1, $p1, $d1 ) = $s->parse_section( $i->{req} );
    my $require = $c1 ne '' ? $i->{req} : "$c0:$i->{req}";
    return $require;
}

# === [ configuration ] =======================================================
sub new_ini {
    return Config::Tiny->new;
}

sub read_ini {
    my ( $s, $i ) = @_;
    my $fn = exists $i->{fn} ? $i->{fn} : $s->e( 'no [fn]', 'sp' );
    $s->e( "No such file [$fn]", 'file' ) if not -f $fn;
    my $cfg = Config::Tiny->read( $fn, 'utf8' );
    return $cfg;
}

sub read_template_ini {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1, fn => 1 }, $i, {} );
    $s->e( "No such file [$i->{fn}]", 'file' ) if not -f $i->{fn};

    # consider writing Deploy::Ningyou::Template
    my %config = (
        ABSOLUTE  => 1,
        VARIABLES => {
            PROJECT       => $s->get_project_version,
            CONFIGURATION => $s->get_configuration_version,
            DISTRIBUTION  => $s->get_distribution( { ini => $i->{ini} } ),
            WORKTREE      => $s->get_worktree,
            FQHN          => $s->get_fqhn( { ini => $i->{ini} } ),
        }
    );
    my $t = Template->new( \%config ) || die Template->error(), "\n";
    my $var = { VERSION => $Deploy::Ningyou::Util::VERSION, };
    my $tpl = q{};
    my $r = $t->process( $i->{fn}, $var, \$tpl ) || die $s->e( $t->error() );
    $s->d($tpl);
    my $cfg = Config::Tiny->read_string( $tpl, 'utf8' );
    return $cfg;
}

sub apply_template {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1, tpl => 1 }, $i, {} );
    my $tpl    = $i->{tpl};
    my %config = (
        ABSOLUTE  => 1,
        VARIABLES => {
            PROJECT       => $s->get_project_version,
            CONFIGURATION => $s->get_configuration_version,
            DISTRIBUTION  => $s->get_distribution( { ini => $i->{ini} } ),
            WORKTREE      => $s->get_worktree,
            FQHN          => $s->get_fqhn( { ini => $i->{ini} } ),
            DATE          => $s->get_date,
        }
    );
    my $t = Template->new( \%config ) || die Template->error(), "\n";
    my $var  = { VERSION => $Deploy::Ningyou::Util::VERSION, };
    my $rini = q{};
    my $r    = $t->process( \$tpl, $var, \$rini ) || die $s->e( $t->error() );
    $s->d($rini);
    return $rini;
}

# === [ attribute helper ] ====================================================

# validate_parameter
# IN
#   parameter: { name => 0,      object => 1,      comment => 0     }
#   i        : {                 object => '/srv'                   }
#   default  : { name => 'root'                                     }
# OUT
#   {            name => 'root', object => '/srv', comment => undef }
sub validate_parameter {
    my ( $s, $parameter, $i, $default ) = @_;
    my $sub = ( caller(1) )[3];
    foreach my $p ( sort keys %{$parameter} ) {
        if ( $parameter->{$p} ) {    # mandatory
            $s->d("* mandatory parameter [$p]");
            my $e = "no [$p] at $sub\n" . Dumper($i);
            $i->{$p} = exists $i->{$p} ? $i->{$p} : $s->e( $e, 'sp' );
            $i->{$p} = ( exists $i->{$p} and defined $i->{$p} ) ? $i->{$p} : $s->e( $e, 'sp' );
            $s->d("  subroutine [$sub]");
            $s->d("  value [$i->{$p}]");
        }
        else {                       # optional
            $s->d("* optional parameter [$p]");
            $s->d("  subroutine [$sub]");
            $i->{$p}
                = exists $i->{$p}       ? $i->{$p}
                : exists $default->{$p} ? $default->{$p}
                :                         undef;
            $s->d("  value [$i->{$p}]") if defined $i->{$p};
            $s->d("  value [undef]") if not defined $i->{$p};
        }
    }
    return $i;
}

#    Ningyou
sub get_last_change_of_file {
    my ( $s, $fn ) = @_;
    return undef if not -e $fn;
    my $modtime = ( stat($fn) )[9];
    return $modtime;
}

sub get_verbose {
    my ( $s, $i ) = @_;
    my $opt = exists $i->{opt} ? $i->{opt} : $s->e( 'no [opt]', 'sp' );
    my $v
        = exists $opt->{verbose}
        and defined $opt->{verbose}
        and $opt->{verbose} ? 1 : 0;
    return $v;
}

no Moose::Role;

1;
__END__

=pod

=head1 SYNOPSIS

Various helper subroutines for Deploy::Ningyou.

=method d

Prints debug messages to file specified by environment variable
NINGYOU_DEBUG=<FILE>

=method e

Prints error message

=cut
