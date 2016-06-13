package Ningyou;

# ABSTRACT: clear reproducible system administration

use utf8;                        # so literals and identifiers can be in UTF-8
use v5.12;                       # or later to get "unicode_strings" feature
use strict;                      # quote strings, declare variables
use warnings;                    # on by default
use warnings qw(FATAL utf8);     # make encoding glitches fatal
use open qw(:std :utf8);         # undeclared streams in UTF-8
use charnames qw(:full :short);  # unneeded in v5.16

use Config::Tiny;
use Data::Dumper;
use Encode qw(decode_utf8);
use File::Basename;
use File::Find;
use Moose;
use namespace::autoclean;
use Ningyou::Cmd;
use Ningyou::Util;
use Ningyou::Options;
use Ningyou::Type::Object;
our $VERSION = '0.0.9';

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
#    }, 'Ningyou::Type::Object' )
has 'cfg' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Ningyou::Type::Object]',
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
    isa     => 'HashRef',
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
my $mode       = q{};            # command
my $modules_ar = [];             # modules
my $modules    = q{};            # modules
my $result     = {};             # modules
my $f          = {};             # facts about system
my $cache      = {};
my $wt         = '/dev/null';    # work tree (/srv/ningyou)
my $mt         = '/dev/null';    # modules tree (/srv/ningyou/<REPO>/modules)
my $cfg        = {};             # global cfg space
my $cfg_fn     = undef;          # global cfg space file name
my $pkg        = {};             # pkg from cfg that should be applied or not
my $repository = 'none';
my $provider   = {};             # file, git, ...

sub run {
    my ( $s, $i ) = @_;

    # prepare options
    my $opt = Ningyou::Options->new;
    $opt->process_options;
    my $o = $opt->get_options;
    $s->set_options($o);         # set for Ningyou::Out ...
    $s->d("Ningyou::run version $VERSION");
    $mode = $opt->get_command;
    $s->d("Ningyou::run mode [$mode]");
    $modules_ar = $opt->modules;
    $modules = join q{ }, @{$modules_ar};
    $s->d("Ningyou::run modules [$modules]");

    # prepare facts
    my $u = Ningyou::Util->new;
    $f = $u->get_facts;

    # prepare configuration
    my $rfn
        = ( exists $o->{configuration} and defined $o->{configuration} )
        ? $o->{configuration}
        : '~/.ningyou/repository.ini';
    $s->d("Ningyou::run rfn [$rfn]");
    ( $cfg_fn, $cfg ) = $s->get_or_setup_cfg( $rfn, $u );
    $s->d("Ningyou::run cfg_fn [$cfg_fn]");

    # update system package meta data
    if ( exists $cfg->{status}->{packages}
        and $cfg->{status}->{packages} eq 'always-update-on-start'
        or exists $o->{update} )
    {
        $s->d("Ningyou::run update package status ...]");
        system('aptitude update');
        $s->d("Ningyou::run ... update package status]");
    }

    # print preamble
    # $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $mode = ( $mode eq q{} ) ? 'show' : $mode;
    $s->d("Ningyou::run mode [$mode]");
    my $cmmnt = ( $mode eq 'script' ) ? '# ' : q{};
    $s->o("#!/bin/sh\n") if $mode eq 'script';
    $s->o(    $cmmnt
            . 'Ningyou '
            . $s->c( 'version', "v$VERSION" ) . " for "
            . $s->c( 'host',    $f->{fqdn} )
            . "\n" );
    $s->o(
        $cmmnt . "Using configuration " . $s->c( 'file', $cfg_fn ) . "\n" );

    my $str = ( not defined $modules or $modules eq q{} ) ? 'all' : $modules;
    $s->o(    $cmmnt
            . $s->c( 'mode', ucfirst($mode) )
            . " module(s) "
            . $s->c( 'module', $str ) . " in "
            . $s->c( 'dir',    $mt )
            . "\n" );

    # prepare print used modules
    my $dot = q{ } . '.' x 70;
    my $dl  = 68 - $o->{indentation};

    # print used modules and read its configuration
    #$s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->v("Modules concidered processing: (switch on/off via master.ini)\n");
    my @modules = ();
    if ( $modules ne q{} and $modules ne 'all' ) {
        @modules = @{$modules_ar};
    }
    else {
        @modules = @{ $s->read_all_modules() };
    }
    if ( $mode eq 'list' ) {
        $s->d("Ningyou::run list modules");
        foreach my $mo ( sort @modules ) {
            chomp $mo;
            $mo =~ s{^$mt/}{}gmx;    #/home/c/g/wt/modules/zsh -> zsh
            $s->o( $s->c( 'module', "$mo " ) );
        }
        $s->o("\n");
        return;
    }
    foreach my $mo ( sort @modules ) {
        chomp $mo;
        $mo =~ s{^$mt/}{}gmx;        #/home/c/g/wt/modules/zsh -> zsh
        my $md = $mo . $dot;
        if ( $s->should_be_applied($mo) ) {
            $s->read_one_module($mo);
            $result->{$mo}->{considered} = 1;
        }
        else {
            $result->{$mo}->{considered} = 0;
        }
    }

    # make a query, print verbose query
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
    my $unprovided_objects = $s->query_unprovided();

    # make a validation, print verbose validation
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" )
        if $unprovided_objects;
    $s->planning($unprovided_objects) if $unprovided_objects;

    # print result
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->v("Verbose results:\n");
    $s->v("  number of objects to update: $unprovided_objects\n");
    $s->v( "  number of command sections: " . $s->count_commands / 2 . "\n" );

    $s->v("\n") if $mode eq 'show';
    my $dx = $dl - 12;
    $s->v(
        sprintf( "%-$dx.${dx}s  %s %s\n", 'module', 'considered', 'status' ) )
        if $mode eq 'show';
    $s->v( "_" x ( 78 - $o->{indentation} ) . "\n" ) if $mode eq 'show';
    foreach my $mo ( sort @modules ) {
        chomp $mo;
        $mo =~ s{^$mt/}{}gmx;    #/home/c/g/wt/modules/zsh -> zsh
        my $md = $s->c( 'module', $mo ) . $dot;
        my $considered
            = ( $result->{$mo}->{considered} )
            ? $s->c( 'yes', 'YES' )
            : $s->c( 'no',  'NO ' );
        my $todo
            = ( not $result->{$mo}->{considered} ) ? $s->c( 'done', '----' )
            : ( $result->{$mo}->{todo} ) ? $s->c( 'todo', 'TODO' )
            :                              $s->c( 'done', 'DONE' );

        $s->o(
            sprintf(
                "%-$dl.${dl}s [ %s ] [ %s ]\n", $md, $considered, $todo
            )
        ) if $mode eq 'show';

    }

    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );

    if ($unprovided_objects) {
        $s->action();    # do action if any
        if ( $mode eq 'show' ) {
            $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
            if ( $modules eq q{} ) {
                $s->o( "Apply changes: "
                        . $s->c( 'execute', " ningyou apply all" ) );
                $s->o( ' What would be done: '
                        . $s->c( 'execute', "ningyou script all\n" ) );
            }
            else {
                $s->o( $s->c( 'execute', " ningyou apply $modules" ) );
                $s->o( ' What would be done:'
                        . $s->c( 'execute', " ningyou script $modules\n" ) );
            }
        }
    }
    else {
        $s->o( $s->c( 'ready', "Ningyou is already up-to-date\n" ) );
    }

    $s->d("END\n");
    return 1;
}

sub get_uid {
    my @o   = qx(facter);
    my $uid = undef;
    foreach my $line (@o) {
        if ( $line =~ m{^id\s+=>\s+(.*)}gmx ) {
            $uid = $1;
        }
    }
    chomp $uid;
    return $uid;
}

sub get_gid {
    my @o   = qx(facter);
    my $gid = undef;
    foreach my $line (@o) {
        if ( $line =~ m{^gid\s+=>\s+(.*)}gmx ) {
            $gid = $1;
        }
    }
    chomp $gid;
    return $gid;
}

sub get_distribution {
    my @o   = qx(facter);
    my $dis = undef;
    foreach my $line (@o) {
        if ( $line =~ m{^lsbdistdescription\s+=>\s+(.*)}gmx ) {
            $dis = lc($1);
        }
    }
    chomp $dis;
    $dis =~ s{\s+|/}{-}gmx;
    $dis =~ s{\(|\)}{}gmx;
    $dis =~ s{-$}{}gmx;    # rm space (hyphen) at the end
    return $dis;
}

sub init_dir {
    my ( $s, $dn ) = @_;
    if ( -d $dn ) {
        print "ERR 01: directory [$dn] exists\n";
        print "please clean up before using ningyou init\n";
        exit 2;
    }
    else {
        my $c = Ningyou::Cmd->new();
        $c->cmd("mkdir -p $dn");
        $c->cmd("chown $> $dn");     # eff uid $>, real uid $<
        $c->cmd("chmod 700 $dn");    # eff gid $), real gid $(
    }
    return $dn;
}

sub init_file {
    my ( $s, $fn, $n ) = @_;
    if ( -f $fn ) {
        print "ERR 02: file [$fn] exists\n";
        print "please clean up before using ningyou init\n";
        exit 2;
    }
    else {
        my $c = Ningyou::Cmd->new();
        $c->cmd("touch $fn");
        $c->cmd("chown $> $fn");     # eff uid $>, real uid $<
        $c->cmd("chmod 600 $fn");    # eff gid $), real gid $(
        open my $f, q{>}, $fn or die "ERR 03: can not open [$fn]\n";

        print $f "$n\n";
        close $f;
    }
    return $fn;
}

sub git_init {
    my ($s) = @_;
    my $c = Ningyou::Cmd->new();
    my ( $o, $e, $r ) = $c->cmd("git init");
    return ( $o, $e, $r );
}

sub get_or_setup_cfg {
    my ( $s, $rfn, $u ) = @_;

    my $fn = glob $rfn;      # master cfg (~/.ningyou/repository.ini)
    my $d  = dirname($fn);
    if ( $mode eq 'init' ) {
        my $pwd = qx(pwd);
        chomp $pwd;
        my $h = qx(hostname --fqdn);
        chomp $h;
        my $rn = $s->get_distribution();
        my $wt = "$pwd";
        my $rp = "$pwd/$rn/modules";
        $s->o(    "Initializing empty Ningyou repository in "
                . $s->c( 'dir', $pwd )
                . "\n" );
        $s->o( "for host " . $s->c( 'host', $h ) . "\n" );
        $s->o( "creating new directory " . $s->c( 'dir', $rp ) . "\n" );
        $s->init_dir($rp);
        $s->o(    "creating new file      "
                . $s->c( 'file', "$pwd/master.ini" )
                . "\n" );
        $s->init_file(
            "$pwd/master.ini",
            $u->init_master_configuration(
                { hn => $h, wt => $wt, rn => $rn }
            )
        );
        $s->o(    "creating new directory "
                . $s->c( 'dir', "$rp/modules" )
                . "\n" );
        $s->init_dir("$rp/modules");
        my $dn0 = glob "~/.ningyou";
        $s->o( "creating new directory " . $s->c( 'dir', $dn0 ) . "\n" );
        $s->init_dir($dn0);
        my $fn1 = $dn0 . "/repository.ini";
        $s->o( "creating new file      " . $s->c( 'file', $fn1 ) . "\n" );
        $s->init_file( $fn1, "[global]\nworktree=$wt\n" );
        $s->o("intializing git repository\n");
        $s->git_init($pwd);
    }
    else {

    }

    # read ~/.ningyou/repository.ini
    die "ERR 04: no [$fn]. Execute 'ningyou init'\n" if not -f $fn;

    #my $rcfg = Config::INI::Reader->read_file($fn);
    my $rcfg = Config::Tiny->read( $fn, 'utf8' );
    my $wtp = $rcfg->{global}->{worktree};
    $s->v( "worktree" . $s->c( 'dir', $wtp ) . "\n" );
    my $cfg_fn = "$wtp/master.ini";
    die "please provide master configuration $cfg_fn\n" if not -e $cfg_fn;

    # read /srv/ningyou/master.ini
    #my $cfg = Config::INI::Reader->read_file($cfg_fn);
    my $cfg = Config::Tiny->read( $cfg_fn, 'utf8' );
    $repository = $s->get_repository( $cfg, $f->{fqdn} );

    $mt = $s->get_moduletree( $cfg, $repository );
    die "please provide working tree $mt\n" if not -d $mt;
    $provider = $cfg->{provider};
    return ( $cfg_fn, $cfg );
}

sub get_repository {
    my ( $s, $c, $h ) = @_;    #  c = cfg (master.ini), h = fqdn
    $s->d("get_repository: host [$h]");

    my $m
        = "ERR 05: Node "
        . $s->c( 'host', $h )
        . " not mentioned in section [nodes]\n";
    $m .= "Please add node to master.ini\n";

    my $r = exists $c->{nodes}->{$h} ? $c->{nodes}->{$h} : die $m;
    $s->d("get_repository: use repository [$r]\n");

    return $r;
}

sub get_moduletree {
    my ( $s, $c, $r ) = @_;    # c =cfg (master.ini), r = repository name

    my $se = 'repositories';
    my $m  = "ERR 06: a repository called '$r' is\n";
    $m .= "not mentioned in section [$se]!\n";
    $m .= "Please add repository to master.ini\n";
    my $wt = exists $c->{$se}->{$r} ? $c->{$se}->{$r} : die $m;
    my $mt = "$wt/$r/modules";
    $s->d("use worktree: $wt\n");
    $s->d("use moduletree: $mt\n");

    return $mt;
}

# query OBJECTs of PROVIDER if applied or not
# returns number of unprovided objects
sub query_unprovided {
    my ( $s, $i ) = @_;
    my $se = "Ningyou::query_unprovided";
    $s->d($se);
    return if $mode eq 'full-show';
    return if $mode eq 'full-script';

    my $unprovided = 0;

    # foreach provider: File, Directory, ...
    $s->v("Query: what is already provided and what not ...\n");
    $s->d("$se Foreach entry id (provider:object)\n");
    foreach my $id ( sort $s->ids_cfg ) {    # id = provider:object
        my ( $pr, $iv ) = $s->id($id);
        $s->d("$se pr [$pr] iv [$iv]");
        if ( not $s->check_provided($id) ) {
            $unprovided++;
            $s->d("$se => unprovided");
        }
    }
    return $unprovided;
}

sub check_provided {
    my ( $s, $id ) = @_;                     # id=package:vim

    my $se = "Ningyou::check_provided";
    $s->d($se);
    my ( $pr, $iv ) = $s->id($id);           # pr=package, iv=vim
    my $prnt_pr = $s->c( 'file',   $pr );
    my $prnt_iv = $s->c( 'module', $iv );
    $s->d("$se pr [$pr] iv [$iv]");
    my $o = $s->get_options;
    $s->v("* Checking provided $prnt_pr provide object $prnt_iv\n");
    my $msg
        = "ERR 07: provider $prnt_pr not supported!\n"
        . "Please install the provider Ningyou::Provider::"
        . ucfirst $pr
        . "\nand consider adding it at"
        . " section [providers] in master.ini\n";
    die $msg if not exists $provider->{$pr};
    my $ppm = "Ningyou::Provider::" . ucfirst $pr;
    $s->d("$se Perl provider module [$ppm]");
    eval "use $ppm";
    die $@ if defined $@ and $@;

    # $o = {
    #        'indentation' => 0,
    #        'debug' => '/tmp/ningyou.log',
    #        'verbose' => 1
    #      };
    my $p = $provider->{$pr}->new( { options => $o } );

    # $cfg = (
    #     'object' => {
    #                      'source' => 'ningyou://~/bin',
    #                      'ensure' => 'latest',
    #                      'module' => 'home-c-bin'
    #                 }
    #     }, 'Ningyou::Type::Object' );
    my $cfg
        = ( $s->is_cfg($id) and exists $s->get_cfg($id)->{object} )
        ? $s->get_cfg($id)->{object}
        : {};
    my $module
        = exists $cfg->{module}
        ? $cfg->{module}
        : die "no module in CFG: " . Dumper($cfg);

    if ( exists $cfg->{require} ) {
        $cfg->{require} =~ s{\s+}{}gmx;
        $s->v(    "- Q: "
                . $s->c( 'file', $id )
                . " requires "
                . $s->c( 'file', $cfg->{require} )
                . ",\n" );
        $s->v("     are all requirements met?\n");
        use Data::Dumper;
        $s->v( "cfg: \n" . Dumper($cfg) );
        my $rcfg
            = ( $s->is_cfg( $cfg->{require} )
                and exists $s->get_cfg( $cfg->{require} )->{module} )
            ? $s->get_cfg( $cfg->{require} )->{module}
            : {};
        my ( $rpr, $riv ) = $s->id( $cfg->{require} );
        $s->d("RIV module [$riv]\n");
        my $require_ok = $p->applied(
            {
                cfg      => $rcfg,    #$r->{$pr}->{$iv},
                object   => $riv,
                module   => $riv,
                provider => $rpr,
                cache    => $cache,
                mt       => $mt,
                dryrun   => 1,
                itemize  => 1,
                base     => '-a',
            }
        );
        if ($require_ok) {
            $s->v(    "- A: "
                    . $s->c( 'yes', 'YES' )
                    . ", dependency is met, will continue\n" );

        }
        else {
            $s->v(    "- A: "
                    . $s->c( 'no', 'NO' )
                    . ", dependency is NOT met, will abbort\n" );
            return 0;
        }
    }

    $s->v("- Q: do provider $prnt_pr provide object $prnt_iv?\n");
    $s->d("$se object [$iv]");
    my $is_provided = $p->applied(
        {
            cfg      => $cfg,     #$r->{$pr}->{$iv},
            object   => $iv,      # /srv/new-dir
            provider => $pr,
            cache    => $cache,
            mt       => $mt,
            dryrun   => 1,
            itemize  => 1,
            base     => '-a',
        }
    );
    if ($is_provided) {
        $s->set_provided( "$pr:$iv" => 1 );
        $s->v(    "- A: "
                . $s->c( 'yes',    'YES' ) . ", "
                . $s->c( 'module', $iv ) . " "
                . $s->c( 'file',   $pr )
                . " allready provied\n" );
    }
    else {
        $s->set_provided( "$pr:$iv" => 0 );
        $s->v(    "- A: "
                . $s->c( 'no',     'NO' ) . ", "
                . $s->c( 'module', $iv )
                . " not provied\n" );
        $s->v(    "  Therefore "
                . $s->c( 'module', $iv )
                . " is going to be provided via ["
                . $s->c( 'file', 'apply' )
                . "]\n" );

        # TODO: check, if 'apply' is really correct. Better use 'applied'?
        # WHY? actually we do only want to exec apply when installing
        # or apply in a dry mode when 'script' is used
        my $cmd = $p->apply(
            {

                # mandatory
                cache    => $cache,
                object   => $iv,
                provider => $pr,
                cfg      => $cfg,
                mt       => $mt,
            }
        );
### ###
        if ( defined $cmd ) {
            $s->v("  add cmd [$cmd]");
            my $mo = $cfg->{module};
            $s->v("  module  [$mo]");
            my $y = "=" x 78;
            my $x = sprintf( "# === module [%s] === object [%s] ===%s",
                $mo, $id, $y );
            if ( $mode eq 'apply' ) {
                $s->add_command($cmd);
            }
            else {
                $s->add_command(
                    sprintf( "%-.74s\n", $s->c( 'comment', $x ) ) );
                $s->add_command( $s->c( 'command', $cmd ) . "\n" );
            }
            $result->{$mo}->{'todo'} = 1;
        }
        else {
            $s->v("no cmd from apply\n");
            my $mo = $cfg->{module};
            $result->{$mo}->{todo} = 0;
        }
    }

    return $is_provided;
}

# TODO: this is testing the dependency chain only 1 level deep
#       and only for normal providers
#       - consider to make it "indefinite" deep
#       - consider to add provider "Module"
sub planning {
    my ( $s, $i ) = @_;
    my %queue = ();

    $s->v("Query: what dependencies need to be applied:\n");
    foreach my $id ( sort $s->ids_cfg ) {
        $s->d("id [$id]");
        my ( $pr, $iv ) = $s->id($id);
        my $piv = $s->c( 'module', $iv );
        my $ppr = $s->c( 'file',   $pr );

        $s->v("- Q: Should object $piv be provided via $ppr?\n");
        if ( $s->get_provided($id) ) {
            $s->v(    "- A: "
                    . $s->c( 'no', 'NO' )
                    . ", should not be provided via $ppr\n" );
            next;
        }
        else {
            $s->v(    "- A: "
                    . $s->c( 'yes', 'YES' )
                    . ", should be provided via $ppr\n" );

            # TODO: check if ->{module}->{object}
            my $mo = $s->get_cfg($id)->{module}->{module};
            $s->v(    "- Q: What direct dependecies has "
                    . $s->c( 'module', $id )
                    . "?\n" );
            my $n = 0;
            foreach my $dep_id ( $s->get_dependencies($id) ) {
                die "Invalid dependency in module [$mo], missing [:]!\n"
                    if not $dep_id =~ m{:}gmx;
                $s->v(    "- A: "
                        . $s->c( 'module', $id )
                        . " has dependency [$dep_id]\n" );
                $s->check_provided($dep_id);
                $n++;
            }
            $s->v("- A: none") if not $n;
        }
    }
    return 0;
}

sub should_be_applied {
    my ( $s, $mo ) = @_;
    my $sr = "Ningyou::should_be_applied: ";
    $s->d( $sr . "module [$mo]" );

    return 1 if ( exists $pkg->{$mo} );
    $pkg->{$mo} = 0;
    $s->d( $sr . "pkg->{$mo} do not exists" );

    # if should be applied globally: [modules]
    if ( exists $cfg->{modules}->{$mo} and $cfg->{modules}->{$mo} ) {
        $s->d( $sr . "should be applied globally: [modules]" );
        $pkg->{$mo}++;
    }

    # if should be applied for repository
    if ( exists $cfg->{$repository}->{$mo} and $cfg->{$repository}->{$mo} ) {
        $s->d( $sr . "should be applied for repository" );
        $pkg->{$mo}++;
    }

    # if it should be applied for client
    if ( exists $cfg->{ $f->{fqdn} }->{$mo} and $cfg->{ $f->{fqdn} }->{$mo} )
    {
        $s->d( $sr . "it should be applied for client" );
        $pkg->{$mo}++;
    }
    return $pkg->{$mo};
}

sub action {
    my ($s) = @_;

    my $o = $s->get_options;
    if ( $mode eq 'script' ) {
        $s->v(    "# number of modules to update: "
                . $s->count_commands / 2
                . "\n" );
        $s->o("export MT=$mt\n");
        my $z = 0;
        foreach my $cmd ( $s->all_commands ) {    # already sorted
            if ( not exists $o->{raw} ) {
                $cmd =~ s/^\s+//gmx;
                if ( $mode eq 'show' ) {
                    $cmd =~ s/^/# /gmx;
                }
                $cmd =~ s/$mt/\${MT}/gmx;
                $cmd =~ s/&&/&&\n/gmx;
            }
            $cmd =~ s{\n}{\n}gmx;
            $cmd =~ s{\s+\n}{\n}gmx;
            $s->o($cmd);
            $z++;
        }
        $s->o( $s->c( 'comment', "# EOS - end of script\n" ) );
    }
    if ( $mode eq 'apply' ) {
        foreach my $cmd ( $s->all_commands ) {    # already sorted
            next if $cmd =~ m{^#};
            $s->o("$cmd\n");
            my $nilicm = Ningyou::Cmd->new();
            my ( $out, $err, $res ) = $nilicm->cmd($cmd);
            if ($err) {
                $s->o( $s->c( 'error', $err . " " . $res ) );
            }
        }
    }
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
    foreach my $tid (@dep_test) {    # package:zsh,vim (order given by admin)
        $s->v("  - Test dependency id [$tid]\n");
        my ( $pr, $str ) = $s->id($tid);
        $s->v( "    id has provider " . $s->c( 'file', $pr ) . "\n" );
        my @d = ();
        if ( $str =~ m{,}gmx ) {     # if comma
            my @d = split /,/, $str;    # zsh,vim
            foreach my $iv (@d) {       # order given by admin
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

sub read_all_modules {
    my ( $s, $i ) = @_;

    my @m = ();
    find( sub { push @m, "$File::Find::dir$/" if (/manifests$/); }, $mt );
    return \@m;
}

sub get_all_mo_ini {
    my ( $s, $mo ) = @_;
    my @ini = qx(cd $mt/$mo/manifests && ls *.ini);
    return @ini;
}

# read from $MODULE/manifests/i.ini
# add it to ONE Ningyou::Type::Object
# add it THE global configuration 'cfg'
# CRITIQUE: actually the type Ningyou::Type::Object do only describe
#           a part of a module, lets say an OBJECT.
#           returning the cfg value for a module is not possible
#           at the moment
sub read_one_module {
    my ( $s, $mo ) = @_;    # mo = module
    my $sr = "Ningyou::read_one_module";
    $s->d($sr);
    my @ini = $s->get_all_mo_ini($mo);
    foreach my $ini ( sort @ini ) {
        chomp $ini;
        $s->d("$sr process ini file [$ini]");
        my $fn = "$mt/$mo/manifests/$ini";

        #my $cfg = Config::INI::Reader->read_file($fn);
        my $cfg = Config::Tiny->read( $fn, 'utf8' );

        # collect default values first
        my $def = {};
        foreach my $rid ( sort keys %{$cfg} ) {    # default : file
            my ( $pr, $iv ) = $s->id($rid);
            $s->d(    "$sr: pr "
                    . $s->c( 'file',   $pr ) . " iv "
                    . $s->c( 'module', $iv )
                    . "\n" );                      # pr [default] iv [file]
            next if $pr ne 'default';
            $def->{$iv} = $cfg->{$rid};    # def->{file} = cfg->{default:file}
        }

        # collect all but default values
        foreach my $rid ( sort keys %{$cfg} ) {
            my ( $pr, $iv ) = $s->id($rid);
            next if $pr eq 'default';
            my $id = "$pr:$iv";
            $s->d("$sr: rid [$rid] -> id [$id] ($pr:$iv)\n");
            my $m = Ningyou::Type::Object->new;
            foreach my $k ( sort keys %{ $cfg->{$rid} } ) {
                $s->d("$sr: k [$k] =>[$cfg->{$rid}->{$k}]\n");
                $m->set_object( $k => $cfg->{$rid}->{$k} );   # 'owner' => 'c'
            }

            # add default values to the module
            foreach my $field ( sort keys %{ $def->{$pr} } ) {

                # module is the same (no def for module)
                next if $field eq 'module';

                # splice in default field values
                $s->d(
                    "$sr: Q: do we apply default value for field [$field]?\n"
                );
                if ( not $m->is_object($field) ) {
                    $s->d("$sr: A: YES ($def->{$pr}->{$field})\n");
                    $m->set_object( $field => $def->{$pr}->{$field} );
                }
                else {
                    $s->d("$sr: A: NO\n");
                }
            }
            $s->d("$sr: will set module to [$mo]");
            $m->set_object( 'module' => $mo );    # remember own module name
            $s->set_cfg( $id => $m );    # add to the global configuration
        }
    }
    return;
}

sub id {
    my ( $s, $id ) = @_;
    my ( $pr, $iv ) = split /\s*:\s*/, $id, 2;
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
