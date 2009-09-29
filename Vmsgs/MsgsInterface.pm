package Vmsgs::MsgsInterface;

# An object oriented interface to the msgs database though msgs.pl, Cache.pm
# and Msg.pm
#
# History
# V1.1   Added pass-through functions for Arg0Client, Arg0Tagline Arg0Status
#        5.15.02
# V1.0   Original release.  An OOP wrapper around msgs.pl

use Vmsgs::Cache;
use Vmsgs::Msg;
use Vmsgs::Debug;
 
#use strict;

our @ISA = qw ( Vmsgs::Debug );
our $VERSION = "1.1";
our $DEBUG =  1;
#our($LOCAL,$SERVER,$MSGSRC);  # globals used by msgs.pl

require "msgs.pl";

# Creates a new managed connection to the msgs database;  host is undef if reading locally
# cachesize if the cache size to use - 50 if not spefified
sub new {
my($class,%args) = @_;
  my($self,@bounds,$user,$host,$port);

  $self = {};
  bless $self,$class;

#  $self->start_debug(".vmsgs.msgsinterface") if ($DEBUG);

  $self->Debug("Creating new MsgsInterface object $self");

  if ($args{'host'}) {
    if ($args{'host'} =~ m/(.*):(\d+)/) {
      $args{'host'} = $1;
      $port = $2;
    }
    $self->Debug("Using remote msgs reading host $1 port $port");
    $LOCAL = 0;
    $SERVER = $self->{'server'} = $args{'host'} || $SERVER;
    $PORT = $port if ($port);
  } else {
    $self->Debug("Using local msgs reading");
    $LOCAL = 1;
  }
  
  $self->Debug("Calling &InitializeMsgsAPI");
  &InitializeMsgsAPI();
  $self->Debug("MSGSRC is $MSGSRC BOUNDS is $BOUNDS");
    
  @bounds = &GetBounds;
  $self->firstmsg($bounds[0]);
  $self->lastmsg($bounds[1]);

  if (!$LOCAL or -f $MSGSRC) {  # If there's a msgsrc file
    $self->currmsg(&ReadRC());
  } else {
    $self->{'currmsg'} = $self->{'lastmsg'} - 100;  # No rc file, set current to last - 100
  }

  $self->{'initial_currmsg'} = $self->currmsg();  # simple hueristic for determining isread()
  $self->maxread($self->currmsg() - 1);
  $self->Debug(sprintf("firstmsg %d lastmsg %d currmsg %d maxread %d\n",
         $self->firstmsg(),
         $self->lastmsg(),
         $self->currmsg(),
         $self->maxread()));

  chomp($user=`whoami`);
  $self->{'me'} = $LOCAL ? $user || $ENV{'USER'} || $ENV{'LOGNAME'} :  &GetLogname();
  chomp($host=`hostname`);
  $self->{'email'} = $ENV{'EMAIL'} || "$user\@$host";


  $self->{'cache'} = new Vmsgs::Cache($self,$args{'cachesize'} || 50,"_read_msg","_write_msg");
  $self->Debug(sprintf("Cache object is %s",$self->{'cache'}));

  $self;
} # end new


sub SetArg0Client {
my($self,$string) = @_;
  &Arg0Client($string);
}

sub SetArg0Tagline {
my($self,$string) = @_;
  &Arg0Tagline($string);
}

sub SetArg0Status {
my($self,$string) = @_;
  $self->Debug("Setting arg0 status to $string");
  &Arg0Status($string);
}


sub local {
my($self) = @_;

  defined($self->{'server'}) ? 0 : 1;
} 


# Returns the two values in the .bounds file
sub bounds {
my($self) = @_;

  &GetBounds();
}

sub server {
my($self) = @_;

  $self->{'server'};
}


# Retrieve the Msg object for a given msg ID
sub Get {
my($self,$id) = @_;

  $self->Debug("In Get for id $id");
  $self->{'cache'}->get($id);
}

# Post a message
sub Send {
my($self,$ref) = @_;
  my($string);

  if (!ref($ref)) {  # Assumme it's a plain string
    &Post($ref);
  } elsif ($ref->isa('Vmsgs::Msg')) {  # Passed in a Msg object
    &Post($ref->Textify());
  } elsif (ref($ref) eq 'SCALAR') {  # Passed in a ref to a string
    &Post($$ref);
  } elsif (ref($ref) eq 'ARRAY') { # Passed in a ref to a list
    &Post(map {m/\n$/ ? $_ : $_ . "\n"} @$ref);  # Make sure each line ends in \n
  } else {
    warn "Unknown ref type ",ref($ref)," passed to Send";
    undef;
  }
}


# Get or set the firstmsg attribute
sub firstmsg {
my($self,$val) = @_;

  if (defined($val)) {
    $self->{'firstmsg'} = $val;
  } else {
    $self->{'firstmsg'};
  }
}

# Get or set the lastmsg attribute
sub lastmsg { 
my($self,$val) = @_;
  
  if (defined($val)) {
    $self->{'lastmsg'} = $val;
  } else {
    $self->{'lastmsg'};
  }
}


# Get or set the currmsg attribute
sub currmsg { 
my($self,$val) = @_;
  
  if (defined($val)) {
    if ($val =~ m/^[+-]\d+/) {  # val is expressed as +10 or -50 as an offset to the current currmsg
      $self->{'currmsg'} += $val;
    } else {
      $self->{'currmsg'} = $val;  # val is just a msg ID 
    }
  } else {
    $self->{'currmsg'};
  }
}


# Get or set the maxread attribute
sub maxread { 
my($self,$val) = @_;
  
  if (defined($val)) {
    $self->{'maxread'} = $val;
  } else {
    $self->{'maxread'};
  }
}

# Mark a single msg as read
sub setread {
my($self,$msgid) = @_;

  if ($msgid > $self->maxread()) {
    $self->maxread($msgid);
  }

  $self->{'read'}->{$msgid} = 1;
}

# Is a msg marked as read?
sub isread {
my($self,$msgid) = @_;

  if (defined($self->{'read'}->{$msgid})) {  # Has the read bit been set before
    $self->{'read'}->{$msgid};
  } elsif ($msgid < $self->{'initial_currmsg'}) {  # otherwise, is this msgid
    1;                           # less than the starting msgid in .msgsrc
  } else {
    0;
  }
}

# Get a list of the read msgIDs
sub readlist {
my($self) = @_;
  keys(%{$self->{'read'}});
}

# Mark a msgID as unread
sub unread {
my($self,$msgid) = @_;
  delete($self->{'read'}->{$msgid});
}


# set a msgID as marked
sub mark {
my($self,$id) = @_;
  $self->{'marks'}->{$id} = 1;
}

# Clear a mark on a msgID
sub unmark {
my($self,$id) = @_;
  delete($self->{'marks'}->{$id});
}

# Returns true if a msgID is marked
sub marked {
my($self,$id) = @_;
  $self->{'marks'}->{$id};
}

# Returns a list of all the marked msgIDs
sub marks {
my($self) = @_;
  keys(%{$self->{'marks'}});
}


# Delete all the current marks
sub unmark_all {
my($self) = @_;
  $self->{'marks'} = undef;
}


# Get or set the current mode.  Used kind of as a catch-all place to store a string
sub mode {
my($self,$val) = @_;
 
  if (defined($val)) {
    $self->{'mode'} = $val;
  } else {
    $self->{'mode'};
  }
}


# Returns your login name
sub me {
my($self) = @_;

  $self->{'me'};
}

# Returns your email address
sub email {
my($self) = @_;

  $self->{'email'};
}


# Currently, we just save the maximum read msg id to the RC file
sub DESTROY {
my($self) = @_;
  $self->Debug("In DESTROY");

  if (! $self->{'maxread'}) {
    $self->Debug(sprintf("Setting maxread to currmsg %d",$self-{'currmsg'}));
    $self->{'maxread'} = $self->{'currmsg'};
  }

  $self->Debug(sprintf("saving RC file id %d",$self->{'maxread'} + 1));
  if (!&SetRC($self->{'maxread'} + 1) ) {
    $self->Debug("Couldn't set last msg ID in the RC file");
    warn "Couldn't set last msg ID in the RC file\n";
  }
}

# The callback for the Cache object when it needs to retrieve a msg
sub _read_msg {
my($self,$id) = @_;
  my($msg,$ref);

  $self->Debug("In MsgsInterface::_read_msg id is $id");
  $msg = new Vmsgs::Msg($id);

  $self->Debug("Getting header");
  $ref = [&GetHeader($id)];
  $self->Debug(sprintf("headers ref is $ref, %d items",scalar(@$ref)));
  $msg->header([&GetHeader($id)]);
  
  $self->Debug("Getting body");
  $msg->body([&GetBody($id)]);

  $msg;
} # end _read_msg

# The callback for the Cache object when it thinks it should store a msg
sub _write_msg {
my($id,$item) = @_;

#  print "In MsgsInterface::_write_msg\n" if ($DEBUG);
  # We're not supporting auto-posting via the cache since it would make msgs IDs get out of sync
  # so, just return true to make the Cache object happy
  1;
}



1;
