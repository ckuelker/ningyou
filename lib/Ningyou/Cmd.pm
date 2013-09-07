package Ningyou::Cmd;

# For the moment Capture::Tiny do the same as Capture::Tiny::Extended If this
# should not be the case: read slides for Capture::Tiny::Extended
# use Capture::Tiny::Extended 'tee';
use Capture::Tiny 'tee';
use Moose;
use namespace::autoclean;
our $VERSION = '0.0.2';

sub cmd {
    my ( $s, $cmd ) = @_;
    my ( $out, $err, $res ) = tee( sub { return system($cmd); } );
    if ($err) {
        warn "ERROR 42: executing command with error state\n";
        warn "          cmd:   [$cmd]\n";
        warn "          value: [$res]\n" if $res;
        warn "          error: $err\n";
        die "(stopping here)\n";
    }
    return ( $out, $err, $res );
}
1;
__END__

=pod

=head1 NAME

Ningou::Cmd - Execute external commands


=cut
