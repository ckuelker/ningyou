package Ningyou::Provider::Git;
use Moose;
use File::Basename;
use namespace::autoclean;
our $VERSION = '0.0.7';

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
    my $iv = exists $i->{object} ? $i->{object} : die 'no [object]';
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die "no [cfg]";
    my $o  = $s->get_options;
    my $m  = "ERROR: no [source] field!\n";
    die $m if not exists $c->{source};
    my $rep     = $c->{source};
    my $dirname = dirname($iv);

    my $sudo = exists $c->{user} ? 'sudo -u ' . $c->{user} : q{};
    my $cmd = "cd $dirname && $sudo git clone $rep";
    $s->v("$id provision will be via this commando:\n        [$cmd]");
    return $cmd;
}

sub installed {
    my ( $s, $i ) = @_;
    my $iv = exists $i->{object} ? $i->{object} : die "no [object]";
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die "no [cfg]";
    my $m  = "ERROR: no [source] field!\n";
    die $m if not exists $c->{source};

    #gitosis@s:todo.git
    my $rep = $c->{source};
    $rep =~ s{^.*:}{}gmx;
    $rep =~ s{\.git$}{}gmx;

    $s->v("$id the git repository is NOT cloned") if not -d $iv;

    # INSTALL check
    return 1 if -d $iv;
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Git  - handle git repositories

=cut


