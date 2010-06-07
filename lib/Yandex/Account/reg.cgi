#!"C:\xampp\perl\bin\perl.exe"

use CGI qw(:standard);
use lib 'C:/xampp/perl/projects/Yandex/lib';
use Yandex::Account::Registration;

if(my $filename = param('store')){
  my $code = param('code');
  my $reg = Yandex::Account::Registration->new({}, $filename);
  if (my $ok = $reg->send_captcha($code)){
    $msg = "Success!";
  }
}

$reg = Yandex::Account::Registration->new();
$url = $reg->get_captcha();
$filename = $reg->{store};

print header,

