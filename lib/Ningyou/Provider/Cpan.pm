package Ningyou::Provider::Cpan;
#
# USAGE:
#
# <MODULE>/manifests/i.ini
#
# MANDATORY:
# [cpan:<PERL_MODULE>]
#
# Example:
# [cpan:Lingua::JA::Kana]
#
# OPTIONAL:
# source=ningyou://~/<TAR-ARCHIVE>
# url=<URL> (if not in source, will download)
# method=<CPAN_METHOD> (make|build|dzil)
# env=<PATH_TO_ENVIRONMENT_FILE>
# version=<VERSION> (version to be checked)
#
# Example:
# [cpan:Lingua::JA::Kana]
# source=ningyou://~/Lingua-JA-Kana-0.07.tar.gz
# url=http://search.cpan.org/CPAN/authors/id/D/DA/DANKOGAI/Lingua-JA-Kana-0.07.tar.gz
# env=/srv/env/perl-5-20-2
#
#
#
# NOT IMPLEMENTED:
# method=cpanm|dzil|cpan
# perl5lib=<DIRECTORY>
# perl-mm-opt=<DIRECTORY>
# perl-mb-opt=<DIRECTORY>
# require=package:libgit-repository-perl,libgit-wrapper-perl,libterm-shell-perl,libdigest-md5-file-perl,libmoose-perl
#
# source /srv/env/perl-5.20.2 sets:
# PERL_MB_OPT=--install_base /srv/perl-5.20.2
# PERL_MM_OPT=INSTALL_BASE=/srv/perl-5.20.2
# PERL5LIB=/srv/perl-5.20.2/lib/perl5:/srv/perl-5.20.2/lib/i486-linux-gnu-thread-multi:
#
use Data::Dumper;
use File::Basename;
use Moose;
use Time::HiRes qw(gettimeofday);
use namespace::autoclean;
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

my $id = q{ } x 8;

sub init { my ( $s, $i ) = @_; return $i; }

sub apply {
    my ( $s, $i ) = @_;
    my $ca = exists $i->{cache}    ? $i->{cache}    : die 'no cache';
    my $iv = exists $i->{object}   ? $i->{object}   : die 'no object';
    my $pr = exists $i->{provider} ? $i->{provider} : die 'no provider';
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die 'no cfg';
    my $mt = exists $i->{mt}       ? $i->{mt}       : die 'no mt';

    # cfg
    my $mo = exists $c->{module} ? $c->{module} : die "no [module] in cfg";
    my $ur = ( exists $c->{url} and defined $c->{url} ) ? $c->{url} : 0;

    # calculated
    my $o  = $s->get_options;
    my $u  = Ningyou::Util->new( { options => $o } );
    my $so = $u->source_to_fqfn(
        { module => $mo, moduletree => $mt, source => $c->{'source'} } );
    my $sr = "Ningyou::Provider::Cpan::apply ";
    $s->d("$sr so [$so]");

    my $di = "$mt/$mo/files";
    $s->d("$sr di [$di]");
    my @cmd = ();
    if ( not -e $so ) {
        if ($ur) {
            $s->d("$sr no source [$so], but url [$ur]");
            push @cmd, "mkdir $di" if not -d $di;
            $s->d("$sr download url [$ur]");
            push @cmd, "cd $di && wget -q  $ur";
        }
        else {
            die "ERR: no source [$so] and no url= in [$mo]\n";
        }
    }
    else {
        $s->d("$sr found  so [$so]");
    }

    my $env = exists $c->{env} ? "source $c->{env} &&" : q{};
    $s->d("$sr env [$env]");

    my ( $bds, $bdm ) = gettimeofday;
    my $bd = "/tmp/ningyou-$bds.$bdm";
    $s->d("$sr bd [$bd]");
    push @cmd, "mkdir -p $bd";
    push @cmd, "cd $bd";
    my $tar = basename($so);
    push @cmd, "cp $so .";
    push @cmd,
          q{perl -e 'use Archive::Tar;my $t=Archive::Tar->new;$t->read("}
        . $tar
        . q{");$t->extract();'};

    my $archive = basename( $tar, ( '.tar.gz', '.tgz', 'tar.bz2', 'tbz' ) );
    push @cmd, "cd $archive";

    my $mtst = ( exists $c->{test} and $c->{test} ) ? '&& make test'    : q{};
    my $btst = ( exists $c->{test} and $c->{test} ) ? '&& ./Build test' : q{};
    my $make
        = "bash -c '$env perl Makefile.PL && make $mtst && make install'";
    my $build
        = "bash -c '$env perl Build.PL && ./Build build $btst &&. /Build install'";
    if ( exists $c->{method} ) {
        if ( $c->{medthod} eq 'make' ) {
            push @cmd, $make;
        }
        elsif ( $c->{medthod} eq 'build' ) {
            push @cmd, $build;
        }
        elsif ( $c->{medthod} eq 'dzil' ) {
            push @cmd, "bash -c '$env dzil install $so'";
        }
        else {
            die
                "ERR: CPAN method [$c->{method}] not supported. (supported: make|build|dzil\n";
        }
    }
    else {
        push @cmd, "if [ -e Build.PL ]; then $build; else $make; fi";
    }
    if ( exists $o->{debug} ) {
        push @cmd,
            "echo 'debug mode, remember to remove /tmp/ningyou-$bds.$bdm'";
    }
    else {
        push @cmd, "rm -rf /tmp/ningyou-$bds.$bdm";
    }

    my $rcmd = join q{ && }, @cmd;
    return $rcmd;
}

sub applied {
    my ( $s, $i ) = @_;

    # api
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";
    my $mt = exists $i->{mt}       ? $i->{mt}       : die 'no mt';

    # cfg
    my $mo = exists $c->{module} ? $c->{module} : die "no [module] in cfg";
    my $env = exists $c->{env}     ? "source $c->{env} &&" : q{};
    my $ver = exists $c->{version} ? $c->{version}         : 0;

    my $sr = "Ningyou::Provider::Cpan::applied";
    $s->d("$sr env [$env]");
    $s->d("$sr ver [$ver]");

    if ($ver) {
        $s->d("$sr ver [$ver]");
        $s->v("    check version $ver");
        my $cmd = "eval \"require $iv\" and print $iv" . '->VERSION;';
        $s->v(qq{    cmd [bash -c "$env perl -le '$cmd'"});
        my $v = qx(bash -c "$env perl -le '$cmd'");
        chomp $v;
        $s->v("    got version [$v]");

        return 1 if $v eq $ver;
        return 0;

    }
    else {
        $s->d("$sr no version");
        my $cmd = qq{bash -c "$env perl -e 'require $iv;' > /dev/null 2>&1"};
        $s->d("$sr cmd [$cmd]");
        eval { system($cmd); };
        my $e = defined $? ? $? : 0;
        $s->d("$sr return code [$e]");
        return 1 if not $e;
    }
    return 0;
}
1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Cpan - handle CPAN Perl modules

=cut

