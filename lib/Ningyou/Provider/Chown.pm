package Ningyou::Provider::Chown;
use Moose;
use Ningyou::Util;
use namespace::autoclean;
our $VERSION = '0.0.6';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# FORMAT
#   MANDATORY
#     [chown:/path/to/file]
#   AUX
#     owner = root (defaults to root, if not given)

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
    my $ow = exists $c->{owner} ? $c->{owner} : 'root';
    my $mo = exists $c->{module} ? $c->{module} : die 'no module';

    $s->d('debug output for Ningyou::Provider::Chown');

    # calculated
    my $cmd = "chown $ow $iv";

    $s->v("$id cmd [$cmd]\n");
    return $cmd;
}

sub applied {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    my $uid = ( stat $iv )[4];
    my $ow0 = ( getpwuid $uid )[0];
    my $ow1 = exists $c->{owner} ? $c->{owner} : 'root';

    return 1 if $ow0 eq $ow1;
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Chown - handle owners

=cut


