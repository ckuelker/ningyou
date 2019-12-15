# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::File                                           |
# |                                                                           |
# | Provides file deployment                                                  |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::File;

# ABSTRACT: Provides file deployment

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
our $CACHE   = {};

sub register { return 'file'; }

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
        checksum => 0,
        comment  => 0,
        ensure   => 0,
        group    => 0,
        mode     => 0,
        owner    => 0,
        require  => 0,
        source   => 0,
    };
}    # parameter => 1=mandatory|0=optional

sub attribute_default {
    return {
        checksum => 0,
        comment  => 0,
        ensure   => 0,
        group    => 'root',
        mode     => '0640',
        owner    => 'root',
        require  => 0,
        source   => 0,
    };
}    # parameter => 1=mandatory|0=optional

# module configuration attributes
sub attribute_description {

    # provided by Deploy::Ningyou::Attribute::*
    return {
        checksum => 'file need to match this check sum',
        comment  => 'test, not used the moment',
        ensure   => 'latest|present|missing',
        group    => 'group name of the file: chgrp',
        mode     => 'file mode: chmod',
        owner    => 'user who owns the file: chown',
        require  => 'require this other entity (provider)',
        source   => 'source file in the worktree',
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
    # 1. If file exists and it should be removed:
    #    => rm
    # 3. If do not exists and also not source, then just touch it
    #    => touch
    # 4. If file exists and exists checksum and exists source
    #    and checksum not matching
    #    => cp,chmod,chown,chgrp
    # 5. If file do not exists
    #    => cp,chmod,chown,chgrp
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
    my $got_owner = $s->get_owner_of_file($dst);
    my $got_group = $s->get_group_of_file($dst);
    my $got_mode  = $s->get_mode_of_file($dst);
    my $owner  = ( defined $got_owner and $got_owner eq $c->{owner} ) ? 1 : 0;
    my $group  = ( defined $got_group and $got_group eq $c->{group} ) ? 1 : 0;
    my $mode   = ( defined $got_mode and $got_mode eq $c->{mode} ) ? 1 : 0;
    my @cmd    = @{ $s->get_cmd };
    my $return = 1;
    my $sec_c  = $s->c( 'module', $sec );
    my $loc_c  = $s->c( 'file', $i->{loc} );

    # B checks
    # b.2. Check if our source exists
    $s->e(
        "No [source] file [$c->{source}]\nin section [$sec_c]\nat [$loc_c]",
        'cfg' )
        if $c->{source} and not -f $c->{source};

    # b.3. Warn about ensure missing
    $s->e( "Ensure is missing. Set automatically ensure=present in [$sec_c]\n"
            . "at [$loc_c].\n"
            . "Please add ensure=latest or other value to 'ensure'" )
        if not exists $c->{ensure};

    # b.4. Warn about ensure=latest without checksum
    $s->e(    "Found ensure=latest without checksum in [$sec_c]\n"
            . "at [$loc_c]\n"
            . "Please change to ensure=present or add checksum" )
        if not $c->{checksum} and $c->{ensure} eq 'latest';

    # b.5. Warn about ensure=present with checksum
    $s->e(    "Found ensure=present with checksum in [$sec_c]\n"
            . "at [$loc_c]\n"
            . $s->c( 'no', "Checksum will be ignored.\n" )
            . "Please change to ensure=latest or remove checksum" )
        if $c->{checksum} and $c->{ensure} eq 'present';

    # b.6. Warn about checksum without source
    $s->e(
        "Found checksum without source in [$sec_c]\n"
            . "at [$loc_c]\n"
            . $s->c( 'no', "Checksum will be ignored.\n" )
            . "Please add source or remove checksum"
            . Dumper($c),
        'cfg'
    ) if $c->{checksum} and not $c->{source};

    # B.7. Warn about wrong source checksum
    if ( $c->{checksum} ) {
        $s->d("checksum src [$c->{source}] -> dst [$dst]");
        my $scs = $s->get_md5( $CACHE, $c->{source} );
        $s->d("scs [$scs] checksum [$c->{checksum}]");
        if ( $scs ne $c->{checksum} ) {
            $s->e(    "Found non matching checksum in [$sec_c]\n"
                    . "at [$loc_c]\n"
                    . "Checksum should be ["
                    . $s->c( 'action', $c->{checksum} ) . "],\n"
                    . "but it is          ["
                    . $s->c( 'action', $scs ) . "].\n"
                    . $s->c( 'no',     "Checksum will be ignored.\n" )
                    . "The source file is newer than the configuration\n"
                    . "Did you update the source file, but forget to update"
                    . " the configuration?\n"
                    . "Please add correct checksum or remove checksum" );
            $c->{checksum} = 0;
        }
    }
    else {
        $c->{checksum} = 0;
    }

    my $pfx = "  => file";

    # C action
    # 1. If file exists and it should be removed:
    if ( -e $dst and $c->{ensure} eq 'missing' ) {
        my $v = "$pfx [$dst] exist and it should be removed";
        push @cmd, { cmd => "rm $dst", verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 3. If do not exists and also not source, then just touch it
    elsif ( not -e $dst and not $c->{source} ) {
        my $v = "$pfx [$dst] do not exist: should be created without source";
        push @cmd, { cmd => "touch $dst", verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},  verbose => '' };
        push @cmd, { cmd => qq{chown $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 4. If file exists and exists checksum and exists source
    #    and checksum not matching
    elsif ( -e $dst
        and $c->{checksum}
        and $c->{source}
        and not $s->file_md5_eq( $CACHE, $dst, $c->{source} ) )
    {
        my $v = "$pfx [$dst] do exist and should be copied, MD5 differ";
        push @cmd,
            { cmd => qq{cp $c->{source} $dst}, verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},  verbose => '' };
        push @cmd, { cmd => qq{chown $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 5. If file do not exists and we have source
    elsif ( not -e $dst and $c->{source} ) {
        my $v = "$pfx [$dst] do NOT exist and it should be copied";
        push @cmd,
            { cmd => qq{cp $c->{source} $dst}, verbose => $s->c( 'no', $v ) };
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

