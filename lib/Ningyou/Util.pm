package Ningyou::Util;

use Moose;
use Data::Dumper;
use namespace::autoclean;
our $VERSION = '0.0.2';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

has 'options' => (
    is       => 'rw',
    isa      => 'HashRef',
    reader   => 'get_options',
    writer   => 'set_options',
    default  => sub { return {}; },
    required => 1,
);

my $id = q{ } x 10;

sub source_to_fqfn {
    my ( $s, $i ) = @_;
    my $wt = exists $i->{worktree} ? $i->{worktree} : die "no [worktree]";
    my $mo = exists $i->{module}   ? $i->{module}   : die "no [module]";
    my $so = exists $i->{source}   ? $i->{source}   : return undef;
    my $oso = $so;
    die "Malformed URL! [$so] is not of the form [ningyou:///<MODULE>/*]\n"
        if not $so =~ m{ningyou:///.+}mx;

    $s->d("$id source_to_fqfn: [$so] -> - worktree");
    $so =~ s{ningyou:///modules/}{$wt/};
    $s->d("$id source_to_fqfn: [$so] -> + files");
    $so =~ s{/$mo/}{/$mo/files/};
    $s->d("$id source_to_fqfn: [$so]  -> -e");
    $s->v("$id source URL [$oso] points to [$so]");

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

    $s->d("$id calculate md5 [$digest]");
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

            my ( $out, $err, $res ) = $nc->cmd('/usr/bin/facter');
            my @out = split /\n/, $out;
            foreach my $o (@out) {
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

1;

__END__

=pod

=head1 NAME

Ningyou::Util - aux. utils for Ningyou

=cut

