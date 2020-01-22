# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Bootstrap                                        |
# |                                                                           |
# | Provides bootstrap argument action                                        |
# |                                                                           |
# | Version: 0.1.3 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.3 2020-01-21 Christian Kuelker <c@c8i.org>                            |
# |     - [class] section now in bootstrapped configuration                   |
# |     - create host.ini with --main-configuration-only                      |
# |     - create .gitconfig with --main-configuration-only                    |
# |     - add class sections in host.ini                                      |
# |                                                                           |
# | 0.1.2 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.1 2019-12-11 Christian Kuelker <c@c8i.org>                            |
# |     - add creation of ~/.gitconfig                                        |
# |                                                                           |
# | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::Bootstrap;

# ABSTRACT: Provides bootstrap argument action

use Cwd qw(cwd);
use Data::Dumper;
use File::Touch;
use Moose;
use namespace::autoclean;
use Template;
use Deploy::Ningyou::Facter;

has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, do not seem to work with Module::Pluggable
);

has 'rep_dir' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_rep_dir',
    writer  => '_set_rep_dir',
    default => 'deploy',
);

with qw(
    Deploy::Ningyou::Env
    Deploy::Ningyou::Util
    Deploy::Ningyou::Util::Action
    Deploy::Ningyou::Host
);

our $VERSION = '0.1.3';

# === [ main ] ================================================================
sub register { return 'bootstrap'; }

# subroutine input options
# parameter => 1=mandatory|0=optional
sub parameter             { return { opt => 1 }; }
sub parameter_description { return { opt => 'commandline options' }; }

# configuration input options
# param => description
sub attribute             { return {}; }
sub attribute_description { return {}; }

sub apply {
    my ( $s, $i ) = @_;
    my $opt = exists $i->{opt} ? $i->{opt} : $s->e( "no [opt]", 'sp' );
    my $rep = exists $i->{rep} ? $i->{rep} : $s->e( "no [rep]", 'sp' );

    # 1. check configuration is NOT present
    my $fn = "$ENV{HOME}/.ningyou.ini";
    $s->e( "Configuration already present [$fn]", 'removing' ) if -f $fn;
    $s->p("Using configuration file name [$fn]\n");

    # 2. create main configuration
    touch( ($fn) ) or $s->e( "$!! Can not create [$fn]", 'permission' );
    $s->e( "$!! Can not create [$fn]", 'permission' ) if not -f $fn;
    $s->e( "No `facter`", 'facter' ) if not -f '/usr/bin/facter';
    my $fqhn = $s->get_facter_fqhn;              # fully qualified host name
    my $nf   = Deploy::Ningyou::Facter->new();
    my $dist = $nf->get_facter_distribution;

    my $dir = cwd or $s->e( "Can not change to current directory", 'no_dir' );
    $dir
        = ( defined $rep and $rep ne q{} ) ? $rep : "$dir/" . $s->get_rep_dir;
    $dir =~ s{//}{/}gmx;    # in case / there will be //deploy
    $s->d("worktree dir [$dir]");

    my %config = (
        VARIABLES => {
            PROJECT       => $s->get_project_version,
            CONFIGURATION => $s->get_configuration_version,
            DISTRIBUTION  => $dist,
            WORKTREE      => $dir,
            FQHN          => $fqhn,
        }
    );
    my $mt    = Template->new( \%config ) || die Template->error(), "\n";
    my $mtpl  = $s->ningyou_ini();
    my $mvars = { VERSION => $Deploy::Ningyou::Action::Bootstrap::VERSION, };
    my $mr = $mt->process( \$mtpl, $mvars, $fn ) || die $s->e( $mt->error() );
    $s->e( "Problem found when creating $fn", 'permission' ) if not $mr;
    $s->p("Created configuration file [$fn]\n") if $mr;

    my $sw = 'main-configuration-only';
    my $main = ( exists $opt->{$sw} and $opt->{$sw} ) ? 1 : 0;

    # 3.0 check of git configuration is present, of not create
    #     does not make sense to create worktree without git configuration
    my $gcfn = "$ENV{HOME}/.gitconfig";
    if ( -f $gcfn ) {
        $s->p("git configuration [$gcfn] exists\n");
    }
    else {
        touch( ($gcfn) )
            or $s->e( "$!! Can not create [$gcfn]", 'permission' );
        my $gct    = Template->new( \%config ) || die Template->error(), "\n";
        my $gctpl  = $s->gitconfig_ini();
        my $gcvars = {
            VERSION => $Deploy::Ningyou::Action::Bootstrap::VERSION,
            USER    => $ENV{USER},
            FQHN    => $fqhn,
        };
        my $gcr = $gct->process( \$gctpl, $gcvars, $gcfn )
            || die $s->e( $gct->error() );
        $s->p("Created configuration file [$gcfn]\n") if $gcr;
    }

    my $repo = "$dir/$dist";
    my $mode = 0750;
    if ( not $main ) {

        # 3.1 check work tree is NOT present
        $s->e( "Work tree already present [$dir]", 'removing' ) if -d $dir;
        $s->p("Bootstrapping Ningyou to work tree [$dir]\n");

        # 4. create work tree
        mkdir $dir;
        chmod $mode, $dir;
        $s->e( "$!! Can not create [$dir]", 'permission' ) if not -d $dir;
        $s->p("Created work tree [$dir]\n") if -d $dir;

        # 5. create distribution
        mkdir $repo;
        chmod $s->e( "$!! Can not create [$repo]", 'permission' )
            if not -d $repo;
        $s->p("Created distribution [$repo]\n") if -d $repo;

        # 6. git init
        my $cmd = qq{cd $dir && git init};
        my @o   = qx($cmd)
            or die $s->e( "$!! Can not initialize git repository",
            'permission' );
        foreach my $o (@o) { $s->p($o); }
    }    # not main

    # 7. create host configuration with main and without
    my $hfn = "$dir/$fqhn.ini";
    $s->p("Using host file name [$hfn]\n");
    my $ht    = Template->new( \%config ) || die Template->error(), "\n";
    my $htpl  = $s->host_ini();
    my $hvars = { VERSION => $Deploy::Ningyou::Action::Bootstrap::VERSION, };
    my $hr    = $mt->process( \$htpl, $hvars, $hfn )
        || die $s->e( $ht->error() );
    $s->e( "Problem found when creating $hfn", 'permission' ) if not $hr;
    $s->p("Created host file [$hfn]\n") if $hr;
    my $cm   = "+ host configuration $fqhn";
    my $hcmd = qq{cd $dir&&git add $hfn;git commit -m '$cm' $hfn};
    $s->d($hcmd);
    my $ho = qx($hcmd);
    $s->p($ho);

    my @dir = ();
    if ( not $main ) {

        # 8. create more directories
        push @dir, "$dir/global";
        push @dir, "$dir/global/modules";
        push @dir, "$dir/global/modules/ningyou";
        push @dir, "$dir/global/modules/ningyou/files";
        push @dir, "$dir/global/modules/ningyou/manifests";

        #push @dir, "$repo/modules";
        #push @dir, "$repo/modules/default";
        #push @dir, "$repo/modules/default/files";
        #push @dir, "$repo/modules/default/manifests";
        #push @dir, "$dir/$fqhn";
        #push @dir, "$dir/$fqhn/modules";
        #push @dir, "$dir/$fqhn/modules/default";
        #push @dir, "$dir/$fqhn/modules/default/files";
        #push @dir, "$dir/$fqhn/modules/default/manifests";
        foreach my $d (@dir) {
            $s->p("Crate directory [$d]\n");
            mkdir $d;
            $s->e( "$!! Can not create [$d]", 'permission' ) if not -d $d;
        }

        # 9. create default module at 3 locations
        my @default = (
            "$dir/global/modules/default/manifests/default.ini",
            "$repo/modules/default/manifests/default.ini",
            "$dir/$fqhn/modules/default/manifests/default.ini",
        );
        foreach my $dfn (@default) {
            next;    # disbaled for the moment
            $s->p("Using default manifest file name [$dfn]\n");
            my $dt = Template->new( \%config ) || die Template->error(), "\n";
            my $dtpl  = $s->default_ini();
            my $dvars = {
                VERSION  => $Deploy::Ningyou::Action::Bootstrap::VERSION,
                FILENAME => $dfn
            };
            my $dr = $dt->process( \$dtpl, $dvars, $dfn )
                || die $s->e( $dt->error() );
            $s->e( "Problem found when creating $dfn", 'permission' )
                if not $dr;
            $s->p("Created manifest file [$dfn]\n") if $dr;
            my $dcmd
                = qq{cd $dir&&git add $dfn;git commit -m "+ module manifest $dfn" $dfn};
            $s->d($dcmd);
            my $do = qx($dcmd);
            $s->p($do);
        }

        # 10. create ningyou module at 1 location
        my @ningyou
            = ( "$dir/global/modules/ningyou/manifests/ningyou.ini", );
        foreach my $dfn (@ningyou) {
            $s->p("Using ningyou manifest file name [$dfn]\n");
            my $dt = Template->new( \%config ) || die Template->error(), "\n";
            my $dtpl  = $s->ningyou_module_ini();
            my $dvars = {
                VERSION  => $Deploy::Ningyou::Action::Bootstrap::VERSION,
                FILENAME => $dfn
            };
            my $dr = $dt->process( \$dtpl, $dvars, $dfn )
                || die $s->e( $dt->error() );
            $s->e( "Problem found when creating $dfn", 'permission' )
                if not $dr;
            $s->p("Created manifest file [$dfn]\n") if $dr;
            my $cstr = "+ module manifest $dfn";
            my $dcmd = qq{cd $dir&&git add $dfn;git commit -m "$cstr" $dfn};
            $s->d($dcmd);
            my $do = qx($dcmd);
            $s->p($do);
        }
    }    # not main
    return 1;
}

sub ningyou_ini {

    return <<'END_INI';
; +---------------------------------------------------------------------------+
; | ningyou.ini => ~/.ningyou.ini                                             |
; |                                                                           |
; | Main configuration for Ningyou                                            |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
;
; Valid sections are: [version], [global]
;
; Valid parameters for section [version]: project, configuration, file
;
; Valid parameters for section [global]: worktree
;
[version]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

[class]
server=0
client=0
x11=0

[global]
worktree=[% WORKTREE %]

[system]
fqhn=[% FQHN %]

[os]
distribution=[% DISTRIBUTION %]
; package manager cache time to live, default 3600 = 1h
pm_cache_ttl=3600

END_INI

}

sub host_ini {

    return <<'END_HOST_INI';
; +---------------------------------------------------------------------------+
; | host.ini (actual name is FQHN)                                            |
; |                                                                           |
; | Configuration for one host                                                |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-03-30 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
[version]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

[global]
; distribution independent modules
; active modules = 1
; inactive modules = 0
ningyou=1

[client]
; base software, similar to global

[server]
; headless client

[x11]
; desktop, laptop

[[% DISTRIBUTION %]]
; distribution [% DISTRIBUTION %] dependent modules

[[% FQHN %]]
; host [% FQHN %] dependent modules

END_HOST_INI

}

sub default_ini {

    return <<'DEFAULT_INI';
; +---------------------------------------------------------------------------+
; | modules/default/manifests/default.ini                                     |
; |                                                                           |
; | Configuration for default module.                                         |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-03-30 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
;
[version:default]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

;[nop:default]
; the 'nop' provider provides a 'no operation' - nothing
; can be used to check (via debug) if configuration section is actually used
;debug=NOP default [% FILENAME %]

DEFAULT_INI

}

sub ningyou_module_ini {

    return <<'NINGYOU_MODULE_INI';
; +---------------------------------------------------------------------------+
; | modules/ningyou/manifests/ningyou.ini                                     |
; |                                                                           |
; | Configuration for a Ningyou module. The aim is not to install Ningyou,    |
; | but to keep its dependencies up to date.                                  |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-07-24 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
;
; --- [ 1st dependencies ] ----------------------------------------------------
[package:aptitude]
ensure=latest
[package:libmoose-perl]
ensure=latest
[package:libmodule-pluggable-perl]
ensure=latest
[package:libconfig-tiny-perl]
ensure=latest
[package:libfile-dircompare-perl]
ensure=latest
[package:liblist-compare-perl]
ensure=latest
[package:libnamespace-autoclean-perl]
ensure=latest
[package:libtemplate-perl]
ensure=latest
[package:libcapture-tiny-perl]
ensure=latest
[package:libapt-pkg-perl]
ensure=latest
[package:libconfig-ini-perl]
ensure=latest
[package:libfile-touch-perl]
ensure=latest
[package:libgraph-perl ]
ensure=latest
[package:libtest-deep-perl]
ensure=latest
[package:facter]
ensure=latest

; --- [ 2nd dependencies ] ----------------------------------------------------
; need for ::Provider::
[package:git]
ensure=latest
[package:rsync]
ensure=latest
NINGYOU_MODULE_INI
}

sub gitconfig_ini {
    return <<"GITCONFIG";
# This is Git's per-user configuration file. Created by ningyou bootstrap.
[user]
# Please adapt the following lines:
        name = [% USER %] ([% FQHN %])
        email =[% USER %]@[% FQHN %]
GITCONFIG
}

__PACKAGE__->meta->make_immutable;

1;
__END__

