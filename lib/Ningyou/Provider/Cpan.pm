package Ningyou::Provider::Cpan;
use Data::Dumper;
use File::Basename;
use Moose;
use namespace::autoclean;
our $VERSION = '0.0.6';

# GLOBAL MANDATORY
# [cpan:yare-dzil]
#  source=ningyou:///modules/yare-cpan/src
#  method=makefile-pl|dzil|cpanm|build-pl|cpan   (Default makefile-pl)

# GLOBAL AUX
# require=package:libgit-repository-perl,libgit-wrapper-perl,libterm-shell-perl,libdigest-md5-file-perl,libmoose-perl
# perl5lib-env=/srv/env/env-perl-5-14-2  (this will install in PERL5LIB)
# tmpdir=/tmp  (default)

# THINK
# ;perl5lib=/srv/perl-5.14.2
# ;perl7lib-user=c

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
    my $ca = exists $i->{cache}    ? $i->{cache}    : die 'no cache';
    my $iv = exists $i->{object}   ? $i->{object}   : die 'no object';
    my $pr = exists $i->{provider} ? $i->{provider} : die 'no provider';
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die 'no cfg';
    my $wt = exists $i->{wt}       ? $i->{wt}       : die 'no wt';

    my $mo = $c->{module};
    my $o  = $s->get_options;

    my @cmd = ();
    my $u = Ningyou::Util->new( {} );

    my $so = $u->source_to_fqfn(
        { module => $mo, worktree => $wt, source => $c->{'source'} } );
    $s->d("$id so [$so]");
    my $env = q{};
    if ( exists $c->{'perl5lib'} ) {
        $env = "PERL5LIB=$c->{'perl5lib'}:\$PERL5LIB";
    }

    if ( defined $so and -d $so ) {
        push @cmd, "cd $so&&";
    }
    elsif ( defined $so and -e $so ) {
        my $bn = basename( $so, ( '.tar.gz', '.tgz' ) );
        if ( exists $c->{tmpdir} ) {
            push @cmd, "cd $c->{tmpdir} && tar xvzf $so && cd $bn";
        }
        else {
            push @cmd, "cd /tmp && tar xvzf $so && cd $bn";
        }
    }
    elsif ( defined $so ) {
        my $m = "ERROR: in [$mo] defined field [source]"
            . " pointing towards Nirvana:\n$so\n";
        die $m;
    }
    if ( $c->{'method'} eq 'build-pl' ) {
        my $c
            = "perl Build.PL && ./Build build && ./Build test && $env ./Build install";
        push @cmd, $c;
    }
    elsif ( $c->{'method'} eq 'dzil' ) {
        push @cmd, "$env dzil install $so";
    }
    else {
        push @cmd, "perl Makefile.PL && make && make test && $env make install";
    }

    my $cmd = join q{ && }, @cmd;
    $cmd =~ s{\s+&&\s+}{ && };

    return  $cmd;
}

sub applied {
    my ( $s, $i ) = @_;
    my $c  = exists $i->{cfg}      ? $i->{cfg}      : die "no [cfg]";
    my $pr = exists $i->{provider} ? $i->{provider} : die "no [provider]";
    my $iv = exists $i->{object}   ? $i->{object}   : die "no [object]";

    # ERROR handling
    if ( not exists $c->{provide} ) {
        my $mo = $c->{module};
        my $m  = "ERROR in configuration! In module [$mo]\n";
        $m .= "at section [$pr:$iv] the [provide] field is missing.\n";
        $m .= "(stopping here)\n";
        die $m;
    }

    # INSTALL check
    my $inc = exists $c->{include} ? " -I " . $c->{include} : q{};
    my $p = $c->{provide};
    if ( exists $c->{version} ) {
        $s->v("    check version $c->{version}");
        my $cmd = "eval \"require $p\" and print $p" . '->VERSION;';
        $s->v("    cmd [perl $inc -le '$cmd'");
        my $v = qx(perl $inc -le '$cmd');
        chomp $v;
        $s->v("    got version [$v]");

        return 1 if $v eq $c->{version};
        return 0;
    }
    else {
        eval { system(qq{perl $inc -e 'require $p;' > /dev/null 2>&1}); };
        my $e = defined $? ? $? : 0;

        return 1 if not $e;
        return 0;
    }
    return 0;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Provider::Cpan - handle Perl modules

=cut

