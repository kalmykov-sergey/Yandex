#!/usr/bin/perl
# reg.cgi - just interface for register yandex bots

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use lib '/home/sergey/projects/Yandex/lib';
use Yandex::Account::Registration;
use Yandex::Account;

  my $msg;
  if(my $filename1 = param('store')){
    my $code = param('code');
    my $reg1 = Yandex::Account::Registration->new({}, $filename1);
    if (my $ok = $reg1->send_captcha($code)){
      $msg = "Success!";
      my $acc = Yandex::Account->new($reg1->{login}, $reg1->{password});
      print redirect '/cgi-bin/reg.cgi';
    }
  }

  my $reg = Yandex::Account::Registration->new();
  my $src = $reg->get_captcha();
  my $filename = $reg->{store};

  print header(-type => 'text/html', -charset => 'cp1251'),
    h1("Lets register ".$reg->{iname}. " ". $reg->{fname}. 
      " as a ". $reg->{login}),
    h3($msg),
    start_form, 
    img({src => $src}), 
    textfield('code'), 
    hidden('store', $filename),
    submit, 
    end_form;
