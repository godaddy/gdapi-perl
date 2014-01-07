#!perl

use Test::More;
use WWW::GoDaddy::REST::Util qw( abs_url add_filters_to_url build_complex_query_url );

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

done_testing();
