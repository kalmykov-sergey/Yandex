#!/usr/bin/perl -w
use warnings;
use Test::More 'no_plan';
use Data::Dumper;

use lib '../../lib';

use_ok('Yandex::XML');

is(Yandex::XML::url_indexed('plarson.ru/tyndex.html'), 0, "unexisting page isn't indexed");
is(Yandex::XML::url_indexed('plarson.ru'), 1, "existing page is indexed");
is(Yandex::XML::url_indexed('http://plarson.ru'), 1, "correct proto usage");
is(Yandex::XML::url_indexed('www.plarson.ru'), 1, "correct www. processing");
