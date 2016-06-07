package Ningyou::Provider::Cmd;
use Moose;
use Ningyou::Util;
use namespace::autoclean;
use File::stat;
our $VERSION = '0.0.9';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# FORMAT
# [cmd:start-kvm-default-network]
#     execute = virsh net-start default
#     <provide=/root/.ningyou/cmd/start-kvm-default-network>
#

has 'options' => (
    is       => 'rw',
    isa      => 'HashRef',
    reader   => 'get_options',
    writer   => 'set_options',
    default  => sub { return {}; },
    required => 1,
);

my $id = q{ } x 8;

sub apply {
    my ( $s, $i ) = @_;

    my $o = $s->get_options;

    #use Data::Dumper;die Dumper($o);
    # if no cache is desiredm then ca can be {}
    my $ca = exists $i->{cache}  ? $i->{cache}  : die 'no cache';
    my $iv = exists $i->{object} ? $i->{object} : die 'no object';
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die 'no cfg';
    my $mt = exists $i->{mt}     ? $i->{mt}     : die 'no mt';

    # shorten config attributes
    my $ow = exists $c->{mode}   ? $c->{mode}   : 'root';
    my $mo = exists $c->{module} ? $c->{module} : die 'no module';

    $s->d('debug output for Ningyou::Provider::Chmod');

    # calculated
    my $cmd = exists $c->{execute} ? $c->{execute} : die 'no execute!';

    $s->v("$id cmd [$cmd]\n");
    return $cmd;
}

sub applied {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    return 1 if exists $c->{provide} and -e $c->{provide};
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Cmd - executes commands

=cut


