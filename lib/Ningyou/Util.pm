package Ningyou::Util;

use Moose;
use Data::Dumper;
use namespace::autoclean;
use Term::ReadKey;
our $VERSION = '0.0.6';

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
    my $wt = exists $i->{worktree} ? $i->{worktree} : die "no [worktree]";
    my $mo = exists $i->{module}   ? $i->{module}   : die "no [module]";
    my $so = exists $i->{source}   ? $i->{source}   : return undef;
    my $oso = $so;
    die "Malformed URL! [$so] is not of the form [ningyou:///<MODULE>/*]\n"
        if not $so =~ m{ningyou:///.+}mx;

    $s->d("source_to_fqfn: [$so] -> - worktree");
    $so =~ s{ningyou:///modules/}{$wt/};
    $s->d("source_to_fqfn: [$so] -> + files");
    $so =~ s{/$mo/}{/$mo/files/};
    $s->d("source_to_fqfn: [$so]  -> -e");
    $s->v("  source URL [$oso]");
    $s->v("  points to");
    $s->v("  [$so]");

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
            $f->{fqdn} = "$f->{host}.$f->{domain}";
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
    my ( $s, $d1, $d2) = @_;
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

sub ask_to_create_directory {
    my ( $s, $i ) = @_;
    $s->o("The directory [$i] does not exist!\n");
    $s->o("Should the directory be created? [y|N]\n");
    ReadMode('normal');
    my $answer = ReadLine 0;
    chomp $answer;
    ReadMode('normal');

    if ( 'y' eq lc $answer ) {
        my $nilicm = Ningyou::Cmd->new();
        $nilicm->cmd("mkdir -p $i");
        $nilicm->cmd("chown $> $i");    # eff uid $>, real uid $<

        # $nilicm->cmd("chgrp  $) $i");    # eff gid $),     real gid $(
        $nilicm->cmd("chmod 0750 $i");
        $s->o("Directory [$i] has been created.\n");
    }
    else {
        $s->o("Please create it manually (stopping here)\n");
        exit 0;
    }
    $s->o("\n");
    return $i;
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

__END__

=pod

=head1 NAME

Ningyou::Util - aux. utils for Ningyou

=cut

