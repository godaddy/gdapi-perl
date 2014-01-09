#!perl

use Test::More;
use WWW::GoDaddy::REST::Util
    qw( abs_url add_filters_to_url build_complex_query_url is_json json_encode json_decode );

is( abs_url( 'http://example.com/v1/', '/schemas' ),
    'http://example.com/v1/schemas',
    'abs_url - ignore absolute request 1'
);

is( abs_url( 'http://example.com/v1', '/schemas' ),
    'http://example.com/v1/schemas',
    'abs_url - ignore absolute request 2'
);

is( abs_url( 'http://example.com/v1', '/../schemas' ),
    'http://example.com/schemas', 'abs_url - honor relative request 1' );

is( abs_url( 'http://example.com/v1', '../schemas' ),
    'http://example.com/schemas', 'abs_url - honor relative request 2' );

is( abs_url( 'http://example.com/v1', '../../../schemas' ),
    'http://example.com/../../schemas',
    'abs_url - honor relative request 3'
);

is( abs_url( 'http://example.com/v1', 'schemas' ),
    'http://example.com/v1/schemas',
    'abs_url - honor relative request 4'
);

is( abs_url( 'http://example.com/v1/', 'schemas' ),
    'http://example.com/v1/schemas',
    'abs_url - honor relative request 5'
);

is( add_filters_to_url( 'http://example.com', { 'food' => 'apple' } ),
    'http://example.com?food=apple',
    'simple equality'
);
is( add_filters_to_url( 'http://example.com', { 'food' => [ { 'value' => 'apple' } ] } ),
    'http://example.com?food=apple',
    'presume equality'
);
is( add_filters_to_url(
        'http://example.com', { 'food' => [ { modifier => 'eq', 'value' => 'apple' } ] }
    ),
    'http://example.com?food=apple',
    'equality squash in key name'
);
is( add_filters_to_url(
        'http://example.com', { 'food' => [ { modifier => 'ne', 'value' => 'apple' } ] }
    ),
    'http://example.com?food_ne=apple',
    'use modifier'
);

is( add_filters_to_url( 'http://example.com?sort=asc', { 'food' => 'apple' } ),
    'http://example.com?sort=asc&food=apple',
    'do not kill existing query params'
);

is( add_filters_to_url(
        'http://example.com',
        {   'food' => [
                { modifier => 'startswith', 'value' => 'apple' },
                { modifier => 'ne',         'value' => 'apple pie' }
            ]
        }
    ),
    'http://example.com?food_startswith=apple&food_ne=apple+pie',
    'more than one filter is parsed correctly'
);

is( add_filters_to_url( 'http://example.com', { 'food' => undef } ),
    'http://example.com', 'skip empty params' );

is( add_filters_to_url( 'http://example.com', { 'foo' => 'd', 'bar' => 'none' } ),
    'http://example.com?bar=none&foo=d',
    'more than one field is processed'
);

# build_complex_query_url

my $EMPTY_FILTER = {};

is( build_complex_query_url( 'http://example.com', $EMPTY_FILTER, { 'sort' => 'foo' } ),
    'http://example.com?sort=foo&order=asc',
    'order defaults to "asc"'
);

is( build_complex_query_url(
        'http://example.com', $EMPTY_FILTER, { 'sort' => 'foo', 'order' => 'asc' }
    ),
    'http://example.com?sort=foo&order=asc',
    'column and order 1'
);

is( build_complex_query_url(
        'http://example.com', $EMPTY_FILTER, { 'sort' => 'foo', 'order' => 'desc' }
    ),
    'http://example.com?sort=foo&order=desc',
    'column and order 2'
);

is( build_complex_query_url('http://example.com'), 'http://example.com', 'no sort 1' );
is( build_complex_query_url( 'http://example.com', $EMPTY_FILTER ),
    'http://example.com', 'no sort 2' );
is( build_complex_query_url( 'http://example.com', $EMPTY_FILTER, {} ),
    'http://example.com', 'no sort 3' );

is( build_complex_query_url(
        'http://example.com?search=test&sort=bar', $EMPTY_FILTER,
        { 'sort' => 'foo', 'order' => 'asc' }
    ),
    'http://example.com?search=test&sort=foo&order=asc',
    'squash search params if they exist'
);

my @json_tests = (
    {   json    => '"3"',
        perl    => '3',
        is_json => 1
    },
    {   json    => '3',
        perl    => 3,
        is_json => 1,
    },
    {   json    => 'asf asfd',
        perl    => undef,
        is_json => 0,
    },
    {   json    => '{"k":"v"}',
        perl    => { 'k' => 'v' },
        is_json => 1
    }
);

foreach (@json_tests) {
    my $json           = $_->{json};
    my $perl           = $_->{perl};
    my $is_json        = is_json($json);
    my $expect_is_json = $_->{is_json};

    is( $is_json, $expect_is_json, "is_json is as expected [$is_json '$json']" );
    if ($is_json) {
        is_deeply( json_decode($json), $perl, "json decodes to perl ['$json']" );
        is_deeply( json_encode($perl), $json, "perl encodes to json ['$json']" );
    }
}

done_testing();
