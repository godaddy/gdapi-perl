package WWW::GoDaddy::REST::Util;

use strict;
use warnings;

use Sub::Exporter -setup => {
    exports => [
        qw( abs_url
            add_filters_to_url
            build_complex_query_url
            )
    ]
};
use URI;
use URI::QueryParam;

sub abs_url {
    my $api_base = shift;
    my $url      = shift;

    $url      =~ s|^/||;
    $api_base =~ s|/*$|/|;

    return URI->new_abs( $url, $api_base );
}

sub add_filters_to_url {
    my ( $url, $filters ) = @_;

    my $uri = URI->new($url);
    foreach my $field ( sort keys %{$filters} ) {
        my $field_filters = $filters->{$field};

        next unless $field_filters;

        if ( ref($field_filters) eq 'ARRAY' ) {

            # a query could look like so:
            # {
            #   'myField' => [
            #       { modifier => 'ne', value => 'apple' },
            #       { value => 'orange' } # implicit 'eq'
            #   ]
            # }
            foreach my $filter ( @{$field_filters} ) {
                my $modifier = $filter->{modifier} || 'eq';
                my $value = $filter->{value};
                if ( $modifier eq 'eq' ) {
                    $uri->query_param_append( $field => $value );
                }
                else {
                    $uri->query_param_append( sprintf( '%s_%s', $field, $modifier ) => $value );
                }
            }
        }
        else {

            # a query could look like so:
            # {
            #   'myField' => 'apple'
            # }
            $uri->query_param_append( $field => $field_filters );
        }
    }
    return $uri->as_string;
}

sub build_complex_query_url {
    my ( $url, $filter, $params ) = @_;

    $filter ||= {};
    $params ||= {};

    $url = add_filters_to_url( $url, $filter );

    if ( exists $params->{'sort'} ) {
        $params->{'order'} ||= 'asc';
    }

    my $uri = URI->new($url);
    while ( my ( $key, $value ) = each %{$params} ) {
        $uri->query_param( $key => $value );
    }

    return $uri->as_string;

}

1;

=head1 NAME

WWW::GoDaddy::REST::Util - Mostly URL tweaking utilities for this package

=head1 SYNOPSIS

  use WWW::GoDaddy::REST::Util qw/ abs_url add_filters_to_url /;

  # http://example.com/v1/asdf
  abs_url('http://example.com/v1','/asdf');

  # http://example.com?sort=asc&fname=Fred
  add_filters_to_url('http://example.com?sort=asc',{ 'fname' => [ { 'value': 'Fred' } ] });

=head1 DESCRIPTION

Utilities used commonly in this package.  Most have to do with URL manipulation.

=head1 FUNCTIONS

=over 4

=item abs_url

Given a base and path fragment, generate an absolute url with the two
joined.

Example:

  # http://example.com/v1/asdf
  abs_url('http://example.com/v1','/asdf');

=item add_filters_to_url

Given a url and a query filter, generate a url with the filter
query parameters added.

Filter syntax can be seen in the docs for L<WWW::GoDaddy::REST>.

Example:

  add_filters_to_url('http://example.com?sort=asc',{ 'fname' => [ { 'value': 'Fred' } ] });
  # http://example.com?sort=asc&fname=Fred

=item build_complex_query_url

Return a modified URL string given a URL, an optional filter spec, and optional
query parameter hash.

If you specify a sort, then an order parameter will be filled in if not present, and
and sort or order query parameters in the input string will be replaced.

All other query parameters (filters etc) will be appended to the query parameters
of the input URL instead of replacing.

Example:

    build_complex_query_url(
      'http://example.com',
      {
        'foo' => 'bar'
      },
      {
        'sort' => 'surname'
      }
    );
    # http://example.com?foo=bar&sort=surname&order=asc

=back

=head1 EXPORTS

None by default.

=head1 AUTHOR

David Bartle, C<< <davidb@mediatemple.net> >>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2014 Go Daddy Operating Company, LLC

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

=cut

