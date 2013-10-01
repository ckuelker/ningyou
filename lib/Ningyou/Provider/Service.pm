package Ningyou::Provider::Service;
use Moose;
use Ningyou::Util;
use Data::Dumper;
use namespace::autoclean;
our $VERSION = '0.0.3';

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

# FORMAT:
# [service:/etc/init.d/ssh]
#     ensure=started|stopped
#     require=[x:y]

# BUGS:
# * Status will be checked with "status" (not "show" or others)
# * Some init scripts do not suport "status"

sub install {
    my ( $s, $i ) = @_;

    # if no cache is desiredm then ca can be {}
    my $ca = exists $i->{cache}  ? $i->{cache}  : die 'no cache';
    my $iv = exists $i->{object} ? $i->{object} : die 'no object';
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die 'no cfg';

    # shorten config attributes
    my $en = exists $c->{ensure} ? $c->{ensure} : 'latest';
    my $mo = exists $c->{module}  ? $c->{module}  : die 'no module';

    # calculated
    my $o = $s->get_options;
    my $u = Ningyou::Util->new( { options => $o } );

    my $cmd = q{};

    if ( -e $iv and $en eq 'started' ) {
        $s->v("$id file [$iv] exist and service should be started\n");
        $cmd = "$iv start";
    }
    elsif ( -e $iv and $en eq 'stopped' ) {
        $s->v("$id file [$iv] exist and service should be stopped\n");
        $cmd = "$iv stop";
    }
    elsif ( not -e $iv ) {
        my $m
            = "ERROR: Unhandled sitation in [$mo] at section [service:$iv]\n"
            . " Most likely this is caused by a logical misconfiguration.\n"
            . " Known mistakes: \n"
            . "   - file [$iv] do not exist\n";
        die $m;
    }
    elsif ( $en ne 'started' and $en ne 'stopped' ) {
        my $m
            = "ERROR: Unhandled sitation in [$mo] at section [service:$iv]\n"
            . " Most likely this is caused by a logical misconfiguration.\n"
            . " Known mistakes: \n"
            . "   - ensure is not [started] or [stopped]\n";
        die $m;
    }
    else {
        $cmd = "NOP";
    }

    # TODO: test success
    $s->v("$id cmd [$cmd]\n");
    return $cmd;
}

sub installed {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $iv = exists $i->{object} ? $i->{object} : die "no [object]";
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die "no [cfg]";
    my $m  = "ERROR: no [ensure] field!\n";
    die $m if not exists $c->{ensure};
    die "ERROR: No service file [$iv]!" if not -e $iv;
    my $status = 0;
    eval { system(qq{$iv status > /dev/null 2>&1}); };
    my $e = defined $? ? $? : 0;
    if   ($e) { $status = 0; }
    else      { $status = 1; }

    return $status;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Service - handle system services

=cut


