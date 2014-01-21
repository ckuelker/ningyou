package Ningyou::Provider::Chgrp;
use Moose;
use Ningyou::Util;
use namespace::autoclean;
our $VERSION = '0.0.8';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# FORMAT 
#   MANDATORY
#     [chgrp:/path/to/file]
#   AUX
#     group = root  (defaults to root)

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
    my $ow = exists $c->{group} ? $c->{group} : 'root';
    my $mo = exists $c->{module} ? $c->{module} : die 'no module';

    $s->d('debug output for Ningyou::Provider::Chgrp');

    # calculated
    my $cmd = "chgrp $ow $iv";

    $s->v("$id cmd [$cmd]\n");
    return $cmd;
}

sub applied {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    my $gid = ( stat $iv )[5];
    my $gr0 = ( getgrgid $gid )[0];
    my $gr1 = exists $c->{group} ? $c->{group} : 'root';

    return 1 if $gr0 eq $gr1;
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Chgrp - handle groups

=cut


