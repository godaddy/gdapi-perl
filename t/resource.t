#!perl

use strict;
use warnings;

use Carp qw/cluck/;

use File::Slurp qw(slurp);
use FindBin;
use Test::More;
use Test::Exception;
use WWW::GoDaddy::REST;
use WWW::GoDaddy::REST::Resource;
use WWW::GoDaddy::REST::Util qw(json_decode);

my $URL_BASE    = 'http://example.com/v1';
my $SCHEMA_FILE = "$FindBin::Bin/schema.json";
my $SCHEMA_JSON = slurp($SCHEMA_FILE);

my $schema_struct = json_decode($SCHEMA_JSON);

my $c = WWW::GoDaddy::REST->new( { url => $URL_BASE, schemas_file => $SCHEMA_FILE } );

subtest 'constructor' => sub {
    lives_ok { WWW::GoDaddy::REST::Resource->new( { client => $c, fields => {} } ) }
    'required params';
    dies_ok { WWW::GoDaddy::REST::Resource->new( { fields => {} } ) } 'client is required';
    dies_ok { WWW::GoDaddy::REST::Resource->new( { client => $c, fields => undef } ) }
    'fields is required';
    dies_ok { WWW::GoDaddy::REST::Resource->new( { client => $c } ) } 'fields is required';
    dies_ok { WWW::GoDaddy::REST::Resource->new( { client => $c, fields => [] } ) }
    'fields must be hashref';
};

subtest 'fields' => sub {
    my $r = WWW::GoDaddy::REST::Resource->new( { fields => $schema_struct, client => $c } );
    subtest 'get' => sub {
        subtest 'basic' => sub {
            is( $r->f('type'),     'collection', 'getting a field works' );
            is( $r->field('type'), 'collection', 'getting a field works' );
        };
        subtest 'converting to Resource objects' => sub {
            my $data_plain = $r->f('data');
            my $data_res   = $r->f_as_resources('data');
            isnt( $data_plain->[0], 'WWW::GoDaddy::REST::Resource', 'get - no transformation' );
            isa_ok( $data_res->[0], 'WWW::GoDaddy::REST::Resource', 'get - with transformation' );

            my $not_a_res = $r->f_as_resources('type');
            is( $not_a_res, 'collection', 'get - with transformation, but not transformed' );
        };
    };
    subtest 'set' => sub {
        my $orig = $r->f('type');
        is( $r->f( 'type', 'asdf' ), 'asdf', 'setting a field returns new value' );
        is( $r->f('type'), 'asdf', 'field was indeed set' );
        is( $r->field( 'type', 'asdf2' ), 'asdf2', 'setting a field returns new value' );
        is( $r->field('type'), 'asdf2', 'field was indeed set' );
        $r->f( 'type', $orig );
    };
};

done_testing();
