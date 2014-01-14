package Ningyou::Provider::Package;
use Moose;
use Data::Dumper;
use namespace::autoclean;
our $VERSION = '0.0.6';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

has 'r' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_r',
    writer  => 'set_r',
    builder => 'init',
    lazy    => 1,
);

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
    my $cmd = '/usr/bin/dpkg-query';
    my @q = qx($cmd -W --showformat '\${Status};\${Package};\${Version}\\n');
    $s->d("INIT");
    foreach my $q (@q) {
        chomp $q;

        # install ok installed xsltproc 1.1.26-6+squeeze3
        my ( $status, $package, $version ) = split /;/, $q;
        $i->{package}->{$package}->{version} = $version;
        $i->{package}->{$package}->{status}  = $status;
    }
    $s->set_r($i);
    return $i;
}

sub install {
    my ( $s, $i ) = @_;
    my $ca = exists $i->{cache}    ? $i->{cache}    : die 'no cache';
    my $iv = exists $i->{object}   ? $i->{object}   : die 'no object';
    my $pr = exists $i->{provider} ? $i->{provider} : die 'no provider';
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die 'no cfg';
    my $wt = exists $i->{wt}       ? $i->{wt}       : die 'no wt';

    my $fl = exists $i->{aptitude} ? $i->{aptitude} : q{};

    my $mo  = $c->{module};
    my $cmd = "aptitude $fl install $iv";
    $cmd =~s{\s+}{ }gmx;

     return $cmd;
}

sub installed {
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    my $r = $s->get_r;

    return 1 if exists $r->{$pr}->{$iv}->{version};
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Package - handle software packages

=cut


