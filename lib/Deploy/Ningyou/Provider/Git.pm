# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Git                                            |
# |                                                                           |
# | Provides git deployment                                                   |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-12 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Git;

# ABSTRACT: Provides git deployment

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

our $version = '0.1.0';

sub register { return 'git'; }

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

# configuration input options: mandatory 1, optional 0
sub attribute {
    return {
        comment => 0,
        ensure  => 0,
        group   => 0,
        mode    => 0,
        owner   => 0,
        require => 0,
        source  => 1,
    };
}

sub attribute_default {
    return {
        comment => 0,
        ensure  => 'latest',
        group   => 'root',
        mode    => '0750',
        owner   => 'root',
        require => 0,
        source  => 0,
    };
}

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
        sourcee => 'git repository',
    };
}    # param => description

sub apply { my ( $s, $i ) = @_; return $s->standard_apply($i); }
sub init { return 1; }
sub script { return 0; }

sub applied {
    my ( $s, $i ) = @_;
    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;

    # Overview:
    # A: Calculate
    # B: Checks
    # C: Action
    # 1. If git directory exists and it should be removed
    #    => rm -rf
    # 2. If git directory do not exists and source exists: clone it
    #    => sudo git clone
    #    => chmod,chown,chgrp
    # 3. If git directory do exists and .git not: clone it
    #    => sudo git clone
    #    => chmod,chown,chgrp
    # 4. If git dir exists and ensure = latest and not clean, then pull it
    #    => sudo git pull
    # 5. If we have mode and the mode is not correct
    #    => chmod
    # 6. If we have owner and the owner is not correct
    #    => chown
    # 7. If we have group and the group is not correct
    #    => chgrp
    # 8  else
    #    => NOP

    # A calculate
    my $got_owner = $s->get_owner_of_file($dst);
    my $got_group = $s->get_group_of_file($dst);
    my $got_mode  = $s->get_mode_of_file($dst);
    my $owner = ( defined $got_owner and $got_owner eq $c->{owner} ) ? 1 : 0;
    my $group = ( defined $got_group and $got_group eq $c->{group} ) ? 1 : 0;
    my $mode  = ( defined $got_mode and $got_mode eq $c->{mode} ) ? 1 : 0;
    my @cmd    = $s->get_cmd;    # set by applied_in
    my $return = 1;

# Best:
#     if output=$(git status --porcelain) && [ -z "$output" ]; then
#     ... # Working directory clean
#     else
#     ... # Uncommitted changes
#     fi
# Using this, we can check for unstaged changes with:
#     git diff --exit-code
# and staged, but not committed changes with:
#     git diff --cached --exit-code
# => https://unix.stackexchange.com/questions/155046/determine-if-git-working-directory-is-clean-from-a-script
    my $clean = 0;
    if ( -d $dst and -d "$dst/.git" ) {    # we have a git repo
            # gives 255 on unclean and 0 on clean
        my $cmd
            = qq{output=\$(git -C $dst status --untracked-files=no --porcelain) && [ -z "\$output" ]};
        my ( $out, $err, $res ) = $s->execute($cmd);
        $clean = $res ? 0 : 1;
    }

    my $sec_c = $s->c( 'module', $sec );
    my $loc_c = $s->c( 'file',   $i->{loc} );

    # B checks

    # b.2. Warn about ensure missing
    my $wmsg
        = "Ensure is missing. Set automatically ensure=present"
        . "in [$sec_c]\n"
        . "at [$loc_c].\n"
        . "Please add ensure=present or other value to 'ensure'";
    $s->w($wmsg) if not exists $i->{cfg}->{ensure};
    my $ensure_c = $s->c( 'error', $c->{ensure} );
    my $emsg
        = "Wrong value for ensure: $ensure_c \n"
        . "in [$sec_c]\n"
        . "at [$loc_c].";
    $s->e( $emsg, 'cfg' )
        if not( $c->{ensure} eq 'present'
        or $c->{ensure} eq 'missing'
        or $c->{ensure} eq 'latest' );

    my $pfx       = "  => git";
    my $git_clone = "git --no-pager clone $c->{source} $dst --quiet";
    my $git_pull  = "git -C $dst --no-pager pull --quiet";

    # C action
    # 1. If git directory exists and it should be removed:
    if ( -e $dst and $c->{ensure} eq 'missing' ) {
        my $v   = "$pfx [$dst] exist and it should be removed";
        my $rem = "This should probably stay.";
        $s->e("Directory is [/]. $rem")   if $dst eq q{/};
        $s->e("Directory is [./]. $rem")  if $dst eq q{./};
        $s->e("Directory is [..]. $rem")  if $dst eq q{..};
        $s->e("Directory is [../]. $rem") if $dst eq q{../};
        push @cmd, { cmd => "rm -rf $dst", verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 2. If git directory do not exists and source exists: clone it
    elsif ( not -e $dst and $c->{source} ) {
        my $v   = "$pfx [$dst] do not exist: should be cloned";
        my $cmd = "sudo -u $c->{owner} i $git_clone";
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},     verbose => '' };
        push @cmd, { cmd => qq{chown -R $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp -R $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 3. If git directory do exists and .git not: clone it
    elsif ( -d $dst and $c->{source} and not -d "$dst/.git" ) {
        my $v = "$pfx [$dst] do exist and dst/.git missing: should be cloned";
        my $cmd = "sudo -u $c->{owner} $git_clone";
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},     verbose => '' };
        push @cmd, { cmd => qq{chown -R $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp -R $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 4. If git dir exists and ensure = latest and not clean, then pull it
    elsif ( -d $dst and $c->{ensure} eq 'latest' and not $clean ) {
        my $v = $s->c( 'no', "$pfx [$dst] do exist: should be pulled" );
        my $cmd = "sudo -u $c->{owner} $git_pull";
        push @cmd, { cmd => $cmd, verbose => $v };
        $return = 0;
    }

    # 5. If we have mode and the mode is not correct
    elsif ( defined $got_mode and $got_mode ne $c->{mode} ) {
        my $v   = "$pfx [$dst] has mode and mode is wrong: change it";
        my $cmd = qq{chmod $c->{mode} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 6. If we have owner rand the owner is not correct
    elsif ( defined $got_owner and $got_owner ne $c->{owner} ) {
        my $v   = "$pfx [$dst] has owner and owner is wrong: change it";
        my $cmd = qq{chown -R $c->{owner} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 7. If we have group and the group is not correct
    elsif ( defined $got_group and $got_group ne $c->{group} ) {
        my $v   = "$pfx [$dst] has group and group is wrong: change it";
        my $cmd = qq{chgrp -R $c->{group} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 8.else
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

