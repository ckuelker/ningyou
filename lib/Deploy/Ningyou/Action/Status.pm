# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Status                                           |
# |                                                                           |
# | Provides status argument action                                           |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-02 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::Status;

# ABSTRACT: Provides status argument action

use strict;
use warnings;
use Config::INI::Reader;
use Data::Dumper;
use Moose;
use namespace::autoclean;
use Deploy::Ningyou::Class;
use Deploy::Ningyou::Dependency;

has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, do not seem to work with Module::Pluggable
);

with qw(
    Deploy::Ningyou::Util
    Deploy::Ningyou::Util::Action
    Deploy::Ningyou::Modules
    Deploy::Ningyou::Host
);

our $VERSION = '0.1.1';

sub register              { return 'status'; }
sub parameter             { return { module => 0, }; }
sub parameter_description { return { module => 'name of module' }; }
sub attribute             { return {}; }
sub attribute_description { return {}; }
sub init                  { return 1; }
sub applied               { return 1; }

# apply
# IN:
#     ini: global configuration ~/.ningyou.ini {}
#     mod: modules from command line           []
#     opt: command line options                {}
sub apply {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1, mod => 1, opt => 1 }, $i, {} );
    my $verbose = $s->get_verbose($i);    # opt

    # 1. print:
    # Ningyou v0.1.0 at w2.c8i.org with /srv/deploy/w2.c8i.org.ini
    my $str0    = "# Ningyou %s at %s with %s\n";
    my $version = $s->get_project_version;                        # version
    my $fqhn    = $s->get_fqhn( { ini => $i->{ini} } );           # host name
    my $wt      = $s->get_worktree;
    my $hcfg_fn = "$wt/$fqhn.ini";                                # file name
    my $vc      = $s->c( 'version', "v$version" );
    my $hnc     = $s->c( 'host', $fqhn );
    my $fnc     = $s->c( 'file', $hcfg_fn );
    $s->p( sprintf $str0, $vc, $hnc, $fnc );

    # 2. print:
    # Status modules(s) all in /srv/deploy
    my $str1   = "# %s modules(s) %s in %s\n";
    my $action = $s->register;                    # action
    my $scope  = $s->parse_scope( $i->{mod} );    # all | <MODULE> [<MODULE>]
    my $ac  = $s->c( 'action', ucfirst($action) );
    my $sc  = $s->c( 'scope', $scope );
    my $wtc = $s->c( 'file', $wt );
    $s->p( sprintf $str1, $ac, $sc, $wtc );

    # 3. verbose print
    # class:module                                                      enabled status
    # ================================================================================
    # * testing all components of global:ningyou:
    #   - global:package:aptitude                                               [DONE]
    my $dl = 73;
    my $dx = $dl - 9;
    my $dy = $dl + 3;
    if ($verbose) {
        my $str2 = "%-$dx.${dx}s  %s %s\n";
        $s->p( sprintf $str2, 'class:module', '       ', 'status' );
        $s->p( $s->get_line_nl );
    }

    # 4. get host configuration: global, fqhn, distribution
    # - calculate enabled modules
    # - calculate applied modules
    my $enabled = {};
    my $applied = {};
    my $hcfg    = $s->read_ini( { fn => $hcfg_fn } );    # host cfg
    my $nc
        = Deploy::Ningyou::Class->new( { fqhn => $fqhn, ini => $i->{ini} } );
    my $classes = $nc->get_classes;                      # classes_ar
    my $nd      = Deploy::Ningyou::Dependency->new(
        { ini => $i->{ini}, opt => $i->{opt} } );
    my $meta = {};

    foreach my $class ( sort @{$classes} ) {  # global, HOSTNAME, DISTRIBUTION
        $s->d("class [$class]");

        # sort foreach vim, zsh, ...
        foreach my $module ( sort keys %{ $hcfg->{$class} } ) {
            $s->d("module [$module]\n");
            my $fmodule = "$class:$module";

            # if fullmodule ($class:$module) from CLI, we skip the rest
            next if $scope ne 'all' and not( grep { $_ eq $fmodule } @{ $i->{mod} } );
            my $fmodulec = $s->c( 'module', $fmodule );
            $s->p("* testing all components of $fmodulec:\n") if $verbose;
            $s->d("$fmodulec:\n") ;

            if ( $hcfg->{$class}->{$module} ) {
                $enabled->{$fmodule} = 1;
            }
            else {
                $enabled->{$fmodule} = 0;
            }
            #
            ( $applied->{$fmodule}, $meta ) = $nd->is_module_applied(
                {
                    class  => $class,
                    module => $module,
                    ini    => $i->{ini},
                    opt    => $i->{opt},
                    meta   => $meta,
                }
            );
        }
    }

    # 5. go over _all_ modules
    # - print considered (status of enabled: YES|NO)
    # - print status (DONE|TODO)
    #
    # [ /tmp/ningyou/global/modules/default,
    #   /tmp/ningyou/w1.c8i.org/modules/default, ... ]
    print "\n" if $verbose;
    my $str3 = "%-$dx.${dx}s  %s %s\n";
    $s->p( sprintf $str3, 'class:module', 'enabled', 'status' );
    $s->p( $s->get_line_nl );
    $s->d("worktree [$wt]\n");
    my $mpath = $s->find_module_paths( { wt => $wt } );
    foreach my $mp ( sort @{$mpath} ) {
        $s->d("mp [$mp]\n");
        my ( $class, $module )
            = $s->module_path_to_class_module( { mp => $mp } );
        my $fmodule = "$class:$module";
        $s->d("fmpodule [$fmodule]\n");

        # 5. continue only if one or more named modules are present
        next if $scope ne 'all' and not( grep { $_ eq $fmodule } @{ $i->{mod} } );

        # 6.
        # 7.
        my $fmodulec = $s->c( 'module', $fmodule );
        my $considered
            = $enabled->{$fmodule}
            ? $s->c( 'yes', 'YES' )
            : $s->c( 'no',  ' NO' );
        my $status
            = $applied->{$fmodule}
            ? $s->c( 'yes', 'DONE' )
            : $s->c( 'no',  'TODO' );
        my $str2 = "%-${dy}.${dy}s    [%s]   [%s]\n";
        $s->p( sprintf $str2, $fmodulec, $considered, $status );
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

