package Ningyou::Provider::File;
use Moose;
use Digest::MD5;
use Ningyou::Util;
use namespace::autoclean;
our $VERSION = '0.0.9';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# FORMAT MANDATORY
# [file:/path/to/file]
# FORMAT OPTIONALLY
#     source   = ningyou:///modules/kvm-smtp-cipworx-org/qemu
#     owner    = root
#     group    = root
#     sensure  = latest
#     checksum = md5   (for checksum source is mandatory)

has 'options' => (
    is       => 'rw',
    isa      => 'HashRef',
    reader   => 'get_options',
    writer   => 'set_options',
    default  => sub { return {}; },
    required => 1,
);

sub apply {
    my ( $s, $i ) = @_;
use Data::Dumper;
    my $o = $s->get_options;

    #use Data::Dumper;die Dumper($o);
    # if no cache is desiredm then ca can be {}
    my $ca = exists $i->{cache}  ? $i->{cache}  : die 'no cache';
    my $iv = exists $i->{object} ? $i->{object} : die 'no object';
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die 'no cfg';
    my $wt = exists $i->{wt}     ? $i->{wt}     : die 'no wt';

    # shorten config attributes
    my $cs = exists $c->{checksum} ? $c->{checksum} : 0;
    my $ow = exists $c->{owner}    ? $c->{owner}    : 'root';
    my $gr = exists $c->{group}    ? $c->{group}    : 'root';
    my $md = exists $c->{mode}     ? $c->{mode}     : '0644';
    my $en = exists $c->{ensure}   ? $c->{ensure}   : 'latest';
    my $mo = exists $c->{module}   ? $c->{module}   : confess "no module in cfg\n" . Dumper($c);

    $s->d('debug output for Ningyou::Provider::File');

    # calculated
    my $cmd = q{};
    my $u   = Ningyou::Util->new( { options => $o } );
    my $pr  = 'file';
    my $so
        = exists $c->{source}
        ? $u->source_to_fqfn(
        { module => $mo, worktree => $wt, source => $c->{source} } )
        : 0;
    $s->d("source [$so]");

    # if file exists and it should be removed:
    if ( -e $iv and $en eq 'removed' ) {
        $s->v("  file [$iv] exist and it should be removed");
        $cmd = "rm $iv";
    }

    # if file exists and exists checksum and exists source and
    # checksum to matching
    elsif ( -e $iv
        and $cs
        and $so
        and not $u->file_md5_eq( $ca, $iv, $so ) )
    {
        $s->v("  file [$iv] do exist and it should be copied, MD5 differ");
        $cmd
            = "cp $so $iv && chmod $md $iv && chown $ow $iv && chgrp $gr $iv";
    }

    # if do not exists and also not source, then just touch it
    elsif ( not -e $iv and not $so ) {
        $s->v(
            "  file [$iv] do exist and it should be created without source\n"
        );
        $cmd = "touch $iv";
    }

    # if file do not exists
    elsif ( not -e $iv ) {
        $s->v("  file [$iv] do NOT exist and it should be copied");
        $cmd
            = "cp $so $iv && chmod $md $iv && chown $ow $iv && chgrp $gr $iv";
    }

    # do we have a checksum but no source?
    elsif ( $cs and not $so ) {
        my $m
            = "ERROR: Unhandled sitation in $mo at section $pr:$iv\n"
            . " Most likely this is caused by a logical misconfiguration.\n"
            . " Known mistakes: \n"
            . "   - request checksum but not specify source\n";
        die $m;
    }
    else {
        $cmd = "NOP";
    }

    $s->d("  cmd [$cmd]\n");
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

Ningyou::Provider::File - handle files

=cut


