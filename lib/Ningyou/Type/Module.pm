package Ningyou::Type::Module;

use Moose;

#     'owner' => 'c',
#     'source' => 'ningyou:///modules/home-bin/bin',
#     'require' => 'package:zsh',
#     'mode' => 'Fo-x',
#     'group' => 'c',
#     'recurse' => 'true',
#     'purge' => '1',
#     'class' => 'home-bin'


has 'module' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { return {}; },
    handles => {
        has_module    => 'exists',
        is_module     => 'defined',
        ids_module    => 'keys',
        get_module    => 'get',
        set_module    => 'set',
        num_module    => 'count',
        module_is_empty => 'is_empty',
        del_module    => 'delete',
        module_pairs  => 'kv',
    },
);

1;

