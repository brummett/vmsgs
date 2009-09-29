package Vmsgs::TextInterface::PostParent;

use Vmsgs::Msg;

# functions used by both PostNew and Followup

sub _BuildHeaders {
my($self,$msg,$subject) = @_;

  $msg->header("Subject:", $subject);
  $msg->header("Author", $self->msgsinterface->me);
  $msg->header("Email", $self->msgsinterface->email);
  $msg->header("Date:", scalar(localtime()));
  $msg->header("X-msgs-client:", "vmsgs " . $main::VERSION);
  $msg->header("X-posting-host:", $ENV{'HOST'}) if ($self->msgsinterface->server);
  $msg->body("");
} # end _BuildHeaders

sub _EditPostMsg {
my($self,$msg,$editor) = @_;
  my($len,$filename,$cmd);

  $len = scalar($msg->header()) + $msg->header("Content-length:") + 8;

  $filename = $ENV{'HOME'} . "/.newmsgs.$$";
  $self->Debug("temp filename is $filename");

  $msg->SaveToFile($filename);

  $cmd = "$editor +$len $filename";
  $self->Debug("Exececuting command $cmd");

  system($cmd);

  $self->Debug("Back from editor");

  print "(S)end (F)orget or (D)ump to /dev/null? ";
  chomp($char = <STDIN>);

  if ($char =~ m/^s/i) {
    $msg = new Vmsgs::Msg();
    $msg->LoadFromFile($filename);
    $self->msgsinterface->Send($msg);
  }
  unlink($filename);

  $self->Debug("Leaving _EditPostMsg");
} # end _EditPostMsg

1;
  
