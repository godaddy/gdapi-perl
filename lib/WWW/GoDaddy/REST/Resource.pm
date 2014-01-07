package WWW::GoDaddy::REST::Resource;

use Carp;
use List::MoreUtils qw( any );
use Moose;
use WWW::GoDaddy::REST::Schema;
use WWW::GoDaddy::REST::Util qw( abs_url );
use Readonly;

Readonly my $DEFAULT_IMPL_CLASS => 'WWW::GoDaddy::REST::Resource';

has 'client' => (
    is       => 'rw',
    isa      => 'WWW::GoDaddy::REST',
    required => 1
);

has 'fields' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

has 'http_response' => (
    is       => 'ro',
    isa      => 'HTTP::Response',
    required => 0
);

sub save {
    my $self = shift;
    my $url  = $self->link('self');
    return $self->client->http_request_as_resource( 'PUT', $url, $self );
}

sub delete {
    my $self = shift;
    my $url  = $self->link('self');
    return $self->client->http_request_as_resource( 'DELETE', $url, $self );
}

sub follow_link {
    my $self      = shift;
    my $link_name = shift;

    my $link_url = $self->link($link_name);
    if ( !$link_url ) {
        my @valid_links = keys %{ $self->links() };
        croak("$link_name is not a valid link name. Did you mean one of these? @valid_links");
    }

    return $self->client->http_request_as_resource( 'GET', $link_url );
}

sub do_action {
    my $self   = shift;
    my $action = shift;
    my $params = shift;

    my $action_url = $self->action($action);
    if ( !$action_url ) {
        my @valid_actions = keys %{ $self->actions() };
        croak("$action is not a valid action name.  Did you mean one of these? @valid_actions");
    }

    return $self->client->http_request_as_resource( 'POST', $action_url, $params );

}

sub items {
    my $self = shift;
    return ($self);
}

sub id {
    return shift->f('id');
}

sub type {
    return shift->f('type');
}

sub type_fq {
    my $self       = shift;
    my $type       = $self->type;
    my $schema_url = $self->link('schemas');
    return abs_url( $schema_url, $type );
}

sub schema {
    my $self = shift;
    my $schema = WWW::GoDaddy::REST::Schema->registry_lookup( $self->type_fq, $self->type );
    return $schema;
}

sub link {
    my $self = shift;
    my $name = shift;

    my $links = $self->links();
    if ( exists $links->{$name} ) {
        return $links->{$name};
    }
    return undef;
}

sub links {
    return shift->f('links');
}

sub action {
    my $self = shift;
    my $name = shift;

    my $actions = $self->actions();
    if ( exists $actions->{$name} ) {
        return $actions->{$name};
    }
    return undef;
}

sub actions {
    return shift->f('actions');
}

sub f {
    return shift->field(@_);
}

sub field {
    my $self = shift;
    if ( @_ <= 1 ) {
        return $self->_get_field(@_);
    }
    else {
        return $self->_set_field(@_);
    }
}

sub _get_field {
    my $self = shift;
    my $name = shift;

    if ( !exists $self->fields->{$name} ) {
        return undef;
    }
    return $self->fields->{$name};

}

sub _set_field {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;
    $self->fields->{$name} = $value;
    return $self->fields->{$name};
}

sub new_subclassed {
    my $class  = shift;
    my $params = shift;

    my $type_short = $params->{fields}->{type} || '';
    my $type_long = $type_short ? $params->{client}->schemas_url($type_short) : '';

    my $impl = $class->find_implementation( ( $type_long, $type_short ) ) || $DEFAULT_IMPL_CLASS;
    eval "require $impl;";

    return $impl->new($params);

}

sub TO_JSON {
    my $self = shift;
    return $self->fields;
}

sub to_string {
    my $self = shift;
    my $pretty = shift;

    my $JSON = JSON->new;
    if( $pretty ) {
        $JSON->pretty(1);
    }
    return $JSON->convert_blessed->encode($self);
}

my %SCHEMA_TO_IMPL = (
    'collection' => 'WWW::GoDaddy::REST::Collection',
    'schema'     => 'WWW::GoDaddy::REST::Schema',
);

sub find_implementation {
    my $class    = shift;
    my @look_for = @_;

    foreach (@look_for) {
        if ( exists $SCHEMA_TO_IMPL{$_} ) {
            return $SCHEMA_TO_IMPL{$_};
        }
    }
    return;
}

1;

=head1 NAME

WWW::GoDaddy::REST::Resource - Represent a REST resource

=head1 SYNOPSIS

  $client = WWW::GoDaddy::REST->new(...);

  $resource = WWW::GoDaddy::REST::Resource->new({
    client => $client,
    fields => {
        'type'  => 'automobile',
        'id'    => '1001',
        'make'  => 'Tesla',
        'model' => 'S'
        'links' => {
            'self'    => 'https://example.com/v1/automobiles/1001',
            'schemas' => 'https://example.com/v1/schemas'
        },
        'actions' => {
            'charge' => 'https://example.com/v1/automobiles/1001?charge'
        }
        # ...
        # see: https://github.com/godaddy/gdapi/blob/master/specification.md
    },
  });

  $resource->f('id'); # get 1001
  $resource->f('id','2000'); # set to 2000 and return 2000

  # follow a link in links section
  $schemas_resource = $resource->follow_link('schemas');

  # perform an action in the actions section
  $result_resource  = $resource->do_action('charge',{ 'with' => 'quick_charger' });

=head1 DESCRIPTION

Base class used to represent a REST resource.

=head1 CLASS METHODS

=over 4

=item new

Given a hash reference of L<"ATTRIBUTES"> and values, return a new instance
of this object.

It is likely more important that you use the C<new_subclassed> class method.

Example:

  my $resource = WWW::GoDaddy::REST::Resource->new({
    client => WWW::GoDaddy::REST->new(...),
    fields => {
        id => '...',
        ...
    },
  });

=item new_subclassed

This takes the same paramegers as C<new> and is the preferred construction
method.  This tries to find the appropriate subclass of
C<WWW::GoDaddy::REST::Resource> and passes along the paramegers to the C<new>
method of that subclass instead.

See also: C<new>

=item find_implementation

Given a list of schema type names, find the best implementation sub class.

Returns the string of the class name. If no good subclass candidate is found,
returns undef.

Example:

  find_implementation( 'schema' );
  # WWW::GoDaddy::REST::Schema

=back

=head1 ATTRIBUTES

=over 4

=item client

Instance of L<WWW::GoDaddy::REST> associated with the resource.

=item fields

Hash reference containing the raw data for the underlying resource.

Several methods delegate to this underlying structure such as C<f>, 
and C<field>.

=item http_response

Optionally present instance of an L<HTTP::Response> object so that
you can inspect the HTTP information related to the resource.

=back

=head1 METHODS

=over 4

=item f

Get or set a field by name. You may also use the longer name C<field>.

When performing a set, it also returns the new value that was set.

Example:

  $res->f('field_name');       # get
  $res->f('field_name','new'); # set

=item field

Get or set a field by name.  You may also use the shorter name C<f>.

When performing a set, it also returns the new value that was set.

Example:

  $res->field('field_name');       # get
  $res->fieldf('field_name','new'); # set

=item save

Does a PUT at this resources URI.  Returns a new resource object.

Example:

  $r2 = $r1->save();

=item delete

Does a DELETE on this resource.  Returns a new resource object.  This
return value likely is only useful to get at the C<http_response> attribute.

=item do_action

Does a POST with the supplied data on the action URL with the given name.

If the action with the provided name does not exist, this method will
die.  See also: C<action> and C<actions>

Example:

  $r2 = $r1->do_action('some_action',{ a => 'a_v' });

=item follow_link

Gets the resource by following the link URL with the provided name.

If the link with the provided name does not exist, this method will
die.  See also: C<link> and C<link>

Example:

  $r2 = $r1->follow_link('some_link');

=item id

Return the id of this instance

=item type

Return the name of the schema type that this object belongs to.

=item type_fq

Return the full URI to the schema type that this object belongs to.

=item schema

Find and return the L<WWW::GoDaddy::REST::Schema> object that this is.

=item link

Return the link URL for the given name or undef if it does not exist.

Example:

  # https://example.com/v1/thing/...
  $r->link('self');
  # 'https://example.com/v1/me/1'

=item links

Return the hashref that contains the link => url information

Example:

  $r->links();
  # {
  #     'self'      => 'https://example.com/v1/me/1',
  #     'some_link' => 'https://example.com/v1/me/1/some_link'
  # }

=item action

Return the action URL for the given name.

Example:

  $r->action('custom_action');
  # https://example.com/v1/thing/1001?some_action

=item actions

Return the hashref that contains the action => url information

Example:

  $r->actions();
  # {
  #     'custom_action' => 'https://example.com/v1/thing/1001?some_action'
  # }

=item items

Returns a list of resources that this resource contains.  This implementation
simply returns a list of 'self'.  It is here to be consistent with the 
implementation found in L<WWW::GoDaddy::REST::Collection>.

Example:

  @items = $resource->items();

=item TO_JSON

Returns a hashref that represents this object.  This exists to make using the
L<JSON> module more convenient.  This does NOT return a JSON STRING, just a 
perl data structure.

=item to_string

Returns a JSON string that represents this object.  This takes an optional
parameter, "pretty".  If true, the json output will be prettified. This defaults
to false.

=back

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
