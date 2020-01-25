# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Git                                            |
# |                                                                           |
# | Provides git deployment                                                   |
# |                                                                           |
# | Version: 0.1.2 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.2 2020-01-25 Christian Kuelker <c@c8i.org>                            |
# |     - fix git pull permissions                                            |
# |     - fix git status permissions                                          |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
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

our $VERSION = '0.1.2';

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
# provided by Deploy::Ningyou::Attribute::*
sub attribute_description {
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

sub init   { return 1; }
sub script { return 0; }

sub apply {
    my ( $s, $i ) = @_;
    $s->d("use standard apply");
    return $s->standard_apply($i);
}

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
    my @cmd    = @{ $s->get_cmd };    # set by applied_in
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
    my $git_porcelain
        = qq{git -C $dst status --untracked-files=no --porcelain};
    my $sudo = $c->{owner} eq 'root' ? q{} : qq{sudo -u $c->{owner} -i };
    my $git_por = qq{output=\$($sudo $git_porcelain) && [ -z "\$output" ]};

    if ( -d $dst and -d "$dst/.git" ) {    # we have a git repo
        $s->d("Section A - test clean");

        # gives 255 on unclean and 0 on clean
        my $cmd = $git_por;
        $s->d("cmd [$cmd]");
        my ( $out, $err, $res ) = $s->execute($cmd);
        $clean = $res ? 0 : 1;
        $s->d("$cmd: $out, $err, $res => $clean");
    }
    $s->d("clean 1 [$clean]\n");

    # test if remote origin has updated
    # https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
    my $git_status = qq{git -C $dst status -uno};
    my $git_update = qq{git -C $dst remote update};
    if ( -d $dst and -d "$dst/.git" and $clean ) {
        $s->d("Section A - test clean - remote");
        my $cmd0
            = $c->{owner} eq 'root'
            ? $git_update
            : qq{sudo -u $c->{owner} -i $git_update};
        $s->d("cmd0 [$cmd0]");
        my ( $out0, $err0, $res0 ) = $s->execute_quite($cmd0);
        chomp $out0;
        $s->d(
            "RESULT 0:\n\tcmd[$cmd0]\n\tout0[$out0]\n\terr0[$err0]\n\tres0[$res0] => $clean"
        );
        my $cmd1
            = $c->{owner} eq 'root'
            ? $git_status
            : qq{sudo -u $c->{owner} -i $git_status};
        $s->d("cmd1 [$cmd1]");
        my ( $out1, $err1, $res1 ) = $s->execute_quite($cmd1);
        chomp $out1;
        $out1 =~ s{\n}{ }gmx;
        $out1 =~ s{\s+}{ }gmx;
        $s->d(
            "RESULT 1:\n\tcmd[$cmd1]\n\tout1[$out1]\n\terr1[$err1]\n\tres1[$res1] => $clean"
        );

        #                     Your branch is up to date
        $clean
            = ( $out1 =~ m/Your\s+branch\s+is\s+up\s+to\s+date/gmx ) ? 1 : 0;
        $s->d(
            "RESULT 2:\n\tcmd[$cmd1]\n\tout1[$out1]\n\terr1[$err1]\n\tres1[$res1] => $clean"
        );
    }
    $s->d("clean 2 [$clean]\n");

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

    $s->d("source [$c->{source}]");
    my $verbose = $s->get_verbose($i);
    $s->d("verbose [$verbose]\n");
    my $pfx       = "  => git";
    my $git_clone = "git --no-pager clone '$c->{source}' '$dst'";
    $git_clone .= " --quiet" if not $verbose;
    my $git_pull = "git -C '$dst' --no-pager pull";
    $git_pull .= " --quiet" if not $verbose;

    $s->d("section C");

    # C action
    # 1. If git directory exists and it should be removed:
    if ( -e $dst and $c->{ensure} eq 'missing' ) {
        $s->d("section C 1");
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
        $s->d("section C 2");
        my $v = "$pfx [$dst] do not exist: should be cloned";
        my $cmd
            = $c->{owner} eq 'root'
            ? $git_clone
            : "sudo -u $c->{owner} -i $git_clone";
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},     verbose => '' };
        push @cmd, { cmd => qq{chown -R $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp -R $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 3. If git directory do exists and .git not: clone it
    elsif ( -d $dst and $c->{source} and not -d "$dst/.git" ) {
        $s->d("section C 3");
        my $v = "$pfx [$dst] do exist and dst/.git missing: should be cloned";
        my $cmd
            = $c->{owner} eq 'root'
            ? $git_clone
            : "sudo -u $c->{owner} $git_clone";
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        push @cmd, { cmd => qq{chmod $c->{mode} $dst},     verbose => '' };
        push @cmd, { cmd => qq{chown -R $c->{owner} $dst}, verbose => '' };
        push @cmd, { cmd => qq{chgrp -R $c->{group} $dst}, verbose => '' };
        $return = 0;
    }

    # 4. If git dir exists and ensure = latest and not clean, then pull it
    elsif ( -d $dst and $c->{ensure} eq 'latest' and not $clean ) {
        $s->d("section C 4");
        my $v = $s->c( 'no', "$pfx [$dst] do exist: should be pulled" );
        my $cmd
            = $c->{owner} eq 'root'
            ? $git_pull
            : "sudo -u $c->{owner} $git_pull";
        push @cmd, { cmd => $cmd, verbose => $v };
        $return = 0;
    }

    # 5. If we have mode and the mode is not correct
    elsif ( defined $got_mode and $got_mode ne $c->{mode} ) {
        $s->d("section C 5");
        my $v   = "$pfx [$dst] has mode and mode is wrong: change it";
        my $cmd = qq{chmod $c->{mode} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 6. If we have owner and the owner is not correct
    elsif ( defined $got_owner and $got_owner ne $c->{owner} ) {
        $s->d("section C 6");
        my $v   = "$pfx [$dst] has owner and owner is wrong: change it";
        my $cmd = qq{chown -R $c->{owner} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 7. If we have group and the group is not correct
    elsif ( defined $got_group and $got_group ne $c->{group} ) {
        $s->d("section C 7");
        my $v   = "$pfx [$dst] has group and group is wrong: change it";
        my $cmd = qq{chgrp -R $c->{group} $dst};
        push @cmd, { cmd => $cmd, verbose => $s->c( 'no', $v ) };
        $return = 0;
    }

    # 8.else
    else {
        $s->d("section C 8");
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

