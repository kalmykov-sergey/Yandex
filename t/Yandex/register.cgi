#!"C:\xampp\perl\bin\perl.exe"

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use YandexRegister;

if(my $captcha = param('captcha')){
  my $form = YandexRegister::restore_form(param('form'));
  $form = YandexRegister::fullfill($form, $captcha);

  YandexRegister::send_form($form);
}

my ($form, $src) = (undef, undef);
my ($iname, $fname);
#eval{
  warn "fetching person\n";
  ($iname, $fname) = YandexRegister::fetch_person;
  warn "1st regisration step\n";
  ($form, $src) = YandexRegister::form2($iname, $fname);
  if(!$src){
    YandexRegister::delete_person($iname, $fname);
    print redirect('/cgi-bin/register.pl');
  }
#};


my $serialized_form = YandexRegister::store_form($form);

print header(-type => 'text/html', -charset => 'cp1251'),
  h1("Lets register $iname $fname"),
  start_form, 
  img({src => $src}), 
  textfield('captcha'), 
  hidden('form', $serialized_form),
  submit, 
  end_form;