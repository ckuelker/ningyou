package Ningyou::Provider::Directory;
use Data::Dumper;
use Digest::MD5;
use Moose;
use namespace::autoclean;
use Ningyou::Util;
our $VERSION = '0.0.3';

with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

has 'options' => (
    is       => 'rw',
    isa      => 'HashRef',
    reader   => 'get_options',
    writer   => 'set_options',
    default  => sub { return {}; },
    required => 1,
);

sub install {
    my ( $s, $i ) = @_;

    # if no cache is desired, then ca can be {}
    my $ca = exists $i->{cache}    ? $i->{cache}    : die 'no cache';
    my $iv = exists $i->{object}   ? $i->{object}   : die 'no object';
    my $pr = exists $i->{provider} ? $i->{provider} : die 'no provider';
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die 'no cfg';
    my $wt = exists $i->{wt}       ? $i->{wt}       : die 'no wt';

    # shorten config attributes
    my $ow = exists $c->{owner}  ? $c->{owner}  : 'root';
    my $gr = exists $c->{group}  ? $c->{group}  : 'root';
    my $md = exists $c->{mode}   ? $c->{mode}   : '0755';
    my $en = exists $c->{ensure} ? $c->{ensure} : 'latest';
    my $mo = exists $c->{module} ? $c->{module} : die 'no module';

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

    my $cmd = undef;

    $s->d("so [$so]\n") if $so;

    $s->v("  * Install provider [$pr]\n");

    # if dir exists and ensured = removed: remove dir (not recursive)
    if ( -d $iv and $en eq 'remove' ) {
        $s->v("  * dir [$iv] exists and should be removed\n");
        $cmd = "rmdir $iv";
    }

    # if dir do NOT exists and source exists: sync it
    elsif ( not -d $iv and $so ) {
        $s->v("* dir [$iv] do NOT exists and should be synced\n");
        $so = $so . q{/};
        $so =~ s{//$}{/}gmx;    # bar -> bar/  | bar/ -> bar/
        $cmd = "rsync $dr $ba $it --owner=$ow --group=$gr $cm $pu $so $iv";
    }

    # seems that we have to RESYNC it, TODO: merge with previous?
    elsif ( -d $iv and $so ) {
        $s->v("* dir [$iv] DO exists and should be RESYNCED\n");
        $so = $so . q{/};
        $so =~ s{//$}{/}gmx;    # bar -> bar/  | bar/ -> bar/
        $cmd = "rsync $dr $ba $it --owner=$ow --group=$gr $cm $pu $so $iv";
    }

    # if dir do NOT exists and source do NOT exists: mkdir
    elsif ( not -d $iv and not $so ) {
        $s->v("* dir [$iv] do NOT exists and should be created\n");
        $cmd
            = "mkdir -p $iv && chmod $md $iv && chown $ow $iv && chgrp $gr $iv";
    }
    else {
        $s->v(" * directory: NOP\n");

         my $m
             = "ERROR: Unhandled sitation in $mo at section $pr:$iv\n"
             . " Most likely this is caused by a logical misconfiguration.\n"
             . " Known mistakes: \n"
             . "   - rsync mode for mkdir?\n";
         die $m;
    }
    $cmd =~s{\s+}{ }gmx;
    $s->v("cmd [$cmd]\n") if defined $cmd;
    return $cmd;
}

# Example $i:
#          'base' => '-a',
#          'provider' => 'directory',
#          'object' => '/home/c/bin',
#          'itemize' => 1,
#          'wt' => '/home/c/g/ningyou/linux-debian-wheezy/modules',
#          'cfg' => {
#                     'owner' => 'c',
#                     'source' => 'ningyou:///modules/home-bin/bin',
#                     'require' => 'package:zsh',
#                     'group' => 'c',
#                     'mode' => 'Fo-x',
#                     'module' => 'home-bin',
#                     'purge' => '1'
#                   },
#          'dryrun' => 1,
#          'cache' => {}
#        };
sub installed {    # alias for "action needed"
    my ( $s, $i ) = @_;
    my $iv = exists $i->{object} ? $i->{object} : die 'no object';
    my $wt = exists $i->{wt}     ? $i->{wt}     : die 'no wt';
    my $c  = exists $i->{cfg}    ? $i->{cfg}    : die 'no cfg';
    my $mo = exists $c->{module} ? $c->{module} : die 'no module';
    my $o  = $s->get_options;
    my $u = Ningyou::Util->new( { options => $o } );
    my $so
        = exists $c->{source}
        ? $u->source_to_fqfn(
        { module => $mo, worktree => $wt, source => $c->{source} } )
        : 0;

    if ( not $so ) {    # no source given, aka mkdir directory only
        if ( -d $iv ) {
            $s->d("xxx A: [YES]\n");
            return 1;
        }
        else {
            $s->d("xxx A: [NO]\n");
            return 0;

        }

    }

    my $d1 = $so;
    my $d2 = $iv;
    use Carp;
    carp "d1 [$d1] not a directory" if not -d $d1;
    carp "d2 [$d2] not a directory" if not -d $d2;
    $s->v("  - Q: is  [$d2] and \n");
    $s->v("    [$d1]\n");
    $s->v("    equal?\n");
    my $equal = $u->compare_dirs( $d1, $d2 );

    if ($equal) {
        $s->v("  - A: [YES] both directories are equal.\n");
    }
    else {
        $s->v("  - A: [NO] both directories are different.\n");
    }
    return $equal;
}
1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Cpan - handle directories

=cut


