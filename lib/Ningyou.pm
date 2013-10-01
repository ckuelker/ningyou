package Ningyou;

# ABSTRACT: clear reproducible system administration

use utf8;                        # so literals and identifiers can be in UTF-8
use v5.12;                       # or later to get "unicode_strings" feature
use strict;                      # quote strings, declare variables
use warnings;                    # on by default
use warnings qw(FATAL utf8);     # make encoding glitches fatal
use open qw(:std :utf8);         # undeclared streams in UTF-8
use charnames qw(:full :short);  # unneeded in v5.16

use Config::INI::Reader;         #use Config::Any;
use Data::Dumper;
use Encode qw(decode_utf8);
use File::Basename;
use File::Find;
use Moose;
use namespace::autoclean;
use Ningyou::Cmd;
use Ningyou::Util;
use Ningyou::Options;
our $VERSION = '0.0.3';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# command line options
has 'options' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_options',
    writer  => 'set_options',
    default => sub { return {}; },
    lazy    => 1,
);

has 'provided' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Bool]',
    default => sub { return { 'package:ningyou' => 1 }; },
    handles => {
        has_provided    => 'exists',
        is_provided     => 'defined',
        ids_provided    => 'keys',
        get_provided    => 'get',
        set_provided    => 'set',
        num_provided    => 'count',
        is_not_provided => 'is_empty',
        del_provided    => 'delete',
        provided_pairs  => 'kv',
    },
);
has 'planned' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Bool]',
    default => sub { return {}; },
    handles => {
        has_planned    => 'exists',
        is_planned     => 'defined',
        ids_planned    => 'keys',
        get_planned    => 'get',
        set_planned    => 'set',
        num_planned    => 'count',
        is_not_planned => 'is_empty',
        del_planned    => 'delete',
        planned_pairs  => 'kv',
    },
);

has 'command' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { return []; },
    handles => {
        all_commands    => 'elements',
        add_command     => 'push',
        map_commands    => 'map',
        filter_commands => 'grep',
        find_command    => 'first',
        get_command     => 'get',
        join_commands   => 'join',
        count_commands  => 'count',
        has_commands    => 'count',
        has_no_commands => 'is_empty',
        sorted_commands => 'sort',
    },
);

# 'directory:/home/c/bin',
#     bless( {
#         module => {
#            'owner' => 'c',
#            'source' => 'ningyou:///modules/home-bin/bin',
#            'require' => 'package:zsh',
#            'mode' => 'Fo-x',
#            'group' => 'c',
#            'recurse' => 'true',
#            'purge' => '1',
#            'module' => 'home-bin'
#        }
#    }, 'Ningyou::Type::Module' )
has 'cfg' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Ningyou::Type::Module]',
    default => sub { return {}; },
    handles => {
        has_cfg    => 'exists',
        is_cfg     => 'defined',
        ids_cfg    => 'keys',
        get_cfg    => 'get',
        set_cfg    => 'set',
        num_cfg    => 'count',
        is_not_cfg => 'is_empty',
        del_cfg    => 'delete',
        cfg_pairs  => 'kv',
    },
);
has 'master' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { return {}; },
    handles => {
        has_master    => 'exists',
        is_master     => 'defined',
        ids_master    => 'keys',
        get_master    => 'get',
        set_master    => 'set',
        num_master    => 'count',
        is_not_master => 'is_empty',
        del_master    => 'delete',
        master_pairs  => 'kv',
    },
);

# global data

# global data to store status
my $mode       = q{};           # command
my $modules_ar = [];            # moduls
my $modules    = q{};           # moduls
my $f          = {};            # facts about system
my @str        = ();            # commands (in order)
my $str        = {};            # commands
my $cache      = {};
my $cfg_fn     = q{};
my $wt         = '/dev/null';   # work tree
my $cfg        = {};            # global cfg space
my $pkg        = {};            # pkg from cfg that should be installed or not
my $repository = 'none';
my $provider   = {};            # file, git, ...

sub run {
    my ( $s, $i ) = @_;

    # prepare options
    my $opt = Ningyou::Options->new;
    $opt->process_options;
    my $o = $opt->get_options;
    $s->set_options($o);        # set for Ningyou::Out ...
    $mode       = $opt->get_command;
    $modules_ar = $opt->modules;
    $modules    = join q{ }, @{$modules_ar};

    # prepare facts
    my $u = Ningyou::Util->new;
    $f = $u->get_facts;

    # prepare configuration
    $cfg_fn
        = ( exists $o->{configuration} and defined $o->{configuration} )
        ? $o->{configuration}
        : '~/.ningyou/master.ini';
    $cfg = $s->get_or_setup_cfg($cfg_fn);

    # update system package meta data
    if ( exists $cfg->{status}->{packages}
        and $cfg->{status}->{packages} eq 'always-update-on-start'
        or exists $o->{update} )
    {
        system('aptitude update');
    }

    # print preamble
    $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->o("Ningyou v$VERSION for [$f->{fqdn}]\n");
    $s->o("use master configuration: $cfg_fn\n");
    $s->o("use mode: $mode\n");
    $s->o("use module: $modules\n") if $modules ne q{};
    $s->o("use repository: $repository\n");    # linux-debian-wheezy
    $s->o("use work tree: $wt\n");    # /home/c/g/ningyou/linux-.../modules

    # prepare print used modules
    my $dot = q{ } . '.' x 70;
    my $dl  = 68 - $o->{indentation};

    # print used modules and read its configuration
    $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->o("Modules concidered processing: (switch on/off via master.ini)\n");
    my @modules = ();
    if ( $modules ne q{} and $modules ne 'all' ) {
        @modules = @{$modules_ar};
    }
    else {
        @modules = @{ $s->read_modules() };
    }
    foreach my $mo ( sort @modules ) {
        chomp $mo;
        $mo =~ s{^$wt/}{}gmx;    #/home/c/g/wt/modules/zsh -> zsh
        my $md = $mo . $dot;
        if ( $s->should_be_installed($mo) ) {
            $s->o( sprintf( "%-$dl.${dl}s [ %s ]\n", $md, 'YES' ) );
            $s->read_module($mo);
        }
        else {
            $s->o( sprintf( "%-$dl.${dl}s [ %s ]\n", $md, 'NO ' ) );
        }
    }

    # make a query, print verbose query
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
    my $unprovided = $s->query_unprovided();

    # make a valiatation, print verbose valiatation
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" ) if $unprovided;
    $s->planning($unprovided) if $unprovided;

    # print result
    $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->v("Verbose results:\n");
    $s->v("  number of tested objects: $unprovided\n");
    $s->v(
        "  number of modules to update: " . $s->count_commands / 2 . "\n" );
    $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );

    if ($unprovided) {
        $s->action();    # do action if any
        if ( $mode eq 'show' ) {
            $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
            $s->o("To install execute:($unprovided)\n");
            $s->o("# ningyou install $modules\n");
        }
    }
    else {
        $s->o("Ningyou is already up-to-date\n");
    }

    $s->d("END\n");
    return 1;
}

sub get_or_setup_cfg {
    my ( $s, $cfg_fn ) = @_;

    my $fn = glob $cfg_fn;    # master cfg (~/.ningyou/master.ini)
    my $d  = dirname($fn);

    die "please provide directory $d\n"                if not -d $d;
    die "please provide master configuration $d/$fn\n" if not -e $fn;
    $cfg        = Config::INI::Reader->read_file($fn);
    $repository = $s->get_repository( $cfg, $f->{fqdn} );
    $wt         = $s->get_worktree( $cfg, $repository );
    die "please provide working tree $wt\n" if not -d $wt;
    $provider = $cfg->{provider};

    return $cfg;
}

sub get_repository {
    my ( $s, $c, $d ) = @_;    #  c = cfg (master), d = fqdn

    my $m = "ERROR: Node [$d] not mentioned in section [nodes]\n";
    $m .= "Please add node to master.ini\n";
    my $r = exists $c->{nodes}->{$d} ? $c->{nodes}->{$d} : die $m;
    $s->d("use repository: $r\n");

    return $r;
}

sub get_worktree {
    my ( $s, $c, $r ) = @_;    # c = cfg (master), r = repository name

    my $se = 'repositories';
    my $m  = "ERROR: a repository called '$r' is\n";
    $m .= "not mentioned in section [$se]!\n";
    $m .= "Please add repository to master.ini\n";
    my $wt = exists $c->{$se}->{$r} ? $c->{$se}->{$r} : die $m;
    $s->d("use worktree: $wt\n");

    return $wt;
}

# query OBJECTs of PROVIDER if installed or not
# returns number of unprovided objects
sub query_unprovided {
    my ( $s, $i ) = @_;
    return if $mode eq 'full-show';
    return if $mode eq 'full-script';

    my $unprovided   = 0;
    # foreach provider: File, Directory, ...
    $s->v("Start query: what is already provided and what not ...\n");
    $s->d("Foreach entry id (provider:object)\n");
    foreach my $id ( $s->ids_cfg ) {    # id = provider:object
        my ( $pr, $iv ) = $s->id($id);
        my $provided = $s->check_provided($id);
        $unprovided++ if not $provided;
    }
    return  $unprovided;
}

sub check_provided {
    my ( $s,  $id ) = @_;
    my ( $pr, $iv ) = $s->id($id);
    my $o = $s->get_options;
    $s->v("- Q: do provider [$pr] provide object [$iv]?\n");
    my $msg
        = "ERROR: provider [$pr] not supported!\n"
        . "Please install the provider Ningyou::Provider::"
        . ucfirst $pr
        . "\nand consider adding it at"
        . " section [providers] in master.ini\n";
    die $msg if not exists $provider->{$pr};
    my $module = "Ningyou::Provider::" . ucfirst $pr;
    eval "use $module";
    die $@ if defined $@ and $@;
    my $p = $provider->{$pr}->new( { options => $o } );

    my $cfg
        = ( $s->is_cfg($id) and exists $s->get_cfg($id)->{module} )
        ? $s->get_cfg($id)->{module}
        : {};

    my $is_provided = $p->installed(
        {
            cfg      => $cfg,     #$r->{$pr}->{$iv},
            object   => $iv,
            provider => $pr,
            cache    => $cache,
            wt       => $wt,
            dryrun   => 1,
            itemize  => 1,
            base     => '-a',
        }
    );
    if ($is_provided) {
        $s->set_provided( "$pr:$iv" => 1 );
        $s->v("- A: [YES] [$iv] allready provied\n");
    }
    else {
        $s->set_provided( "$pr:$iv" => 0 );
        $s->v("- A: [NO] [$iv] not provied\n");
        my $cmd = $p->install(
            {

                # mandatory
                cache    => $cache,
                object   => $iv,
                provider => $pr,
                cfg      => $cfg,
                wt       => $wt,
            }
        );
        if ( defined $cmd ) {
            $s->v("add cmd [$cmd]");
            my $mo = $cfg->{module};
            my $y  = "=" x 78;
            my $x  = sprintf( "# === module [%s] === object [%s] ===%s",
                $mo, $id, $y );
            $s->add_command( sprintf( "%-.74s", $x ) );
            $s->add_command($cmd);
        }
        else {
            $s->v("no cmd from install\n");
        }
    }

    return $is_provided;
}

# The validate
# TODO: this is testing the dependency chain only 1 level deep
#       and only for normal providers
#       - consider to make it "indefinte" deep
#       - consider to add provider "Module"
sub planning {
    my ( $s, $i ) = @_;
    my %queue = ();

    foreach my $id ( $s->ids_cfg ) {
        my ( $pr, $iv ) = $s->id($id);

        $s->v("- Q: Should object [$iv] be provided via [$pr]?\n");
        if ( $s->get_provided($id) ) {
            $s->v("- A: [NO] Should not be provided via [$pr]\n");
            next;
        }
        else {
            $s->v("- A: [YES] Should be provided via [$pr]\n");
            my $mo = $s->get_cfg($id)->{module}->{module};
            $s->v("- Q: What dependecies has [$id]?\n");
            foreach my $dep_id ( $s->get_dependencies($id) ) {
                die "Invalid dependency in module [$mo]"
                    if not $dep_id =~ m{:}gmx;
                $s->v("- A: [$id] has dependency [$dep_id]\n");
                $s->check_provided($dep_id);
            }
        }
    }
    return 0;
}

sub validate {
    my ( $s, $i ) = @_;
    my $r = {};    # TODO

    my $p  = "validate: ";
    my $oq = scalar(@str);
    my $q  = scalar(@str);

    # z = complexity
    my $n = 0;
    $s->v("Validate requirements of provider ...\n");
    $s->v("Foreach complexity 0..999999\n");
    foreach my $z ( 0 .. 999999 ) {    # TODO make 99 a cfg val
        $s->v("- entering complexity [$n], command counter [$q]\n");
        $n++;
        $oq = $q;                      # old copy of nr of actions
        $q  = scalar(@str);            # nr of actions
        last if $q == $oq and $q > 0;                # stop if something to do
        last if $q == $oq and $q == 0 and $z > 0;    # stop if nothing todo
        $s->d("z [$z] [$q]\n");

        # pr(provider): file, directory, package
        $s->v("  Foreach provider (file, directory, package, ...)\n");
        foreach my $pr ( sort keys %{$r} ) {
            $s->v("  - validate requirements of provider [$pr] ...\n");
            next if $pr eq 'default';    # we do not need to install 'default'

            # vi: zsh, /tmp/file, /tmp/dir, ...
            $s->v("    Foreach object (zsh, /tmp/file, /tmp/dir, ...)\n");
            foreach my $iv ( sort keys %{ $r->{$pr} } ) {
                my $id = "$pr:$iv";
                $s->v("    - object [$iv]\n");
                my $mo = $r->{$pr}->{$iv}->{module};    # module
                if ( $s->is_provided($id) ) {
                    $s->v("A: [$iv] allready provided via [$pr] at [$mo]\n");
                    next;
                }
                if ( $s->is_planned($id) ) {
                    $s->v("A: [$iv] allready planned via [$pr] at [$mo]\n");
                    next;
                }

                $s->v("Q: Can [$mo] provide [$iv] via [$pr]?\n");
                my $so
                    = exists $r->{$pr}->{$iv}->{source}
                    ? $r->{$pr}->{$iv}->{source}
                    : undef;
                $s->v("           source points to [$so]\n")
                    if defined $so;

               # DIRECTORY with SOURCE
               # we want to skip chmod, chown and chgrp  in case source exists
               # (means we use rsync) because chmod,chown and chgrp would be
               # set # to the source owner, which might be not root. In those
               # cases /usr/local might become local user as owner.
                if (
                        $s->all_require_ok($id)
                    and $pr eq 'directory'
                    and defined $so
                    and $s->has_provided(
                        $id)    # exists $info->{$pr}->{$iv}->{installed}
                    and not $s->is_provided($id)
                    )           #   $info->{$pr}->{$iv}->{installed} )
                {
                    $s->store( $pr, $iv );
                    $s->v("A: [YES] [$iv] to [$so] as [$pr] via rsync\n");

                    #$info->{$pr}->{$iv}->{planned} = 1;
                    $s->set_planned( $id => 1 );
                }
                elsif (
                       $s->all_require_ok($id) and $pr eq 'directory'
                    or $pr eq 'file'
                    and $s->has_provided(
                        $id)    #exists $info->{$pr}->{$iv}->{installed}
                    and not $s->is_provided($id)
                    )           #$info->{$pr}->{$iv}->{installed} )
                {
                    if ( defined $so ) {
                        $s->v("A: [YES] [$iv] to [$so] as [$pr]\n");
                    }
                    else {
                        $s->v("A: [YES] [$iv] as [$pr]\n");
                    }
                    $s->store( $pr, $iv );

                    #$info->{$pr}->{$iv}->{planned} = 1;
                    $s->set_planned( $id => 1 );
                    if ( exists $r->{$pr}->{$iv}->{ensure}
                        and $r->{$pr}->{$iv}->{ensure} ne 'removed' )
                    {
                        $s->v("A: [YES] allready done by provider\n");
                    }
                    else {
                        $s->v(
                            "A: [YES] provision will be done by [removal]\n"
                        );
                    }
                }
                elsif (
                    $s->all_require_ok($id)
                    and $s->has_provided(
                        $id)    #exists $info->{$pr}->{$iv}->{installed}
                    and not $s->is_provided($id)
                    )           # $info->{$pr}->{$iv}->{installed} )
                {
                    if ( defined $so and $so ) {
                        $s->v("A: [YES] [$iv] to [$so] as [$pr]\n");
                    }
                    else {
                        $s->v("A: [YES] [$iv] as [$pr]\n");

                    }
                    $s->store( $pr, $iv );

                    #$info->{$pr}->{$iv}->{planned} = 1;
                    $s->set_planned( $id => 1 );
                }
                else {

# Why $so is not defined? $s->v( "    no, dependency not met or is allready provided for [$iv] to [$so] as [$pr]\n"
                    $s->v("A: [NO], \n");
                    $s->v("   dependency not met or is allready provided");
                    $s->v("   for [$iv] to [?] as [$pr]\n");
                }
            }
        }
    }
    return $n;
}

sub should_be_installed {
    my ( $s, $mo ) = @_;

    return 1 if ( exists $pkg->{$mo} );
    $pkg->{$mo} = 0;

    # if should be installed globally: [packages]
    $pkg->{$mo}++
        if ( exists $cfg->{packages}->{$mo}
        and $cfg->{packages}->{$mo} );

    # if should be installed for repository
    $pkg->{$mo}++
        if ( exists $cfg->{$repository}->{$mo}
        and $cfg->{$repository}->{$mo} );

    # if it should be installed for client
    $pkg->{$mo}++
        if exists $cfg->{ $f->{fqdn} }->{$mo}
            and $cfg->{ $f->{fqdn} }->{$mo};
    return $pkg->{$mo};
}

sub action {
    my ($s) = @_;

    $s->d( Dumper($str) );
    my $o = $s->get_options;
    if ( $mode eq 'script' ) {
        $s->o("#\!/bin/sh\n");
        $s->o("# Ningyou v$VERSION action script\n");
        $s->o("# for [$f->{fqdn}] as [$repository]\n");
        $s->v(    "# number of modules to update: "
                . $s->count_commands / 2
                . "\n" );
        $s->o("# module name(s): $modules\n");
        $s->o("export WT=$wt\n");
    }
    else {
        if ( exists $o->{install} and $o->{install} ) {
            $s->o("the following commands will be executed:\n");
        }
        else {
            $s->o("the following commands would be executed:\n");
        }
    }
    my $z = 0;

    foreach my $cmd ( $s->all_commands ) {
        if (   $mode eq 'production'
            or $mode eq 'install' )
        {
            $s->o("execute: [$cmd]\n");
            my $nilicm = Ningyou::Cmd->new();
            $nilicm->cmd($cmd);
        }
        else {
            if ( not exists $o->{raw} ) {
                $cmd =~ s/^\s+//gmx;
                if ( $mode eq 'show' or $mode eq 'full-show' ) {
                    $cmd =~ s/^/# /gmx;
                }
                $cmd =~ s/$wt/\${WT}/gmx;
                $cmd =~ s/&&/&&\n/gmx;
            }
            if ( $mode eq 'show' or $mode eq 'full-show' ) {
                $cmd =~ s{\n}{\n    #}gmx;
            }
            else {
                $cmd =~ s{\n}{\n   }gmx;
            }
            $cmd =~ s{\s+\n}{\n}gmx;
            $s->o($cmd);
        }
        $z++;
    }
    if ( $mode eq 'script' or $mode eq 'full-script' ) {
        $s->o("# EOS - end of script\n");
    }

}

sub queue_add {

    #        pr=file   iv=/tmp/x  type=?  cmd=chmod 640 /home/c/.zshrc
    my ( $s, $pr, $iv, $type, $cmd ) = @_;
    if ( $str->{$pr}->{$iv}->{$type} ) {
        $s->d("[$iv] already in queue\n");
    }
    else {
        $s->d("queue add: [$cmd]\n");
        push @str, $cmd;

        # TODO: consider real values
        #$str->{$pr}->{$iv}->{$type} = 1;
        $str->{$pr}->{$iv}->{$type}->{$cmd} = 1;
    }
}

sub store {

    #        pr=object_type, iv=id_value
    #        pr=chown      , iv=/home/c/.zshrc
    #        file           /tmp/c    vim      src
    my ( $s, $pr, $iv ) = @_;

    #my $mo
    #    = exists $r->{$pr}->{$iv}->{module}
    #    ? $r->{$pr}->{$iv}->{module}
    #    : die "no pr [$pr], iv [$iv]";

    my $mo
        = ( $s->is_cfg( "$pr:$iv" => 'module' ) )
        ? $s->get_cfg( "$pr:$iv" => 'module' )
        : die "no pr [$pr], iv [$iv]";

    $s->v("      store [$iv] via [$pr] for [$mo]\n");
    die "Forget to add [$pr] to [provider] in master.ini?\n"
        if not exists $provider->{$pr};

    # This should not be needed:
    #    eval "use $provider->{$pr}";
    #    die $@ if defined $@ and $@;
    my $np  = $provider->{$pr}->new();
    my $cmd = $np->install(
        {

            # mandatory
            cache    => $cache,
            object   => $iv,
            provider => $pr,
            cfg      => $s->get_cfg("$pr:$iv"),    #$r->{$pr}->{$iv},
            wt       => $wt,

            # rsync
            dryrun  => 0,
            itemize => 0,
        }
    );
    $s->queue_add( $pr, $iv, $pr, $cmd )
        if not $cmd =~ m{^NOP};
}

# queries the 'require' field and deliver all  dependencies
# require FIELD format:
# 1. require=package:zsh
# 2. require=package:zsh;file:/tmp/zsh
# 3. require=package:zsh,vim
# 4. require=package:zsh,vim;file:/tmp/zsh,/tmp/vim
sub get_dependencies {
    my ( $s,  $id ) = @_;            # id = package:zsh
    my ( $pr, $iv ) = $s->id($id);

    # split first ";" => require=package:zsh,vim  |  file=/tmp/zsh,/tmp/vim
    return () if not exists $s->get_cfg($id)->{module}->{require};

    my @dependencies = ();
    my $dep_test     = $s->get_cfg($id)->{module}->{require};
    $s->d("test dependencies: [$dep_test]");
    my @dep_test = split /;/, $dep_test;    # package:x,y;file:a/b,c/d
    $s->d("Foreach dependency test id (package:zsh, ...)\n");
    foreach my $tid (@dep_test) {           # package:zsh,vim
        $s->v("  - Test dependency id [$tid]\n");
        my ( $pr, $str ) = $s->id($tid);
        $s->v("    id has provider [$pr]\n");
        my @d = ();
        if ( $str =~ m{,}gmx ) {            # if commata
            my @d = split /,/, $str;        # zsh,vim
            foreach my $iv (@d) {
                $s->v("     + add A dependency [$pr:$iv]\n");
                push @dependencies, "$pr:$iv";
            }
        }
        else {
            $s->v("    + add ONE dependency [$pr:$str]\n");
            push @dependencies, "$pr:$str";
        }
    }
    $s->v(
        sprintf( "    Return [%d] dependenc(y|ies)\n", scalar @dependencies )
    );
    return @dependencies;    # ( file:a/b, file:c/d, package:x, package:y )
}

sub all_dependencies_met {
    my ( $s, $id ) = @_;

    my $fail = 0;
    foreach my $dep_id ( $s->get_dependencies($id) ) {
        if ( not $s->dependency_met($dep_id) ) {
            $fail++;
        }
    }
    return 1 if not $fail;
    return 0;
}

# Decides the question if a dependency via the 'require' field
# is already fulfilled
sub require_ok {
    my ( $s, $id ) = @_;
    die "ERROR: require_ok needs id argument" if not defined $id;
    my ( $pr, $iv ) = $s->id($id);

    $s->v("is the requirement for providor [$pr] regarding [$iv] OK?\n");

    if ( $s->is_provided($id) ) {

        #if ( exists $info->{$pr}->{$iv}->{installed} ) {
        $s->v("pass require [$pr]->[$iv] (already installed)\n");
        return 1;
    }
    elsif ( exists $str->{$pr}->{$iv}->{planned} ) {    # before pending
        $s->v("pass require [$pr]->[$iv] (will be installed before)\n");
        return 1;
    }
    elsif ( $iv eq q{} or $pr eq q{} ) {
        die "ERROR 4: ";
    }
    else {
        $s->v("fail require_ok [$pr]->[$iv]\n");
        return 0;
    }
    return 0;
}

sub read_modules {
    my ( $s, $i ) = @_;

    my @m = ();
    find( sub { push @m, "$File::Find::dir$/" if (/manifests$/); }, $wt );
    return \@m;
}

# read from $MODULE/manifests/i.ini
# add it to ONE Ningyou::Type::Module
# add it THE global configuration 'cfg'
sub read_module {
    my ( $s, $mo ) = @_;    # mo = module
    my $fn  = "$wt/$mo/manifests/i.ini";
    my $cfg = Config::INI::Reader->read_file($fn);

    # collect default values first
    my $def = {};
    foreach my $rid ( sort keys %{$cfg} ) {    # default : file
        my ( $pr, $iv ) = $s->id($rid);
        $s->d("pr [$pr] iv [$iv]\n");          # pr [default] iv [file]
        next if $pr ne 'default';
        $def->{$iv} = $cfg->{$rid};    # def->{file} = cfg->{default:file}
    }

    # collect all but default values
    foreach my $rid ( sort keys %{$cfg} ) {
        my ( $pr, $iv ) = $s->id($rid);
        next if $pr eq 'default';
        my $id = "$pr:$iv";
        $s->d("rid [$rid] -> id [$id] ($pr:$iv)\n");
        use Ningyou::Type::Module;
        my $m = Ningyou::Type::Module->new;
        foreach my $k ( sort keys %{ $cfg->{$rid} } ) {
            $s->d("k [$k] =>[$cfg->{$rid}->{$k}]\n");
            $m->set_module( $k => $cfg->{$rid}->{$k} );    # 'owner' => 'c'
        }

        # add default values to the module
        foreach my $field ( sort keys %{ $def->{$pr} } ) {

            # module is the same (no def for module)
            next if $field eq 'module';

            # splice in default field values
            $s->d("Q: do we apply default value for field [$field]?\n");
            if ( not $m->is_module($field) ) {
                $s->d("A: YES ($def->{$pr}->{$field})\n");
                $m->set_module( $field => $def->{$pr}->{$field} );
            }
            else {
                $s->d("A: NO\n");
            }
        }
        $m->set_module( 'module' => $mo );    # remember own module name
        $s->set_cfg( $id => $m );    # add to the global configuration
    }

    #print Dumper $cfg;
    #print Dumper $s->cfg_pairs;

}

sub id {
    my ( $s, $id ) = @_;
    my ( $pr, $iv ) = split /\s*:\s*/, $id;
    return ( $pr, $iv );
}

1;
__END__

=pod

=head1 NAME

Ningyou

=head1 DEPENDENCIES

=head2 DEIBIAN WHEEZY

libterm-readkey
libnamespace-autoclean-perl
libmoose-perl
libcapture-tiny-perl
libconfig-ini-perl

=cut
