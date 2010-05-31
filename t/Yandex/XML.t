#!/usr/bin/perl -w
use warnings;
use Test::More 'no_plan';
use Data::Dumper;

use lib '../../lib';

use_ok('Yandex::XML');

ok(Yandex::XML::url_indexed('plarson.ru/tyndex.html'));