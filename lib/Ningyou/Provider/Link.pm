package Ningyou::Provider::Link;
use Data::Dumper;
use Moose;
use namespace::autoclean;
use Ningyou::Util;
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

my $id = q{ } x 8;

sub apply {
    my ( $s, $i ) = @_;

    # if no cache is desired then ca can be {}
    my $ca = exists $i->{cache}  ? $i->{cache}  : die 'no cache';
    my $iv = exists $i->{object} ? $i->{object} : die 'no object';
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die 'no cfg';

    # shorten config attributes
    my $mo = exists $c->{module}  ? $c->{module}  : die 'no module';
    my $so = exists $c->{source} ? $c->{source} : die 'no source';
    my $en = exists $c->{ensure} ? $c->{ensure} : 'created';
    my $ow = exists $c->{owner}  ? $c->{owner}  : 'root';
    my $gr = exists $c->{group}  ? $c->{group}  : 'root';

    # calculated
    my $o = $s->get_options;

    my $u = Ningyou::Util->new( { options => $o } );
    my $cmd = q{};

    if ( -e $iv and $so and $en eq 'removed' ) {
        $s->v("$id link [$iv] exist and it should be removed");
        $cmd = "rm $iv";
    }
    elsif ( not -e $iv and $so and $en eq 'created' ) {
        $s->v("$id link [$iv] do NOT exist and it should be copied");
        $cmd = "ln -s $so $iv && chown $ow $iv && chgrp $gr $iv";
    }
    elsif ( $iv and not $so ) {
        my $m
            = "ERROR: Unhandled sitation in [$mo] at section link:$iv\n"
            . " Most likely this is caused by a logical misconfiguration.\n"
            . " Known mistakes: \n"
            . "   - not specified source\n";
        die $m;
    }
    elsif ( $en ne 'removed' and $en ne 'created' ) {
        my $m
            = "ERROR: Unhandled sitation in [$mo] at section link:$iv\n"
            . " Most likely this is caused by a logical misconfiguration.\n"
            . " Known mistakes: \n"
            . "   - ensure is not 'removed' or 'created'\n";
        die $m;
    }
    else {
        $cmd = "NOP";
    }

    $s->d("$id cmd [$cmd]");
    return $cmd;
}

sub applied {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $cmd = $s->apply($i);
    return 1 if $cmd =~ m/^NOP/mx;
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Link - handle (symbolic) links

=cut


