package Vmsgs::TextInterface::PostNew;

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

  $self;
} # end new


sub Run {
my($self) = @_;
  my($subject,$msg,$len);

  $self->Debug("Posting a new msg");

  $self->msgsinterface->SetArg0Status("posting");

  print "\nSubject: ";
  chomp($subject = <STDIN>);

  $msg = new Vmsgs::Msg;
  $self->_BuildHeaders($msg,$subject);

  $msg->AppendSig();

  $self->_EditPostMsg($msg,$self->{'editor'});

  ("quit",undef);
} # end Run

1;
