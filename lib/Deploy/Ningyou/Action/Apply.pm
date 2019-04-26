# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Apply                                            |
# |                                                                           |
# | Provides apply argument action                                            |
# |                                                                           |
# | Version: 0.1.0  (change our $version inside)                              |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-03-31 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::Apply;

# ABSTRACT: Provides apply argument action

use strict;
use warnings;
use Config::INI::Reader;
use Data::Dumper;
use Moose;
use namespace::autoclean;
use Deploy::Ningyou::Dependency;

# mandatory attribute for constructor
has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, # do not seem to work with Module::Pluggable
);

with
    qw(Deploy::Ningyou::Util Deploy::Ningyou::Util::Action Deploy::Ningyou::Modules);

our $version = '0.1.0';

# === [ main ] ================================================================
sub register { return 'apply'; }

# subroutine input options
# parameter: param => 0|1 (optional|mandatory)
# parameter_descrition: param => description
# optional: module name|all, default: all
sub parameter {
    return {
        ini => 1,
        mod => 1,
        opt => 1,
        dry => 0,

    };
}

sub parameter_description {
    return {
        ini => 'configuration',
        mod => 'name of module',
        opt => 'enviroment options',
        dry => 'flag: execute|print script: Deploy::Ningyou::Action::Apply',
    };
}

# configuration input options
sub attribute             { return {}; }
sub attribute_description { return {}; }

sub init { return 1; }

sub apply {
    my ( $s, $i ) = @_;
    my $param = { ini => 1, mod => 1, opt => 1, dry => 0 };
    $i = $s->validate_parameter( $param, $i, {} );
    my $verbose = $s->get_verbose($i);    # opt

    my $action = $s->register;

    # all | zsh vim default ...
    # 1. scope is all if nothing is specified on command line
    # 2. scope is all if all is specified on command line
    # 3. scope is modules if not all is specified on command line
    #   (and at least one modules)
    # 4. scope is all if all and some modules are specified on command line
    #        1.    2.        3.        4.
    # $mod = [ ] | [ all ] | [ vim ] | [ all, vim ]
    my $scope
        = ( grep { $_ eq 'all' } @{ $i->{mod} } ) ? 'all'
        : scalar @{ $i->{mod} } > 0 ? join( q{ }, @{ $i->{mod} } )
        :                             'all';

    my $wt = $s->get_worktree;
    $s->d("wt [$wt]");

    # 1. get providers (file, nop, version, directory, package, ...)
    my $exe = $s->get_providers;

    # 2. get fully qualified host name: HOST.DOMAIN.TDL
    my $fqhn = $s->get_fqhn( { ini => $i->{ini} } );

    # 3. write script boiler plate
    my @script = ();
    push @script, "#!/bin/bash";
    push @script, $s->get_boiler_plate($i);
    push @script, "# Script commands for $fqhn:";
    my $min_lines = scalar @script;

    # 4. get dependency aware queue
    # queue: [ w1.c8i.org:nop:default, global:version:zsh, ... ],
    # rcfg:  { 'global:version:zsh' => { project => '0.1.0', ... }, ... }
    # meta:  { 'global:version:zsh' => { module => 'zsh', ... } }
    my $nd = Deploy::Ningyou::Dependency->new(
        { ini => $i->{ini}, opt => $i->{opt} } );
    my ( $queue, $rcfg, $meta ) = $nd->init;

    # 5. iterate sections (in dependency order)
    my $return = 1;
    foreach my $sec ( @{$queue} ) {    # global:package:vim,...
        $s->d("queue section [$sec]");

        # 5.1 collect some values

        # A check some configuraton
        my ( $class, $provider, $destination ) = $s->parse_section($sec);
        $s->e(
            "section ["
                . $s->c( 'error', $sec )
                . "] is required by a section,\n"
                . "but not provided by any module configuration file.\n"
                . "Add section ["
                . $s->c( 'yes', "$provider:$destination" )
                . "] to a file in the "
                . $s->c( 'class', $class )
                . " class,\n"
                . "for example to "
                . $s->c(
                'file',
                "$class/modules/$destination/manifests/$destination.ini"
                ),
            'configuration'
        ) if not exists $meta->{$sec};

        # B check some configuration
        my $fn
            = exists $meta->{$sec}->{fn}
            ? $meta->{$sec}->{fn}
            : $s->e(
            "no [fn] in meta [$sec] of ::Dependency\n"
                . Dumper( $meta->{$sec} ),
            'bug'
            );

        # C check some configuration
        my $module
            = $meta->{$sec}->{module}
            ? $meta->{$sec}->{module}
            : $s->e( "no [module] in meta [$sec] of ::Dependency", 'bug' );

        $s->d("class [$class]");
        $s->d("provider [$provider]");
        $s->d("destination [$destination]");
        $s->d("module [$module]");
        $s->d("fn [$fn]");

        # 5.2 dispatch scope = all and scope = MODULE
        # next if wrong module and scope not all
        next
            if $scope ne 'all'
            and not( grep { $_ eq "$class:$module" } @{ $i->{mod} } );

        # 5.3 cut the configuration to the current section
        my $cfg
            = exists $rcfg->{$sec}
            ? $rcfg->{$sec}
            : $s->e( "no configuration for section [$sec]", 'bug' );

        # 5.5 apply the section with a provider (execute provider subroutines)
        my $emsg = "unknown for provider [$provider]\n"
            . "at section [$sec]\nin [$fn]";
        my $init
            = exists $exe->{$provider}->{init}
            ? $exe->{$provider}->{init}
            : $s->e( "Init $emsg", 'cfg' );
        my $apply
            = exists $exe->{$provider}->{apply}
            ? $exe->{$provider}->{apply}
            : $s->e( "Apply $emsg", 'cfg' );
        my $applied
            = exists $exe->{$provider}->{applied}
            ? $exe->{$provider}->{applied}
            : $s->e( "Applied $emsg", 'cfg' );
        my $script
            = exists $exe->{$provider}->{script}
            ? $exe->{$provider}->{script}
            : $s->e( "Script $emsg", 'cfg' );

        my $o = {    # options
            cfg => $cfg,
            loc => $fn,         # filename of cfg
            sec => $sec,        # full section
            opt => $i->{opt},
            dry => $i->{dry},
        };

        # 6 init the provider
        $init->($o);

        # 6.1 check if provider was already provided
        my $done = $applied->($o);
        if ( not $done ) {

            # 2: array ref of hash ref { cmd=>,verbose=> }
            #    1   2     3     4     5
            my ( $r, $ar, $out, $err, $ret ) = $apply->($o);

            foreach my $hr ( @{$ar} ) {
                my $v
                    = (     exists $hr->{verbose}
                        and defined $hr->{verbose}
                        and $hr->{verbose} ne q{} )
                    ? "# $hr->{verbose}"
                    : undef;
                my $c
                    = (     exists $hr->{cmd}
                        and defined $hr->{cmd}
                        and $hr->{cmd} ne q{} )
                    ? $hr->{cmd}
                    : undef;
                push @script, $v if defined $v and $verbose;
                push @script, $c if defined $c;
            }
            $done = $applied->($o);

            # exception for provider that have script_output subroutine
        }
        elsif ( $script->($o) ) {
            my ( $r, $ar, $out, $err, $ret ) = $apply->($o);
            foreach my $hr ( @{$ar} ) {
                my $v
                    = (     exists $hr->{verbose}
                        and defined $hr->{verbose}
                        and $hr->{verbose} ne q{} )
                    ? "# $hr->{verbose}"
                    : undef;
                push @script, $v if defined $v and $verbose;
            }
        }
        else {
            $s->d("$class:$module already applied");
        }
    }

    # 7 if dry mode and more linees then default (boiler)

    # script mode: something todo
    if ( $i->{dry} and $min_lines < scalar @script ) {    # script mode
        $s->d("script mode");
    }    # script mode : nothing to do
    elsif ( $i->{dry} and $min_lines == scalar @script ) {
        push @script, '# no script output (nothing to apply)' if $verbose;
    }    # apply mode  and verbose: nothing to do
    elsif ( $verbose and not $i->{dry} and $min_lines == scalar @script ) {
        $s->p("# nothing to apply\n");
    }
    return ( $return, \@script );
}

sub applied { return 1; }

sub get_boiler_plate {
    my ( $s, $i ) = @_;    # arg needed for unit tests
    $i = $s->validate_parameter(
        { ini => 1, opt => 1, mod => 1, version => 0, date => 0, wt => 0 },
        $i,
        {
            version => $s->get_project_version,
            date    => $s->get_date,
            wt      => $s->get_worktree
        }
    );
    my $verbose = $s->get_verbose($i);

    my $action  = $i->{dry} ? 'script'    : $s->register;
    my $options = $verbose  ? "--verbose" : q{};
    my $validdate = $i->{date};
    chomp $validdate;
    my $scope = $s->parse_scope( $i->{mod} );

    my $fqhn = $s->get_fqhn( { ini => $i->{ini} } );
    my $fn = "$i->{wt}/$fqhn.ini";

    return <<"END_OF_BOILER_PLATE";
# +---------------------------------------------------------------------------+
# | Ningyou script                                                            |
# |                                                                           |
# | This script was created with the Ningyou script action                    |
# |                                                                           |
# | Date: $validdate                                                          |
# |                                                                           |
# +---------------------------------------------------------------------------+
#
# Ningyou project version: $i->{version}
# Ningyou script version:  $Deploy::Ningyou::Action::Apply::VERSION
# Worktree:                $i->{wt}
# Configuration:           $fn
# Command Line (approx):   $0 $options $action $scope
#
END_OF_BOILER_PLATE

}

__PACKAGE__->meta->make_immutable;

1;

__END__

