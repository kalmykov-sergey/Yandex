package Yandex::XML;

#use lib '/home/sergey/lib';
use strict;
use warnings;

use URI;
use Encode qw( from_to encode decode );
use LWP;
use XML::XPath;
use Yandex::Account;

use Data::Dumper;
our $last_ip;


sub last_ip {
  return $last_ip;
}

sub xmlescape {
  my($data, $level) = @_;

  return '' unless(defined($data));

  $data =~ s/&/&amp;/sg;
  $data =~ s/</&lt;/sg;
  $data =~ s/>/&gt;/sg;
  $data =~ s/\"/&quot;/sg;

  return $data;
} # ������ escape-�������� ��� xml-����������


sub yandex_xml_request {
  my ($query, $opts) = @_;
  my $query_esc = xmlescape( $query );

  my $page = $opts->{page} || 0;

  my $doc = <<EOF;
<?xml version='1.0' encoding='windows-1251'?>
<request>
  <query>${query_esc}</query>
  <page>$page</page>
  <maxpassages>0</maxpassages>
  <groupings>
    <groupby attr='d' mode='deep' groups-on-page='20' docs-in-group='1' curcateg='-1'/>
  </groupings>
</request>
EOF

  my $request = HTTP::Request->new( 
    POST => 'http://xmlsearch.yandex.ru/cgi-bin/xmlsearch.pl'
  );
  $request->content_type('application/xml');
  $request->content($doc);

  return $request;
} # ��������� xml-������ � �������


sub search {
  my ($query, $page, $ip) = @_;

  unless ($ip){
    my $random_account = Yandex::Account->new_random();
    $ip = $random_account->ip;
  }
  $last_ip = $ip;
  
  my $ua = LWP::UserAgent->new;
  {
    no warnings;
    @LWP::Protocol::http::EXTRA_SOCK_OPTS = ( 
      PeerAddr => '77.88.21.13',
      LocalAddr => $ip,
    );
  }

  my $req = yandex_xml_request($query, {page => $page});
  my $response = $ua->request($req);
  
  @LWP::Protocol::http::EXTRA_SOCK_OPTS = (); # clear peer addr
  
  die "������ xml �������: ". ($response->status_line) ."\n" 
    unless $response->is_success;
  my $xml = $response->content;
#  die "������ ���������" unless from_to($xml, 'utf-8', 'windows1251');
#  $xml =~ s#encoding="utf-8"#encoding="windows-1251"#;
  return $xml;
} # xml-����� �� ������ ����� xml-���������


sub geo_code {
  my $region = shift;

  local $/;
  open my $r, '<geo.c2n' or die;
  my $geo_file = <$r>;
  close $r;

  my %regions = split(/\n|\t/,$geo_file);
  my %codes = reverse %regions;

  return $codes{$region} || 1;
} # ��� ������� ��� ������������� ������ � �������


sub position {
  my ($site, $query, $region, $ref) = @_;
  my $page = 0;
  my ($Pos, $match) = (0, undef);
  while($page < 3 && $Pos == 0){
    ($Pos, $match, $ref) = _position($site, $query, $page++, $region, $ref);
  }
  return ($Pos, $match, $ref);
}


sub _position {
  my ($site, $query, $page, $region, $ref) = @_;

  $page ||= 0;
  if($region){
    $query = $query.' << cat=('.(11000000+geo_code($region)).')';
  }

  my $xml_doc = search($query, $page);
  my $xml = XML::XPath->new( xml => $xml_doc );

  my $error = $xml -> findvalue ('/yandexsearch/response/error');
  die $error if ($error);
  
  my @nodes = $xml->findnodes('/yandexsearch/response/results/grouping/group/doc');
  my %nodes = map{$_->findnodes('url')->[0]->string_value => $_->findnodes('properties/_PassagesType')->[0]->string_value} @nodes;
  my @sites = map{URI->new($_)->host} map{$_->findnodes('url')->[0]->string_value} @nodes;
  my @matches = map{$_->findnodes('properties/_PassagesType')->[0]->string_value} @nodes;
  my $match = 0;
  my $position = 0;
  my $i = $page*20;
  foreach(0..$#sites){
    $i++;
    #if($debug){print lc $sites[$_], " =? ", lc $site, "\n";}
    if (index(lc $sites[$_], lc $site) > -1 and not $position){
      $position = $i;
      $match = $matches[$_];
    }
    $ref->{$i} = $sites[$_];
  }
  return ($position, $match, $ref);
}

sub url_indexed {
  my $url = shift;
  my $ip = shift;
  $url =~ s#http://##i;
  $url =~ s#www\.##i;
  my $query = "url:$url || url:www.$url";
  my $xml_doc = search($query, 0, $ip);
  my $utf8_xml = $xml_doc;
  from_to($xml_doc, 'utf-8', 'cp1251');
  return 0 if $xml_doc =~ /<error code="15">������� ���������� ���� ����� �� �����������</;
  my $xml = XML::XPath->new(xml => $utf8_xml);
  my $error = $xml->findvalue('/yandexsearch/response/error');
  die $error if $error;
  return 1;
} # �������� �������������������� ���� �������� (� ������� ��������� ����� �������� url: )


1;
