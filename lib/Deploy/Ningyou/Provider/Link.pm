# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Link                                           |
# |                                                                           |
# | Provides link deployment                                                  |
# |                                                                           |
# | Version: 0.1.2 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.2 2020-01-26 Christian Kuelker <c@c8i.org>                            |
# |     - rm checking for existing source (dependency problem)                |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-15 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Link;

# ABSTRACT: Provides link deployment

use Data::Dumper;
use Moose;
use namespace::autoclean;

has 'cmd' => (
    isa     => 'ArrayRef',
    is      => 'rw',
    reader  => 'get_cmd',
    writer  => 'set_cmd',
    default => sub { return []; },
);
has 'dst' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_dst',
    writer  => 'set_dst',
    default => q{},
);

with qw(
    Deploy::Ningyou::Util
    Deploy::Ningyou::Cfg
    Deploy::Ningyou::Execute
    Deploy::Ningyou::Util::Provider
);

our $VERSION = '0.1.2';

sub register { return 'link'; }

sub parameter {
    return { loc => 1, cfg => 1, sec => 1, opt => 1, dry => 0, };
}

sub parameter_description {
    return {
        loc => 'location of the configuration file',
        cfg => 'configuration snippet of a section',
        sec => 'section of the configuration file',
        opt => 'commandline options',
        dry => 'dry run for ::Script',
    };
}

sub parameter_default { return { dry => 1 }; }

# configuration input options
sub attribute {
    return {
        comment => 0,
        ensure  => 1,
        require => 0,
        source  => 1,
        type    => 1,
    };
}    # parameter => 1=mandatory|0=optional

sub attribute_default {
    return {
        comment => 0,
        ensure  => 'present',
        require => 0,
        source  => 0,
        type    => 'symbolic',
    };
}

# module configuration attributes
sub attribute_description {

    # provided by Deploy::Ningyou::Attribute::*
    return {
        comment => 'test, not used the moment',
        ensure  => 'present|missing',
        require => 'require this other entity (provider)',
        source  => 'link source',
        type    => 'kind of link',
    };
}    # param => description

sub init { return 1; }

# IN:
#   cfg:
#   loc:
#   sec:
#   opt
#   dry
# OUT
#   1: global return value                  0|1
#   2: command queue (stack)                [ { cmd=>,verbose=>},.. ]
#   3: output stack                         []
#   4: error stack                          []
#   5: result stack                         []
sub apply { my ( $s, $i ) = @_; return $s->standard_apply($i); }
sub script { return 0; }

# cfg: module section configuration
# cfg = {
#          'destination' => '/home/USER/.vim',
#          'require' => 'package:vim',
#          'ensure' => 'present',
#        };
# loc: /srv/ningyou-0.1.0/global/modules/devel/manifests/devel.ini
# sec: global:file:/home/USER/.perltidyrc
# opt: { 'verbose' => 1 }
# dry: 0
sub applied {
    my ( $s, $i ) = @_;

    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;

    # Overview:
    # A: Calculate
    # B: Checks
    # C: Action
    # 1. If directory exists and it should be removed:
    #    => rm
    # 3. If do not exists  then create it
    #    => mkdir
    #    => chmod,chown,chgrp
    # 6. If we have mode and the mode is not correct
    #    => chmod
    # 7. If we have owner and the owner is not correct
    #    => chown
    # 8. If we have group and the group is not correct
    #    => chgrp
    # 9  else
    #    => NOP
    #
    # A calculate
    my $tflag  = $c->{type} eq 'symbolic' ? '-s' : q{};
    my @cmd    = @{ $s->get_cmd };
    my $return = 1;

    my $sec_c = $s->c( 'module', $i->{sec} );
    my $loc_c = $s->c( 'file',   $i->{loc} );

    # B checks
    # b.1.
    # This will fail if the source of the link is pending (will
    # be created in one go). If to enable this check it is needed
    # to check in the dependency chain if the source will probably
    # created (we hardly can predict this).
    #my $em = "In configuration [$c->{source}] in [$sec_c] at [$loc_c]";
    #$em   .= " an attribute [source] was found, but that source is missing";
    #$em   .= " from the file system. This usually points to a missing";
    #$em   .= " [require] in the configuration. Please, make sure the";
    #$em   .= " source is create before a link is created to it.";
    #$s->e( $em, 'cfg',Dumper($c) ) if not -e $c->{source};

    # b.3. Warn about ensure missing
    $s->e( "Ensure is missing. Set automatically ensure=present in [$sec_c]\n"
            . "at [$loc_c].\n"
            . "Please add ensure=present or other value to 'ensure'" )
        if not exists $c->{ensure};

    $s->e(
              "Wrong value for ensure: "
            . $s->c( 'error', $c->{ensure} )
            . "\nin [$sec_c]\n"
            . "at [$loc_c].", 'cfg'
    ) if not( $c->{ensure} eq 'present' or $c->{ensure} eq 'missing' );

    my $pfx = "  => link";

    # C action
    # 1. If link exists and it should be removed:
    if ( -e $dst and $c->{ensure} eq 'missing' ) {
        my $v = "$pfx [$dst] exist and it should be removed";
        push @cmd, { cmd => "rm $dst", verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 3. If do not exists , then create it
    elsif ( not -e $dst and $c->{ensure} eq 'present' ) {
        my $v = $s->c( 'no', "$pfx [$dst] do not exist: should be created" );
        my $cmd = "ln $tflag $c->{source} $dst";
        push @cmd, { cmd => $cmd, verbose => $v };
        $return = 0;
    }

    # 9.else
    else {
        my $v = $s->c( 'yes', "$pfx was already applied" );
        push @cmd, { cmd => '', verbose => $v };
        $return = 1;
    }
    $s->set_cmd( \@cmd );
    return $return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

