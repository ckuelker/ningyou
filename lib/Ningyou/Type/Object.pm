package Ningyou::Type::Object;

use Moose;

#     'owner' => 'c',
#     'source' => 'ningyou:///modules/home-bin/bin',
#     'require' => 'package:zsh',
#     'mode' => 'Fo-x',
#     'group' => 'c',
#     'recurse' => 'true',
#     'purge' => '1',
#     'class' => 'home-bin'


has 'object' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { return {}; },
    handles => {
        has_object    => 'exists',
        is_object     => 'defined',
        ids_object    => 'keys',
        get_object    => 'get',
        set_object    => 'set',
        num_object    => 'count',
        object_is_empty => 'is_empty',
        del_object    => 'delete',
        object_pairs  => 'kv',
    },
);

1;

