package Ningyou::Provider::Chmod;
use Moose;
use Ningyou::Util;
use namespace::autoclean;
use File::stat;
our $VERSION = '0.0.6';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# FORMAT
# [chmod:/path/to/file]
#     moder = root
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
    my $wt = exists $i->{wt}     ? $i->{wt}     : die 'no wt';

    # shorten config attributes
    my $ow = exists $c->{mode} ? $c->{mode} : 'root';
    my $mo = exists $c->{module} ? $c->{module} : die 'no module';

    $s->d('debug output for Ningyou::Provider::Chmod');

    # calculated
    my $cmd = "chmod $ow $iv";

    $s->v("$id cmd [$cmd]\n");
    return $cmd;
}

sub applied {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    my $md0 = sprintf('%o', (stat $iv)[2] & 07777);
    my $md1 = exists $c->{mode} ? $c->{mode} : '0644';

    return 1 if $md0 eq $md1;
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Chmod - handle modes

=cut


