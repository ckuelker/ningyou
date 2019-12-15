# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Directory                                      |
# |                                                                           |
# | Provides directory deployment                                             |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-12 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Directory;

# ABSTRACT: Provides directory deployment

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

our $VERSION = '0.1.1';

sub register { return 'directory'; }

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
        ensure  => 0,
        group   => 0,
        mode    => 0,
        owner   => 0,
        require => 0,
    };
}

sub attribute_default {
    return {
        comment => 0,
        ensure  => 'present',
        group   => 'root',
        mode    => '0750',
        owner   => 'root',
        require => 0,
    };
}    # parameter => 1=mandatory|0=optional

# module configuration attributes
sub attribute_description {

    # provided by Deploy::Ningyou::Attribute::*
    return {
        comment => 'test, not used the moment',
        ensure  => 'present|missing',
        group   => 'group name of the file: chgrp',
        mode    => 'file mode: chmod',
        owner   => 'user who owns the file: chown',
        require => 'require this other entity (provider)',
    };
}    # param => description

sub init   { return 1; }
sub script { return 0; }
sub apply  { my ( $s, $i ) = @_; return $s->standard_apply($i); }

sub applied {
    my ( $s, $i ) = @_;
    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;

    # Overview:
    # A: Calculate
    # B: Checks
    # C: Action
    # 1. If directory exists and it should be missing:
    #    => rmdir
    # 1. If directory exists and it should be purged:
    #    => rm -rf
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

    # A calculate
    my $got_owner = $s->get_owner_of_file($dst);
    my $got_group = $s->get_group_of_file($dst);
    my $got_mode  = $s->get_mode_of_file($dst);
    my $owner  = ( defined $got_owner and $got_owner eq $c->{owner} ) ? 1 : 0;
    my $group  = ( defined $got_group and $got_group eq $c->{group} ) ? 1 : 0;
    my $mode   = ( defined $got_mode and $got_mode eq $c->{mode} ) ? 1 : 0;
    my @cmd    = @{ $s->get_cmd };
    my $return = 1;

    my $sec_c = $s->c( 'module', $sec );
    my $loc_c = $s->c( 'file',   $i->{loc} );

    # B checks

    # b.2. Check if our source exists
    $s->e( "No [source] file in section [$i->{sec}]\nat [$loc_c]", 'cfg' )
        if $c->{source} and not -f $c->{source};

    # b.3. Warn about ensure missing
    $s->e( "Ensure is missing. Set automatically ensure=present in [$sec_c]\n"
            . "at [$loc_c].\n"
            . "Please add ensure=present or other value to 'ensure'" )
        if not exists $i->{cfg}->{ensure};

    $s->e(
              "Wrong value for ensure: "
            . $s->c( 'error', $c->{ensure} )
            . "\nin [$sec_c]\n"
            . "at [$loc_c].", 'cfg'
    ) if not( $c->{ensure} eq 'present' or $c->{ensure} eq 'missing' );

    my $pfx  = "  => directory";
    my $stay = 'This should probably stay.';

    # C action
    # 1. If directory exists and it should be missing:
    if ( -e $dst and $c->{ensure} eq 'missing' ) {
        my $v = "$pfx [$dst] exist and it should be removed";
        $s->e("Directory is [/]. $stay")   if $dst eq q{/};
        $s->e("Directory is [./]. $stay")  if $dst eq q{./};
        $s->e("Directory is [..]. $stay")  if $dst eq q{..};
        $s->e("Directory is [../]. $stay") if $dst eq q{../};

        push @cmd, { cmd => "rmdir $dst", verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 2. If directory exists and it should be purged
    if ( -e $dst and $c->{ensure} eq 'purged' ) {
        my $v = "$pfx [$dst] exist and it should be purged";
        $s->e("Directory is [/]. $stay")   if $dst eq q{/};
        $s->e("Directory is [./]. $stay")  if $dst eq q{./};
        $s->e("Directory is [..]. $stay")  if $dst eq q{..};
        $s->e("Directory is [../]. $stay") if $dst eq q{../};

        push @cmd, { cmd => "rm -rf $dst", verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 3. If do not exists , then create it
    elsif ( not -e $dst ) {
        my $v = "$pfx [$dst] do not exist: should be created";
        push @cmd, { cmd => "mkdir  $dst", verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},  verbose => '' };
        push @cmd, { cmd => qq{chown $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 6. If we have mode and the mode is not correct
    elsif ( defined $got_mode and $got_mode ne $c->{mode} ) {
        my $v   = "$pfx [$dst] has mode and mode is wrong: change it";
        my $cmd = qq{chmod $c->{mode} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 7. If we have owner rand the owner is not correct
    elsif ( defined $got_owner and $got_owner ne $c->{owner} ) {
        my $v   = "$pfx [$dst] has owner and owner is wrong: change it";
        my $cmd = qq{chown $c->{owner} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 8. If we have group and the group is not correct
    elsif ( defined $got_group and $got_group ne $c->{group} ) {
        my $v   = "$pfx [$dst] has group and group is wrong: change it";
        my $cmd = qq{chgrp $c->{group} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
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

