# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Rsync                                          |
# |                                                                           |
# | Provides recursive directory deplyment                                    |
# |                                                                           |
# | Version: 0.1.2 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.2 2020-01-21 Christian Kuelker <c@c8i.org>                            |
# |     - fix rsync --group option                                            |
# |     - fix rsync --owner option                                            |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-12 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Rsync;

# ABSTRACT: Provides recursive directory deployment

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

sub register { return 'rsync'; }    # name of provider type: file, rsync, ...

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
        dry     => 0,
        group   => 0,
        itemize => 0,
        mode    => 0,
        owner   => 0,
        purge   => 0,
        require => 0,
        source  => 1,
    };
}    # parameter => 1=mandatory|0=optional

sub attribute_default {
    return {
        comment => 0,
        dry     => 1,
        group   => 'root',
        itemize => 0,
        mode    => '0750',
        owner   => 'root',
        purge   => 0,
        require => 0,
        source  => 0,
    };
}

# module configuration attributes
sub attribute_description {

    # provided by Deploy::Ningyou::Attribute::*
    return {
        comment => 'test, not used the moment',
        dry     => 'make dry-run',
        ensure  => 'latest|present|missing',
        group   => 'group name of the file: chgrp',
        itemize => 'output a change-summary for all updates',
        mode    => 'file mode: chmod',
        owner   => 'user who owns the file: chown',
        purge   => 'delete file not present in source',
        require => 'require this other entity (provider)',
        source  => 'source directory',
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
    # 1. If do not exists then create it and sync it
    #    => rsync,chmod,chown,chgrp
    # 2. If do  exists then sync it
    #    => rsync,chmod,chown,chgrp
    # 3. If we have mode and the mode is not correct
    #    => chmod
    # 4. If we have owner and the owner is not correct
    #    => chown
    # 5. If we have group and the group is not correct
    #    => chgrp
    # 6  else
    #    => NOP
    #
    # A calculate
    my $got_owner = $s->get_owner_of_file($dst);
    my $got_group = $s->get_group_of_file($dst);
    my $got_mode  = $s->get_mode_of_file($dst);
    my @cmd       = @{ $s->get_cmd };
    my $return    = 1;
    my $sec_c     = $s->c( 'module', $sec );
    my $loc_c     = $s->c( 'file', $i->{loc} );

    my $rsync = $v ? qq{rsync -avSPHAX} : qq{rsync -aSPHAX};

    # special attributes (user value not equal provider value)
    my $itemize = $i->{cfg}->{itemize} ? '--itemize-changes' : q{};
    my $purge   = $i->{cfg}->{purge}   ? '--delete'          : q{};
    my $dryrun  = $i->{cfg}->{dry}     ? '--dry-run'         : q{};

    # construct command
    my $chmod = '--chmod=' . $c->{mode};
    my $opt   = qq{$itemize $dryrun $purge $chmod};
    $c->{source} = $c->{source} . "/";
    $c->{source} =~ s{//$}{/}gmx;    # bar -> bar/  | bar/ -> bar/
    my $command = "$rsync $opt $c->{source} $dst";

    # B checks
    # b.2. Check if our source exists
    $s->e(
        "A [source] directory was specified in section [$sec_c]\nat [$loc_c],\nbut do not exist on the file system: ["
            . $s->c( 'error', $c->{source} )
            . "]. Please create it.",
        'cfg'
    ) if $c->{source} and not -d $c->{source};

    my $pfx = "  => rsync";

    # C action
    # 1. If do not exists , then create it
    if ( not -d $dst and -d $c->{source} ) {
        my $v
            = "$pfx [$dst] do NOT exist: should be created and synchronized";
        push @cmd, { cmd => $command, verbose => $v };

        # owner
        if ( exists $c->{owner} and $c->{owner} ) {
            $v = "$pfx [$dst] change owner to [$c->{owner}]";
            push @cmd, { cmd => "chown -R $c->{owner} $dst", verbose => $v };
        }

        # group
        if ( exists $c->{group} and $c->{group} ) {
            $v = "$pfx [$dst] change group to [$c->{group}]";
            push @cmd, { cmd => "chown -R $c->{group} $dst", verbose => $v };
        }
        $return = 0;
    }

    # 2. If do exists , then sync it (again)
    elsif ( -d $dst and $c->{source} and -d $dst ) {
        my ( $equal, $rem ) = $s->compare_dirs( $dst, $c->{source} );
        if ( not $equal ) {
            my $v = "$pfx [$dst] do exist: should be synchronized again";
            foreach my $r ( @{$rem} ) {
                push @cmd, { verbose => $s->c( 'no', $r ) };
            }
            push @cmd, { cmd => $command, verbose => $v };

            # owner
            if ( exists $c->{owner} and $c->{owner} ) {
                $v = "$pfx [$dst] change owner to [$c->{owner}]";
                push @cmd,
                    { cmd => "chown -R $c->{owner} $dst", verbose => $v };
            }

            # group
            if ( exists $c->{group} and $c->{group} ) {
                $v = "$pfx [$dst] change group to [$c->{group}]";
                push @cmd,
                    { cmd => "chown -R $c->{group} $dst", verbose => $v };
            }
            $return = 0;
        }
    }

    # 3. If we have mode and the mode is not correct
    elsif ( defined $got_mode and $got_mode ne $c->{mode} ) {
        my $v   = "$pfx [$dst] has mode and mode is wrong: change it";
        my $cmd = qq{chmod $c->{mode} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 4. If we have owner rand the owner is not correct
    elsif ( defined $got_owner and $got_owner ne $c->{owner} ) {
        my $v   = "$pfx [$dst] has owner and owner is wrong: change it";
        my $cmd = qq{chown $c->{owner} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 5. If we have group and the group is not correct
    elsif ( defined $got_group and $got_group ne $c->{group} ) {
        my $v   = "$pfx [$dst] has group and group is wrong: change it";
        my $cmd = qq{chgrp $c->{group} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 6.else
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

