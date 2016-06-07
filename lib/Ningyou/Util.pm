package Ningyou::Util;

use Moose;
use Data::Dumper;
use namespace::autoclean;
use Term::ReadKey;
our $VERSION = '0.0.9';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

has 'options' => (
    is       => 'rw',
    isa      => 'HashRef',
    reader   => 'get_options',
    writer   => 'set_options',
    default  => sub { return {}; },
    required => 1,
);

sub source_to_fqfn {
    my ( $s, $i ) = @_;
    my $mt
        = exists $i->{moduletree} ? $i->{moduletree} : die "no [moduletree]";
    my $mo = exists $i->{module} ? $i->{module} : die "no [module]";
    my $so = exists $i->{source} ? $i->{source} : return undef;
    my $oso = $so;
    die
        "Malformed URL! [$so] is not of the form [ningyou://<MODULE>/*] or [ningyou://~/*\n"

        if not $so =~ m{ningyou://.+}mx;

    if ( $so =~ s{ningyou://~}{$mt/$mo/files}gmx ) {
        $s->d("source_to_fqfn: short URL (tilde) [$so]");
    }
    elsif ( $so =~ s{ningyou:///modules/$mo}{$mt/$mo/files}gmx ) {
        $s->d("source_to_fqfn: long URL [$so]");
    }
    $s->v("  source URL requested from module");
    $s->v( "    -> " . $s->c( 'todo', $oso ) );
    $s->v("  points to calculated source FILE|DIRECTORY");
    $s->v( "    -> " . $s->c( 'file', $so ) );

    return $so;
}

sub file_md5_eq {
    my ( $s, $ca, $fn1, $fn2 ) = @_;
    my $d1 = $s->get_md5( $ca, $fn1 );
    my $d2 = $s->get_md5( $ca, $fn2 );
    return 1 if $d1 eq $d2;
    return 0;
}

sub get_md5 {
    my ( $s, $ca, $fn ) = @_;
    my $ctx = Digest::MD5->new;
    open my $f, q{<}, $fn or die "Can not read [$fn]!\n";
    $ctx->addfile($f);
    my $digest = $ctx->hexdigest;
    close $f;

    $s->d("calculate md5 [$digest]");
    $ca->{$fn} = $digest;
    return $digest;
}

sub get_facts {
    my ( $s, $i ) = @_;

    my $f = {};
    my $x = {};

    eval {
        require Sys::Facter;

        my $sf = Sys::Facter->new();

        $s->d( Dumper($sf) );
        $sf->load('operatingsystem');

        $s->d( Dumper $sf->facts );
        $f->{dist}
            = defined $sf->operatingsystem ? $sf->operatingsystem : 'na';
        $f->{kernel} = defined $sf->kernel   ? $sf->kernel   : 'na';
        $f->{host}   = defined $sf->hostname ? $sf->hostname : 'na';
        $f->{domain} = defined $sf->domain   ? $sf->domain   : 'na';
        $f->{fqdn}   = "$f->{host}.$f->{domain}";
        1;
    } or do {

        my $error = $@;
        if ( -e "/usr/bin/facter" ) {

            use Ningyou::Cmd;
            my $nc = Ningyou::Cmd->new;

            my @out = qx(/usr/bin/facter);
            foreach my $o (@out) {
                chomp $o;
                $s->d("facter [$o]\n");
                my ( $key, $value ) = split /\s+=>\s+/, $o;
                $x->{$key} = $value;
            }
            $f->{kernel} = exists $x->{kernel}   ? $x->{kernel}   : 'na';
            $f->{host}   = exists $x->{hostname} ? $x->{hostname} : 'na';
            $f->{dist}
                = exists $x->{operatingsystem} ? $x->{operatingsystem} : 'na';
            $f->{domain} = exists $x->{domain} ? $x->{domain} : 'na';
            $f->{fqdn}   = "$f->{host}.$f->{domain}";
            $f->{fqdn}   = qx(hostname --fqdn);
            chomp $f->{fqdn};
        }
        else {
            die "need Sys::Facter or facter\n";
        }

    };

    return $f;
}

use File::DirCompare;
use File::Basename;

sub compare_dirs {
    my ( $s, $d1, $d2 ) = @_;
    use Carp;
    carp "d1 [$d1] not a directory!\n" if not -d $d1;
    carp "d2 [$d2] not a directory!\n" if not -d $d2;

    my $equal = 1;

    File::DirCompare->compare(
        $d1, $d2,
        sub {
            my ( $a, $b ) = @_;
            $equal = 0
                ; # if the callback was called even once, the dirs are not equal

            if ( !$b ) {
                $s->v( sprintf "| File '%s' only exists in dir '%s'.\n",
                    basename($a), dirname($a) );
            }
            elsif ( !$a ) {
                $s->v( sprintf "| File '%s' only exists in dir '%s'.\n",
                    basename($b), dirname($b) );
            }
            else {
                $s->v("| File contents for\n");
                $s->v("| [$a]\n");
                $s->v("| and [$b] are different.\n");
            }
        }
    );

    return $equal;
}

sub ask_question {
    my ( $s, $i ) = @_;
    my $q = exists $i->{q} ? $i->{q} : die "no 'q'\n";    # question
    my $e = exists $i->{e} ? $i->{e} : q{};               # example
    my $do = 1;
    my $a  = q{};
    while ( not $a ) {
        $s->o( $q . "\n" );
        $s->o( "example: " . $e . "\n" );
        $s->o(': ');
        ReadMode('normal');
        $a = ReadLine 0;
        chomp $a;
        ReadMode('normal');
    }
    $s->o("\n");
    return $a;
}

sub ask_for_user {
    my ( $s, $i ) = @_;
    my ($e1000) = getpwuid(1000);
    my $e  = defined $e1000 ? $e1000 : 'bilbo';
    my $do = 1;
    my $a  = q{};
    while ($do) {
        my $q = 'please provide a login/user name (example ';
        $s->o( $q . $s->c( 'module', $e ) . ")\n$i: " );
        ReadMode('normal');
        $a = ReadLine 0;
        chomp $a;
        ReadMode('normal');
        my $n = getpwnam($a);
        $do = 0 if defined $n and $n;
        $s->o("\n");
    }
    return $a;
}

sub ask_for_group {
    my ( $s, $i ) = @_;
    my ($e1000) = getgrgid(1000);
    my $e  = defined $e1000 ? $e1000 : 'bilbo';
    my $do = 1;
    my $a  = q{};
    while ($do) {
        my $q = 'please provide a gid/group name (example ';
        $s->o( $q . $s->c( 'module', $e ) . ")\n$i: " );
        ReadMode('normal');
        $a = ReadLine 0;
        chomp $a;
        ReadMode('normal');
        my $n = getgrnam($a);
        $do = 0 if defined $n and $n;
        $s->o("\n");
    }
    return $a;
}

sub ask_for_directory {
    my ( $s, $i ) = @_;
    my $dir   = exists $i->{dir}   ? $i->{dir}   : die "no 'dir'\n";
    my $uid   = exists $i->{uid}   ? $i->{uid}   : die "no 'uid'\n";
    my $gid   = exists $i->{gid}   ? $i->{gid}   : die "no 'gid'\n";
    my $mode  = exists $i->{mode}  ? $i->{mode}  : die "no 'mode'\n";
    my $cause = exists $i->{cause} ? $i->{cause} : die "no 'cause'\n";
    my $do    = 1;
    my $d     = q{};
    while ($do) {
        my $q = "please provide a directory\n(example ";
        $s->o( $q . $s->c( 'file', $dir ) . ")\n$cause: " );
        ReadMode('normal');
        $d = ReadLine 0;
        chomp $d;
        ReadMode('normal');
        $s->o("\n");
        my $n
            = ( -d $d )
            ? $d
            : $s->ask_to_create_directory(
            { dir => $d, uid => $uid, gid => $gid, mode => $mode } );
        $do = 0 if -d $n;
    }
    return $d;
}

sub ask_to_create_directory {
    my ( $s, $i ) = @_;
    my $dir  = exists $i->{dir}  ? $i->{dir}  : die "no 'dir'\n";
    my $uid  = exists $i->{uid}  ? $i->{uid}  : die "no 'uid'\n";
    my $gid  = exists $i->{gid}  ? $i->{gid}  : die "no 'gid'\n";
    my $mode = exists $i->{mode} ? $i->{mode} : die "no 'mode'\n";
    return $i if -d $i;
    $s->o( "the directory " . $s->c( 'file', $dir ) . "\ndoes not exist!\n" );
    $s->o("should the directory be created? [y|N]\n");
    ReadMode('normal');
    my $answer = ReadLine 0;
    chomp $answer;
    ReadMode('normal');

    if ( 'y' eq lc $answer ) {
        my $nilicm = Ningyou::Cmd->new();
        $nilicm->cmd("mkdir -p $dir");
        if ( defined $uid ) {
            $nilicm->cmd("chown $uid $dir");
        }
        else {
            $nilicm->cmd("chown $> $dir");    # eff uid $>, real uid $<
        }
        if ( defined $gid ) {
            $nilicm->cmd("chgrp  $gid $dir");
        }
        else {

            # $nilicm->cmd("chgrp  $) $i");    # eff gid $),     real gid $(
        }
        if ( defined $mode ) {
            $nilicm->cmd("chmod $mode $dir");
        }
        else {
            $nilicm->cmd("chmod 0750 $dir");
        }
        $s->o(
            "Directory " . $s->c( 'file', $dir ) . " has been created.\n" );
    }
    else {
        $s->o("Please create it manually (stopping here)\n");
        exit 0;
    }
    $s->o("\n");
    return $dir;
}

sub init_master_configuration {

    # wt=/srv/ningyou-syscfg /home/c/g/ningyou
    # rp= debian-gnu-linux-8.4-jessie
    # ho=x0.c8i.org

    # fn=~/.ningyou/master.ini wt=/home/c/g/ningyou rn=linux-debian-wheezy
    my ( $s, $i ) = @_;
    my $wt = exists $i->{wt} ? $i->{wt} : die "no 'wt'\n";    # work
    my $rn = exists $i->{rn} ? $i->{rn} : die "no 'rn'\n";    # rep
    my $hn = exists $i->{hn} ? $i->{hn} : die "no 'hn'\n";    # host
    my $z  = 0;
    my $c  = q{};
    while ( my $data = <DATA> ) {
        $data =~ s{\[%\s+host\s+%\]}{$hn}gmx;
        $data =~ s{\[%\s+worktree\s+%\]}{$wt}gmx;
        $data =~ s{\[%\s+repository\s+%\]}{$rn}gmx;
        $c .= $data;
        $z++;
    }
    return $c;
}

sub ask_to_create_worktree {
    my ( $s, $i ) = @_;
    my $wt = $i;
    $s->o("The worktree do not exists!\n");
    $s->o("Should the directory [$wt] be created? [y|N]\n");
    ReadMode('normal');
    my $answer = ReadLine 0;
    chomp $answer;
    ReadMode('normal');

    if ( 'y' eq lc $answer ) {
        my $nilicm = Ningyou::Cmd->new();
        $nilicm->cmd("mkdir -p $i");
        $nilicm->cmd("chown $> $i");    # eff uid $>, real uid $<
            #$nilicm->cmd("chgrp  $) $i");    # eff gid $),     real gid $(
        $nilicm->cmd("chmod 0750 $i");
        $s->o("Directory [$i] has been created.\n");
    }
    else {
        $s->o("Please create it manually (stopping here)\n");
        exit 0;
    }
    $s->o("\n");
}

#print "Please specify two directory names\n" and exit if ( @ARGV < 2 );
#printf "%s\n",
#    &compare_dirs( $ARGV[0], $ARGV[1] ) ? 'Test: PASSED' : 'Test: FAILED';
1;

=pod

=head1 NAME

Ningyou::Util - aux. utils for Ningyou

=cut

__DATA__
[global]
;kernel=[% kernel %]
;distribution=[% distribution %]
;release=[% release %]

[provider]
file      = Ningyou::Provider::File
directory = Ningyou::Provider::Directory
cpan      = Ningyou::Provider::Cpan
package   = Ningyou::Provider::Package
git       = Ningyou::Provider::Git
link      = Ningyou::Provider::Link
service   = Ningyou::Provider::Service
chown     = Ningyou::Provider::Chown
chgrp     = Ningyou::Provider::Chgrp
chmod     = Ningyou::Provider::Chmod
cmd       = Ningyou::Provider::Cmd

; assign a repository to a node
[nodes]
[% host %]=[% repository %]

; define at least one repository: repository=path
[repositories]
[% repository %]=[% worktree %]

; Ningyou modules to be installed or ignored globally
[modules]
ningyou=1

; single packages to be installed or ignored globally
;[packages]
;ningyou=0

; REPOSITORY [repository-name]
; modules to be installed or ignored per repository
[[% repository %]]
ningyou=1

; HOST [FQDN-host-name]
; modules to be installed or ignored per host
[[% host %]]
ningyou=1
