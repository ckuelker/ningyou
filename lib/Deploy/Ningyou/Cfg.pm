# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Cfg                                                      |
# |                                                                           |
# | Configuration space                                                       |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-18 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Cfg;

# ABSTRACT: Configuration space

use Cwd qw(abs_path);
use Config::Tiny;
use Data::Dumper;
use Moose::Role;
use namespace::autoclean;

has 'ini_filename' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_ini_filename',
    writer  => 'set_ini_filename',
    default => sub { my $r = "$ENV{HOME}/.ningyou.ini"; return $r; }
);

# Read a INI configuration
# - Config::INI::Reader
# - Exmaple: Host based configuration: HOST.DOMAIN.TLD.ini
# REMARK: this configuration will not be processed by template toolkit
#         to load those: Deploy::Ningyou::Util::read_template_ini({fn=>$fn})
#         for nomal:     Deploy::Ningyou::Util::read_ini({fn=>$fn})
has 'ini' => (
    isa     => 'Config::Tiny',
    is      => 'rw',
    reader  => 'get_ini',
    writer  => 'set_ini',
    lazy    => 1,
    default => sub {
        my ($s) = @_;
        my $cfn = $s->get_ini_filename;
        $s->e( "No configuration [$cfn]", 'bootstrap' ) if not -f $cfn;
        my $ini = ( -f $cfn ) ? $s->read_ini( { fn => $cfn } ) : $s->new_ini;
        my $fqhn = $s->get_fqhn( { ini => $ini } )
            ;    # fully qualified host name: HOST.FQDN
        my $hfn = "$ini->{global}->{worktree}/$fqhn.ini";
        $s->e( "No configuration [$hfn]", 'bootstrap' ) if not -f $hfn;

        # inject host configuration under key 'host'
        $ini->{host}
            = ( -f $hfn ) ? $s->read_ini( { fn => $hfn } ) : $s->new_ini;

        # Class blessings are OMITTED (*):
        # 'ini' => {   (*)
        #     'version' => {
        #         'file'          => '0.1.0',
        #         'project'       => '0.1.0',
        #         'configuration' => '0.1.0'
        #     },
        #     'host' => { (*)
        #         'version'    => {
        #             'project'       => '0.1.0',
        #             'configuration' => '0.1.0',
        #             'file'          => '0.1.0'
        #         },
        #         'global'    => { 'default' => '1' },
        #         'debian-gnu-linux-9.8-stretch-amd64-x86_64' => {
        #             'default' => '1'
        #         }
        #         'w1.c8i.org' => { 'default' => '1' },
        #     },
        #     'global' => { 'worktree' => '/tmp/ningyou' }
        # },
        return $ini;
    }
);
has 'worktree' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_worktree',
    writer  => 'set_worktree',
    lazy    => 1,
    default => sub {
        my ($s) = @_;
        my $ini = $s->get_ini;
        my $wt
            = exists $ini->{global}->{worktree}
            ? $ini->{global}->{worktree}
            : $s->e( "no worktree", 'cfg' );

        $s->e( "worktree [$wt] not found", 'worktree' ) if not -d $wt;
        return abs_path($wt);    # abs_path to resolve symlink
    }
);

with qw(Deploy::Ningyou::Util);

requires(qw(get_fqhn read_ini new_ini));

our $version = '0.1.0';

no Moose::Role;

1;
__END__
