use strict;
use warnings;
use diagnostics;
use Test::More;
use Test::Moose;    # meta_ok,does_ok,as_attribute_ok

{

    package Test::Class;
    use Moose;
    use version 0.77; our $VERSION = version->declare('v1.2.3');
    with qw(Deploy::Ningyou::Util);
    sub overwrite { return 1; }
    1;
}

my $expect_class = 'Test::Class';
my $expect_role  = 'Deploy::Ningyou::Util';
does_ok( $expect_class, $expect_role,
    "Test::Class does Deploy::Ningyou::Util role" );
my $class = Test::Class->meta;
isa_ok( $class, 'Moose::Meta::Class' );
isa_ok( $class, 'Class::MOP::Module' );

is( $class->name, 'Test::Class', '... got the right name of Test::Class' );
is( $class->version, 'v1.2.3', '... got the right version of Test::Class' );

is( $class->get_method('overwrite')->body,
    \&Test::Class::overwrite, '... Test::Class got the overwrite method' );
ok( $class->has_method('overwrite'),
    '... Test::Class has the overwrite method' );
my $tc = Test::Class->new;

# === [ METHODS ] =============================================================
my $methods = [
    qw(
        _set_debug
        _set_debug_filename
        apply_template
        c
        d
        e
        env_modules
        exists_color
        get_action_list
        get_class
        get_configuration_version
        get_date
        get_debug
        get_debug_filename
        get_distribution
        get_env_action
        get_env_bootstrap_repository
        get_env_options
        get_facter_fqhn
        get_fqhn
        get_homedir
        get_ini
        get_ini_filename
        get_last_change_of_file
        get_line
        get_line_nl
        get_pm_cache_ttl
        get_project_version
        get_providers
        get_verbose
        get_worktree
        init_facter_fqhn
        meta
        module_to_ini
        new_ini
        overwrite
        p
        parse_section
        process_env_actions
        process_env_options
        read_ini
        read_template_ini
        section_to_full_section
        set_action_list
        set_env_action
        set_env_bootstrap_repository
        set_env_options
        set_facter_fqhn
        set_ini
        set_ini_filename
        set_worktree
        validate_parameter
        w
        )
];

is_deeply( [ sort $class->get_method_list() ],
    $methods, '... got Deploy::Ningyou::Util method list' );

# --- [ sub p ] ---------------------------------------------------------------
isa_ok( $class->get_method('p'), 'Moose::Meta::Role::Method' );
is( $class->get_method('p')->body,
    \&Test::Class::p, '... Deploy::Ningyou::Util got the [p] method' );
ok( $class->has_method('p'), '... Deploy::Ningyou::Util has the [p] method' );
my $exp_p0 = "hello world\n";
my $got_p0 = $tc->p($exp_p0);
is( $got_p0, $exp_p0, "... Deploy::Ningyou::Util::p [$exp_p0]" );
my $exp_p1 = q{};
my $got_p1 = $tc->p();
is( $got_p1, $exp_p1, "... Deploy::Ningyou::Util::p [$exp_p1]" );

# --- [ sub get_project_version ] ---------------------------------------------
my $s = 'get_project_version';
isa_ok( $class->get_method($s), 'Moose::Meta::Role::Method' );
is(
    $class->get_method($s)->body,
    \&Test::Class::get_project_version,
    "... Deploy::Ningyou::Util got the [$s] method"
);
ok( $class->has_method($s), "... Deploy::Ningyou::Util has the [$s] method" );
my $exp_p2 = "0.1.4";
my $got_p2 = $tc->get_project_version($exp_p2);
is( $got_p2, $exp_p2, "... Deploy::Ningyou::Util::$s [$exp_p2]" );

# === [ DONE ] ================================================================
done_testing()
