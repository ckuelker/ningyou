# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Execute                                          |
# |                                                                           |
# | Run shell commands                                                        |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-02 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Execute;

# ABSTRACT: Run shell commands

# For the moment Capture::Tiny do the same as Capture::Tiny::Extended If this
# should not be the case: read slides for Capture::Tiny::Extended
# use Capture::Tiny::Extended 'tee';
use Capture::Tiny qw(tee capture);
use Moose::Role;
use namespace::autoclean;
use Data::Dumper;

our $version = '0.1.0';

sub evaluate_quite {
    my ( $s, $cmd ) = @_;
    my ( $out, $err, $res ) = capture { return system($cmd); };
    return ( $out, $err, $res );
}

sub evaluate {
    my ( $s, $cmd ) = @_;
    print "$cmd\n";
    my ( $out, $err, $res ) = tee { return system($cmd); };
    return ( $out, $err, $res );
}

sub execute_quite {
    my ( $s, $cmd ) = @_;
    my ( $out, $err, $res ) = capture { return system($cmd); };
    my $RES = ( defined $res and $res ) ? $res >> 8 : 0;
    if ($RES) {
        warn "=" x 80 . "\n";
        warn "ERROR: executing command with error state\n";
        warn "          cmd:   [$cmd]\n";
        warn "          res:   [$res]\n" if $res;
        warn "    shell res:   [$RES]\n";
        warn "          error: $err\n";
        warn "=" x 80 . "\n";
        die "(stopping here)\n";
    }
    return ( $out, $err, $res );
}

sub execute {
    my ( $s, $cmd ) = @_;

    #my ( $out, $err, $res ) = tee( sub { return system($cmd); } );
    my ( $out, $err, $res ) = tee { return system($cmd); };
    my $RES = ( defined $res and $res ) ? $res >> 8 : 0;
    if ($RES) {
        warn "=" x 80 . "\n";
        warn "ERROR: executing command with error state\n";
        warn "          cmd:   [$cmd]\n";
        warn "          res:   [$res]\n" if $res;
        warn "    shell res:   [$RES]\n";
        warn "          error: $err\n";
        warn "=" x 80 . "\n";
        die "(stopping here)\n";
    }
    return ( $out, $err, $res );
}

# IN:
#   cmd:        [ {cmd=>'command',verbose=>'msg'},.. ]
#   verbose:    0|1
# OUT:
#  1: gr - global return value:             0|1
#  2: cs - command stack with verbose msg:  [ {cmd=>command,verbose=>msg},.. ]
#  3: os - output stack:                    [ STDOUT, .. ]
#  4: es - error stack:                     [ msg, .. ]
#  5: rs - resut stack:                     [ 0|1, .. ]
#
# EXAMPLE:
#    $s->execute_stack( {
#                         cmd => [
#                                  {              verbose => 'hello world },
#                                  { cmd => 'ls', verbose => 'list stuff' },
#                                ],
#                         verbose => 0
#                       } );
# TODO: rename '2ns verbose to something else like 'print'
sub execute_stack {
    my ( $s, $i ) = @_;
    my $cmd = exists $i->{cmd} ? $i->{cmd} : $s->e( 'no [cmd]', 'sp' );
    my $verbose
        = ( exists $i->{verbose} and defined $i->{verbose} and $i->{verbose} )
        ? $i->{verbose}
        : 0;

    my $gr = 1;     # global return value
    my @cs = ();    # command stack with verbose messages
    my @os = ();    # output stack
    my @es = ();    # error stack
    my @rs = ();    # resut stack

    # [ {verbose=>'hello world'},{cmd=>'ls',verbose=>'list stuff'}, ... ]
    # it is OK if 'cmd' do not exists
    foreach my $hr ( @{$cmd} ) {
        if ( ref($hr) ne 'HASH' ) {
            $s->w("BUG. Expect hr to be a hash reference" . Dumper($cmd));
            next;
        }
        my $c = exists $hr->{cmd}     ? $hr->{cmd}     : undef;
        my $v = exists $hr->{verbose} ? $hr->{verbose} : undef;
        chomp $v if defined $v;
        $s->p("$v\n") if defined $v and $verbose and $v ne q{};
        if ( defined $c ) {
            my ( $out, $err, $res ) = $s->execute($c);
            push @cs, { cmd => $c, verbose => $v };
            push @os, $out;
            push @es, $err;
            push @rs, $res;    # shell result 0=PASS,1=FAIL
            $gr = 0 if $err;
            $gr = 0 if $res;    # shell result 0=PASS,1=FAIL
            if ($verbose) {
                my $fmt = "  %-71s [%s]\n";
                if ( not $res ) {    # PASS
                    $s->p( sprintf $fmt, $c, $s->c( 'yes', 'PASS' ) );
                }
                else {               # FAIL
                    $s->p( sprintf $fmt, $c, $s->c( 'no', 'FAIL' ) );
                    $s->p("$err\n");
                }
            }
        }
    }
    return ( $gr, \@cs, \@os, \@es, \@rs );
}

no Moose;

1;
__END__

=pod

=head1 NAME

Ningou::Execute - Execute external commands

=cut
