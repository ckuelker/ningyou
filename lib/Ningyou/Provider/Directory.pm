package Ningyou::Provider::Directory;
use Data::Dumper;
use Digest::MD5;
use Moose;
use namespace::autoclean;
use Ningyou::Util;
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

my $id = q{ } x 8;

sub install {
    my ( $s, $i ) = @_;

    # if no cache is desiredm then ca can be {}
    my $ca = exists $i->{cache}    ? $i->{cache}    : die 'no cache';
    my $iv = exists $i->{object}   ? $i->{object}   : die 'no object';
    my $pr = exists $i->{provider} ? $i->{provider} : die 'no provider';
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die 'no cfg';
    my $wt = exists $i->{wt}       ? $i->{wt}       : die 'no wt';

    # shorten config attributes
    my $ow = exists $c->{owner}  ? $c->{owner}  : 'root';
    my $gr = exists $c->{group}  ? $c->{group}  : 'root';
    my $en = exists $c->{ensure} ? $c->{ensure} : 'latest';
    my $mo = exists $c->{class}  ? $c->{class}  : die 'no class';

    # controller options for rsync
    my $cm = exists $c->{mode}    ? " --chmod=" . $c->{mode} . " " : q{};
    my $pu = exists $c->{purge}   ? " --delete "                   : q{};
    my $dr = exists $i->{dryrun}  ? " --dry-run "                  : q{};
    my $it = exists $i->{itemize} ? " --itemize-changes "          : q{};
    my $ba = exists $i->{base}    ? " $i->{base} "                 : " -avP ";

    # calculated
    my $o = $s->get_options;
    my $u = Ningyou::Util->new( { options => $o } );
    my $so
        = exists $c->{source}
        ? $u->source_to_fqfn(
        { module => $mo, worktree => $wt, source => $c->{source} } )
        : 0;

    my $cmd = q{};

    $s->d("$id so [$so]\n") if $so;

    $s->v("$id provider [$pr]\n");
    if ( -d $iv and $en eq 'removed' ) {
        $s->v("$id dir [$iv] exists and should be removed\n");
        $cmd = "rmdir $iv";
    }
    elsif ( not -d $iv and $so ) {
        $s->v("$id dir [$iv] do NOT exists and should be synced\n");
        $so = $so . q{/};
        $so =~ s{//$}{/}gmx;    # bar -> bar/  | bar/ -> bar/
        $cmd = "rsync $dr $ba $it --owner=$ow --group=$gr $cm $pu $so $iv";
    }
    elsif ( not -d $iv and not $so ) {
        $s->v("$id dir [$iv] do NOT exists and should be created\n");
        $cmd = "mkdir -p $iv";
    }
    else {

        # my $m
        #     = "ERROR: Unhandled sitation in $mo at section $pr:$iv\n"
        #     . " Most likely this is caused by a logical misconfiguration.\n"
        #     . " Known mistakes: \n"
        #     . "   - ?\n";
        # die $m;
        $cmd = "NOP";
    }

    # TODO: test success
    #$cmd = "NOP 006";
    $s->v("$id cmd [$cmd]\n");
    return $cmd;
}

sub installed {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $cmd = $s->install($i);
    return 1 if $cmd =~ m/^NOP/mx;
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Cpan - handle directories

=cut


