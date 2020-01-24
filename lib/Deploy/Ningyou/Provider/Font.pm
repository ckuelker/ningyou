# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Font                                           |
# |                                                                           |
# | Provides font deployment                                                  |
# |                                                                           |
# | Version: 0.1.0 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2020-01-16 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Font;

# ABSTRACT: Provides font deployment

use Data::Dumper;
use File::Basename;
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

our $VERSION = '0.1.0';
our $CACHE   = {};

sub register { return 'font'; }

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
        global  => 0,
        group   => 0,
        local   => 0,
        mode    => 0,
        owner   => 0,
        require => 0,
        source  => 0,
    };
}    # parameter => 1=mandatory|0=optional

sub attribute_default {
    return {
        comment => 0,
        ensure  => 0,
        global  => 0,
        group   => 'root',
        mode    => '0644',
        local   => 0,
        owner   => 'root',
        require => 0,
        source  => 0,
    };
}    # parameter => 1=mandatory|0=optional

# module configuration attributes
sub attribute_description {

    # provided by Deploy::Ningyou::Attribute::*
    return {
        comment => 'test, not used the moment',
        ensure  => 'latest|present|missing',
        global  => 'path to global installation: /usr/share/fonts/',
        group   => 'group name of the file: chgrp',
        mode    => 'file mode: chmod',
        local   => 'list of users (for local installation)',
        owner   => 'user who owns the file: chown',
        require => 'require this other entity (provider)',
        source  => 'source file in the worktree',
    };
}    # param => description

sub init   { return 1; }
sub script { return 0; }
sub apply  { my ( $s, $i ) = @_; return $s->standard_apply($i); }

sub applied {
    my ( $s, $i ) = @_;
    my ( $v, $sec, $cls, $prv, $search, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;
    $s->d("provider font [$sec]");

    # Overview:
    # Z: Calculate fonts (@family, $count)
    # Y: check if global exists
    # X: check every font ($font)
    # 1. If dir exists and it should be removed:
    #    => rm -rf
    # 2. If dir not exists an it should be present:
    #    => mkdir -p
    # Y:
    my @cmd        = @{ $s->get_cmd };
    my $return     = 1;                            # applied
    my $pfx        = "  => directory";
    my $sec_c      = $s->c( 'module', $sec );
    my $loc_c      = $s->c( 'file', $i->{loc} );
    my @family     = qx(ls $cfg->{source});
    my $ldir       = ".local/share/fonts";
    my $count      = scalar @family;
    my @suffixlist = qw(
        .afm .AFM
        .alias .ALIAS
        .dir .DIR
        .enc.gz .ENC.GZ
        .eot .EOT
        .otf .OTF
        .pcf.gz .PCF.GZ
        .pfb .PFB
        .pfm .PFM
        .scale .SCALE
        .svg .SVG
        .ttc .TTC
        .ttf .TTF
        .woff .WOFF
        .woff2 .WOFF2
    );
    my $in_sec = "\nin section [$sec_c]\nat [$loc_c]";

    $s->e( "Malformed [source] [$c->{source}]$in_sec", 'cfg' ) if $count < 1;

    $s->e( "[local] and [global] are mutual exclusive$in_sec", 'cfg' )
        if (exists $c->{local}
        and $c->{local}
        and exists $c->{global}
        and $c->{global} );

    # Y:
    my @user
        = ( exists $c->{local} and $c->{local} )
        ? $s->get_local_usergroup_list( $c->{local} )
        : ("$c->{owner}:$c->{group}");

    # X:
    foreach my $usergroup (@user) {    # user0:group0, user1:group1, ...

        $pfx = "  => directory";

        # TODO: test if user and group exists
        my ( $owner, $group ) = split /:/, $usergroup;

        my $homedir = $s->get_homedir($owner);
        my $fdir    = "$homedir/$ldir";

        if ( exists $c->{global} and $c->{global} ) {    # global= ...
            $pfx = "  => directory [$c->{global}]";
            $s->d("font global mode\n");
            if ( -d $c->{global} and $c->{ensure} eq 'missing' ) {
                $s->d("font global mode ensure missing: action\n");
                my $v = $s->c( 'no', "$pfx exist and it should be removed" );
                $s->d($v);
                my $cmd = "if [ -d '$c->{global}' ];then";
                $cmd .= " rm -rf '$c->{global}';fi";
                push @cmd, { cmd => $cmd, verbose => $v };
                $return = 0;
                $s->set_cmd( \@cmd );
                return $return;
            }
            elsif ( $c->{global} and $c->{ensure} eq 'missing' ) {
                $s->d("font global mode ensure missing: no action\n");
                my $v = "$pfx not exist and it should be";
                $v .= " removed: nothing to do";
                $s->d($v);
                push @cmd, { verbose => $s->c( 'no', $v ) };
                $s->set_cmd( \@cmd );
                return $return;
            }
            elsif ( not -e $c->{global} and $c->{ensure} eq 'present' ) {
                $s->d("font global mode ensure present\n");
                my $v = $s->c( 'no', "$pfx do not exist: should be created" );
                $s->d($v);
                push @cmd,
                    {
                    cmd     => "mkdir -p $c->{global}",
                    verbose => $v
                    };
            }
        }
        else {    # local= .... (make local dir)
            if ( not -e $fdir ) {
                my $v = "$pfx [$fdir] do not exist: should be created";
                $s->d($v);
                push @cmd,
                    { cmd => "mkdir -p $fdir", verbose => $s->c( 'no', $v ) };
            }
        }

        foreach my $src (@family) {    # .../font-a.ttf, .../font-b.ttf
            chomp $src;
            my ( $font, $path, $suffix ) = fileparse( $src, @suffixlist );
            my $dst
                = ( exists $c->{global} and $c->{global} )
                ? "$c->{global}/$font$suffix"
                : ( exists $c->{local} and $c->{local} )
                ? "$fdir/$font$suffix"
                : $s->e( "[gobal] or [local] attribute missing$in_sec",
                'cfg' );
            $s->d("dst [$dst]");
            my $pfx = "  => file [$dst]";

            # Overview:
            # A: Calculate
            # B: Checks
            # C: Action
            # 1. If file exists and it should be removed:
            #    => rm
            # 3. If do not exists and also not source, then just touch it
            #    => touch
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

            # B checks
            # b.2. Check if our source exists
            $s->e( "No [source] file [$src]$in_sec", 'cfg' )
                if $src and not -f $src;

            # b.3. Warn about ensure missing
            $s->e(
                "Ensure is missing. Set automatically ensure=present"
                    . "$in_sec\n"
                    . "Please add ensure=latest or other value to 'ensure'",
                'attribute'
            ) if not exists $c->{ensure};

            # b.4. Warn about ensure=latest without checksum
            $s->e(
                "Found ensure=latest$in_sec\n"
                    . "Please change to ensure=present",
                'attribute'
            ) if $c->{ensure} eq 'latest';

            # C action
            # 1. If file exists and it should be removed:
            if ( -e $dst and $c->{ensure} eq 'missing' ) {
                my $v = "$pfx exist and it should be removed";
                $s->d($v);
                push @cmd,
                    { cmd => "rm '$dst'", verbose => $s->c( 'no', $v ) };
                $return = 0;
            }

            # 3. If do not exists and also not source, then just touch it
            elsif ( not -e $dst and not $src ) {
                my $v = $s->c( 'no',
                    "$pfx do not exist: should be created without source" );
                $s->d($v);
                push @cmd, { cmd => "touch $dst", verbose => $v };
                push @cmd,
                    { cmd => qq{chmod $c->{mode} '$dst'}, verbose => '' };
                push @cmd, { cmd => qq{chown $owner '$dst'}, verbose => '' };
                push @cmd, { cmd => qq{chgrp $group '$dst'}, verbose => '' };
                $return = 0;
            }

            # 5. If file do not exists and we have source
            elsif ( not -e $dst and $src ) {
                my $v = $s->c( 'no', "$pfx NOT exist: it should be copied" );
                $s->d($v);
                push @cmd, { cmd => qq{cp '$src' '$dst'}, verbose => $v };
                push @cmd,
                    { cmd => "chmod $c->{mode} '$dst'", verbose => '' };
                push @cmd, { cmd => qq{chown $owner '$dst'}, verbose => '' };
                push @cmd, { cmd => qq{chgrp $group '$dst'}, verbose => '' };
                $return = 0;
            }

            # 6. If we have mode and the mode is not correct
            elsif ( defined $got_mode and $got_mode ne $c->{mode} ) {
                my $v = "$pfx has mode and mode is wrong: change it";
                $s->d($v);
                my $cmd = qq{chmod $c->{mode} '$dst'};
                push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
                $return = 0;
            }

            # 7. If we have owner and the owner is not correct
            elsif ( defined $got_owner and $got_owner ne $owner ) {
                my $v = "$pfx has owner and owner is wrong: change it";
                $s->d($v);
                my $cmd = qq{chown $owner '$dst'};
                push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
                $return = 0;
            }

            # 8. If we have group and the group is not correct
            elsif ( defined $got_group and $got_group ne $group ) {
                my $v = "$pfx has group and group is wrong: change it";
                $s->d($v);
                my $cmd = qq{chgrp $group '$dst'};
                push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
                $return = 0;
            }

            # 9.else
            else {
                my $v = $s->c( 'yes', "$pfx was already applied" );
                $s->d($v);
                push @cmd, { verbose => $v };
                $return = 1;
            }
            $s->set_cmd( \@cmd );
        }

        if ($return) {    # aready applied
            my @cnt = qx(fc-list|grep '$search');
            if ( scalar(@cnt) > 0 ) {    # successfully applied
                $s->p("# font [$search] present\n") if $s->get_verbose($i);
            }
            elsif ( exists $c->{global} and $c->{global} )
            {    # not successfully applied in global mode
                my $m = "font $search applied but unknown to the system";
                $m .= $in_sec;
                $s->e( $m, 'cfg' );
            }
        }
        else {
            my $v = 'update font cache';
            $s->d($v);
            if ( $s->get_verbose($i) ) {
                push @cmd, { cmd => 'fc-cache -fv', verbose => $v };
            }
            else {
                push @cmd, { cmd => 'fc-cache -f', verbose => $v };
            }
        }
    }
    return $return;
}

sub get_local_usergroup_list {
    my ( $s, $list ) = @_;
    my @usergroup = split /\s*,\s*/, $list;    # user:user,root:root
    return @usergroup;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

