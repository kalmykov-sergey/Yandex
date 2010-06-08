#!/usr/bin/perl

use lib '../../lib';
use Test::More qw( no_plan );
use_ok('Yandex::Account');
use_ok('Yandex::XML');

my @ips = Yandex::Account->all_ips;
foreach(@ips){
  like($_, qr/\d+\./, "$_ looks like ip");
  is(Yandex::XML::url_indexed('plarson.ru/tyndex.html', $_), 0, "$_ works fine with yandex.xml");
}

isnt(Yandex::XML::search('url:plarson.ru', 0, '93.191.8.190'), 1, 'bad ip');
