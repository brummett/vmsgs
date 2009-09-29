package Vmsgs::TextInterface::Followup;

use Vmsgs::WidgetBase;
use Vmsgs::TextInterface::PostParent;  # For _EditPostMsg and _BuildHeaders
use Vmsgs::Debug;
use Vmsgs::Msg;

use strict;

our @ISA = qw ( Vmsgs::WidgetBase Vmsgs::Debug Vmsgs::TextInterface::PostParent);

sub new {
my($class,%args) = @_;
  my($self);

  $self = {};
  bless $self,$class;

  $self->msgsinterface($args{'msgsinterface'});
  $self->{'editor'} = $args{'editor'};
  $self->{'msgid'} = $args{'msgid'};

  $self;
} # end new


sub Run {
my($self) = @_;
  my($subject,$msg,$newmsg,$msgid,@body);

  $msgid = $self->{'msgid'};

  $self->msgsinterface->SetArg0Status("replying to $msgid");

  $self->Debug("Posting a followup to msg $msgid");

  # Munge up the subject header for all the Re: stuff
  $msg = $self->msgsinterface->Get($msgid);
  $subject = $msg->header("Subject:");
  if ($subject =~ m/^Re\:(.*)/) {
    $subject="Re[2]:$1";
  } elsif ($subject =~ m/^Re\[(\d+)\]\:(.*)/) {
    $subject="Re[". ($1 + 1) ."]:$2";
  } else {
    $subject = "Re: $subject";
  }

  $newmsg = new Vmsgs::Msg();
  $self->_BuildHeaders($newmsg,$subject);
  $newmsg->header("Followup-to:", $msgid);
  
  push(@body,$msg->header("Author") . " said:");
  foreach ( $msg->body() ) {
    push(@body, "\> $_");
  }
  push(@body,"");  # make a blank line at the bottom
  $newmsg->body(\@body);
  $newmsg->AppendSig();

  $self->_EditPostMsg($newmsg,$self->{'editor'});

  ("quit",undef);
} # end Run

1;
