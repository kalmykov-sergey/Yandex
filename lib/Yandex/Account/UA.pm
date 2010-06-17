package Yandex::Account::UA;

use strict;
use warnings;

use LWP;
use HTML::Form;
use Encode;

sub new {
  my ($class, $login, $password) = @_;
  my $ua = LWP::UserAgent->new(
    agent => 'Mozilla 5.0 (MSIE 9.0)',
    cookie_jar => {},
    requests_redirectable => ['GET', 'POST'],
  );
  my $self = {
    ua => $ua,
    login => $login,
    password => $password,
  };
  bless $self, $class; 
}

sub authenticate {
  my $self = shift;

  my $resp = $self->{ua}->get('http://passport.yandex.ru/passport?mode=loginform');
  my $form = HTML::Form->parse($resp);
  $form->value(login => $self->{login});
  $form->value(passwd => $self->{password});

  $resp = $self->{ua}->request($form->click);
  unless(encode('cp1251', decode('utf-8', $resp->content)) =~ /персональные данные/){
    open my $w, '>auth.html';
    print $w $resp->content;
    close $w;
    die "auth failed (see auth.html)";
  }
}
=pod
sub delete {
  my $self = shift;
  $self->{ua}->get('http://passport.yandex.ru/passport?mode=delete');
  unless( $resp->content =~ /Сменить IP-адрес/){
    open my $w, '>reg1.html';
    print $w $resp->content;
    close $w;
    die "register failed (see reg1.html)";
  }

}
=cut

sub register_ip {
  my $self = shift;
  my $ip = shift or die "usage: \$ua->register_ip('192.168.1.2')";
  my $resp = $self->{ua}->get(
    'http://xml.yandex.ru/ip.xml',
    Accept => 'text/html, application/xml',
  );
  die $resp->status_line unless $resp->is_success;
  unless( $resp->content =~ /Сменить IP-адрес/){
    open my $w, '>reg1.html';
    print $w $resp->content;
    close $w;
    die "register failed (see reg1.html)";
  }


  my $form = HTML::Form->parse($resp);
  $form->value(ip => $ip);
  my $req = $form->click;
  $req->header(Accept => 'text/html, application/xml');
  $resp = $self->{ua}->request($req);
  die $resp->status_line unless $resp->is_success;
  unless($resp->content =~ /Изменения сохранены/){
    open my $w, '>reg.html';
    print $w $resp->content;
    close $w;
    die "register failed (see reg.html)";
  }
}

1;
