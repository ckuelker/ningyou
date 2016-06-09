package Ningyou::Provider::Tar;
#
# USAGE:
#
# <MODULE>/manifests/i.ini
#
# MANDATORY:
# [tar:<FILE>] (FILE is a file in the file system provided by tar)
# source=<NINGYOU-URL> (Example: ningyou://~/libacbcdef-0.0.1.tbz)
#
# OPTIONAL STRONGLY RECOMMENDED:
# archive=<TAR-ARCHIVE-STEM> (Example: libabcdef-0.0.1)
#
# OPTIONAL RECOMMENDED:
# provides=<PROVIDER:OBJECT>[, .., <PROVIDER:OBJECT>] (PROVIDER:dir|file|link)
# url=<HTTP-URL> (Example: http://example.com/download/libabcdef.tbz)
# ensure=all (requires provides=)
#
# OPTIONAL:
# configure=1|0
# make=1|0
# make-install=1|0
# post=<COMMAND> (Example: ldconfig)
#
# EXAMPLE:
#
# [tar:/usr/local/lib/libabcdef.so.2.2.0]
# url=http://example.com/download/pub/libabcdef/1.4.0/libabcdef-1.4.0.tar.bz2
# source=ningyou://~/libabcdef-1.4.0.tar.bz2
# archive=libabcdef-1.4.0
# configure=1
# make=1
# make-install=1
# post=ldconfig
# provides=dir:/usr/local/share/doc/libabcdef,\
# file:/usr/local/lib/pkgconfig/libabcdef.pc,dir:/usr/local/include/dvdcss,\
# file:/usr/local/lib/libabcdef.a,file:/usr/local/lib/libabcdef.la,\
# file:/usr/local/lib/libabcdef.so.2.2.0,link:/usr/local/lib/libabcdef.so,\
# link:/usr/local/lib/libabcdef.so.2
# ensure=all
#
# The above configuration might create the following file structure:
#
# /
# ├── /usr/local/lib/libabcdef.a
# ├── /usr/local/lib/libabcdef.la
# ├── /usr/local/lib/libabcdef.so -> /usr/local/lib/libabcdef.so.2.2.0
# ├── /usr/local/lib/libabcdef.so.2 -> /usr/local/lib/libabcdef.so.2.2.0
# ├── /usr/local/lib/libabcdef.so.2.2.0
# └── pkgconfig
#     └── /usr/local/lib/libabcdef.pc

use File::Basename;
use Moose;
use Data::Dumper;
use Ningyou::Util;
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

sub init {
    my ( $s, $i ) = @_;

    return $i;
}

sub apply {
    my ( $s, $i ) = @_;
    my $ca = exists $i->{cache}    ? $i->{cache}    : die 'no cache';
    my $iv = exists $i->{object}   ? $i->{object}   : die 'no object';
    my $pr = exists $i->{provider} ? $i->{provider} : die 'no provider';
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die 'no cfg';
    my $mt = exists $i->{mt}       ? $i->{mt}       : die 'no mt';

    my $mo = $c->{module};
    die "ERR: no 'source=' in [$mo]\n" if not exists $c->{source};

    # calculated
    my $o  = $s->get_options;
    my $u  = Ningyou::Util->new( { options => $o } );
    my $so = $u->source_to_fqfn(
        { module => $mo, moduletree => $mt, source => $c->{source} } );
    my $di  = "$mt/$mo/files";
    my $ur  = ( exists $c->{url} and defined $c->{url} ) ? $c->{url} : 0;
    my @cmd = ();
    if ( not -e $so ) {
        if ($ur) {
            $s->d("no source [$so], but url [$ur]");
            push @cmd, "mkdir $di" if not -d $di;
            $s->d("download url [$ur]");
            push @cmd, "cd $di && wget -q  $ur";
        }
        else {
            die "ERR: no source [$so] and no url= in [$mo]\n";
        }
    }
    my ( $bds, $bdm ) = gettimeofday;
    my $bd = "/tmp/ningyou-$bds.$bdm";
    push @cmd, "mkdir -p $bd";
    push @cmd, "cd $bd";
    my $tar = basename($so);
    push @cmd, "cp $so .";
    push @cmd,
          q{perl -e 'use Archive::Tar;my $t=Archive::Tar->new;$t->read("}
        . $tar
        . q{");$t->extract();'};

    if ( exists $c->{archive} and $c->{archive} ) {
        push @cmd, "cd $c->{archive}";
    }
    else {
        # guess archive stem (better provide: archive=)
        my $ar = $tar;
        $ar =~ s{(.*)\.(tar|tar.gz|tgz|tar.bz2|tbz)$}{$1}gmx;
        push @cmd, "cd $ar";
    }
    push @cmd, "./configure" if exists $c->{configure} and $c->{configure};
    push @cmd, "make"        if exists $c->{make}      and $c->{make};
    push @cmd, "make install"
        if exists $c->{'make-install'} and $c->{'make-install'};
    push @cmd, $c->{post} if exists $c->{post} and $c->{post};

    my $rcmd = join q{ && }, @cmd;
    return $rcmd;
}

sub applied {
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    my $mo = exists $c->{module} ? $c->{module} : die "no [module] in i.ini";

    if ( exists $c->{ensure} and $c->{ensure} eq 'all' ) {
        my $pv
            = exists $c->{provides}
            ? $c->{provides}
            : die "ERR: provides= missing in [$mo]\n";

        # test all entities in ensure=*
        my @e = split q{,}, $pv;
        foreach my $e (@e) {
            my ( $p, $o ) = split q{:}, $e;
            $p =~ s{(^s\+|\s+$)}{}gmx;
            $o =~ s{(^s\+|\s+$)}{}gmx;
            die "ERR: provider missing in PROVIDER:OBJECT for [$e] in [$mo]\n"
                if not defined $o;
            $s->d("Provider::Tar::applied e [$e] [$p] [$o]\n");
            if ( $p eq 'file' ) {
                return 0 if not -e $o;
                $s->d("$o is file -> OK\n");
            }
            elsif ( $p eq 'dir' ) {
                return 0 if not -d $o;
                $s->d("$o is dir -> OK\n");
            }
            elsif ( $p eq 'link' ) {
                return 0 if not -l $o;
                $s->d("$o is link -> OK\n");
            }
            else {
                die "ERR: unknown provider [$p] for [$e] in [$mo]\n"
                    if not defined $o;
            }
            $s->d("next");
        }
        return 1;
    }
    else {
        # only object in [tar:<OBJECT>] is tested
        return 1 if -e $iv;
    }
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Tar - handle source code software comming in tar archives

=cut


