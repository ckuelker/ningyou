# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Modules                                                  |
# |                                                                           |
# | Module related routines                                                   |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-03-27 Christian Külker <c@c8i.org>                             |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Modules;

# ABSTRACT: Module related routines

use Data::Dumper;
use Moose::Role;
use namespace::autoclean;

with qw(Deploy::Ningyou::Util);

our $VERSION = '0.1.1';

# Configuration Space
# w1.c8i.org:zsh, w1.c8i.org:default
sub get_modules_of_host_class {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { fqhn => 1, ini => 1 }, $i, {} );
    $s->e( "no host class for $i->{fqhn}", 'cfg' )
        if not exists $i->{ini}->{host}->{ $i->{fqhn} };

    # {
    #     zsh => 1,
    # }
    return $i->{ini}->{host}->{ $i->{fqhn} };
}

# Configuation Space
# globa:zsh, global:default
sub get_modules_of_global_class {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1 }, $i, {} );
    $s->e( "no global class", 'cfg' )
        if not exists $i->{ini}->{host}->{global};

    # {
    #     zsh => 1,
    # }
    return $i->{ini}->{host}->{global};
}

# Configuation Space
sub get_modules_of_distribution_class {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1 }, $i, {} );
    my $dist = $s->get_distribution( { ini => $i->{ini} } );
    $s->e( "no distribution class", 'cfg' )
        if not exists $i->{ini}->{host}->{$dist};

    # {
    #     zsh => 1,
    # }
    return $i->{ini}->{host}->{$dist};
}

# collect all ENABLED modules for a given host
# from the configuration in the correct order and
# check if they have a manifest
sub get_ini_enabled_modules {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { wt => 1, ini => 1, class => 1 }, $i, {} );

    my $dist = $s->get_distribution( { ini => $i->{ini} } );
    my $fqhn = $s->get_fqhn( { ini => $i->{ini} } );
    my $repd = "$i->{wt}/$dist";
    $s->e( "No distribution [$repd] directory", 'cfg' )
        if not -d $repd;
    my @modules = ();

    foreach my $c ( @{ $i->{class} } ) {    # global, distribution, host
        $s->d("class [$c]");
        foreach my $m ( sort keys %{ $i->{ini}->{host}->{$c} } ) {
            $s->d("module [$m]");
            if ( $i->{ini}->{host}->{$c}->{$m} ) {
                $s->d("module enabled\n");
                my $l = "$i->{wt}/$c/modules/$m/manifests/$m.ini";
                $s->e( "no such file [$l]", 'file' ) if not -f $l;
                my $cfg
                    = $s->read_template_ini( { ini => $i->{ini}, fn => $l } );
                if ( -f $l ) {
                    push @modules,
                        {
                        name     => $m,
                        location => $l,
                        class    => $c,
                        cfg      => $cfg
                        };
                }
                else {
                    my @s = ();
                    push @s, "Module [$m] enabled, but no configuration";
                    push @s, "at [$l].";
                    push @s, "Skiping module [$m] from class section [$c]!";
                    push @s, "HINT: Check [$i->{wt}/$fqhn.ini] or consider";
                    push @s, "creating [$l].";
                    my $str = join qq{\n         }, @s;
                    $s->w($str);
                }
            }
            else {
                $s->d("module NOT enabled, skipping\n");
            }
        }
    }
    return \@modules;
}

no Moose;

1;
__END__
