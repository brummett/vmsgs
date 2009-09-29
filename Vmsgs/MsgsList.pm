package Vmsgs::MsgsList;

# A module for maintaining ordered lists of msgs, as needed by the Select screen,
# search results and the Read module
#
# Operation:
# Unlike version 1 of the module which stored a linked list of Msg objects, this List keeps a list
# of possible msgIDs.  It's also intended to be an interface between the program and the
# MsgsInterface and MsgsRules objects, so all access to msgs has to go through here first.
#
# On creation, you pass in the MsgsInterface object, MsgsRules object and a list of msgsIDs
# the user is allowed to see.  next() and prev() move through this list of possible msgIDs
# and if the actual msgs pass the Rules test, are then given back to the user.  All msgIDs
# that don't pass are removed from the list at run-time.
#
# $self->{'list'} contains the actual list if possible msgIDs.  The items it contains can
# be either a number (a candidate msgID), a ref to a Msg object (this msgID already
# passed the rules test), or a ref to a 2-element list containing a range [$lowid, $highid]

use Vmsgs::Debug;
use strict;

our @ISA = qw ( Vmsgs::Debug );
our $VERSION = "2.0.0";
our $DEBUG = 0;

# Create a new list object.  The List may be created empty, or initialized with a list of 
# msgIDs.  Args are:
# msgsinterface - ref to a MsgsInterface object
# msgsrules - ref to a MsgsRules object
# msgidlist - ref to a list of msgIDs allowed in this list
# current - initial current msgID
sub new {
my($class,%args) = @_;

  my $self = bless {}, $class;

  $self->start_debug(".vmsgs.debug");
  $self->Debug(sprintf("Creating new MsgsList %d items currentid %d",
                       scalar(@{$args{'msgidlist'}}),
                       $args{'current'}));
  $self->{'msgsinterface'} = $args{'msgsinterface'} || return undef;
  $self->{'msgsrules'} = $args{'msgsrules'};
print STDERR "msgsrules is $args{'msgsrules'}\n" if ($DEBUG);
  $self->{'list'} = $args{'msgidlist'};

  # Initialize the current pointer
  if (!$args{'current'}) {
    $self->{'current'} = 0;
print STDERR "initializing current pointer from scratch\n" if ($DEBUG);
    $self->_move_ptr(0);
  } else {
print STDERR "initializing current pointer to $args{'current'}\n" if ($DEBUG);
    $self->setcurrentid($args{'current'});
  }

  $self;
} # end new


# Create a new object with the same configuration as the parent,
# but be able to specify a new list of msgs
sub clone {
my($self,%args) = @_;
  my $class = ref($self) || $self;

  my @list;
  if (! defined $args{'list'}) {
print STDERR "Clone's list arg is undef\n" if ($DEBUG);
    # Copy the parent's list into the new one
    foreach (@{$self->{'list'}}) {
      push @list,$_ if $_;
    }
  } else {
print STDERR "Clone's list was given ",scalar(@{$args{'list'}})," items\n" if ($DEBUG);
    @list = @{$args{'list'}};
  }

#  my $newobj = $class->new(msgsinterface => $args{'msgsinterface'} || $self->{'msgsinterface'},
#                           msgsrules => $args{'msgsrules'} || $self->{'msgsrules'},
#                           msgidlist => \@list,
#                           current => $args{'current'});
  my $newobj = bless {}, $class;
  $newobj->{'msgsinterface'} = $args{'msgsinterface'} || $self->{'msgsinterface'};
  $newobj->{'msgsrules'} = $args{'msgsrules'} || $self->{'msgsrules'};
  $newobj->{'list'} = [[$self->minid, $self->maxid]];
  $newobj->{'current'} = $#list;
  #$newobj->currentpos($self->{'current'});
print STDERR "clone's current is ",$newobj->{'current'}," scalar is ",scalar(@list),"\n" if ($DEBUG);
  $newobj->_move_ptr(0);

  $newobj;
}



# Put a bunch of msgIDs at the end of the list
sub append {
my($self,$list) = @_;
  @{$self->{'list'}} = (@{$self->{'list'}}, @$list);
}


# Put a bunch of msgIDs at the beginning of the list
sub prepend {
my($self,$list) = @_;

  @{$self->{'list'}} = (@$list, @{$self->{'list'}});

  $self->{'current'} += scalar(@$list);
} # end prepend

# Put a bunch of msgIDs into the list at the current position
sub insert {
my($self,$list) = @_;

  splice(@{$self->{'list'}}, $self->currentpos(), 0, @$list);
  
  $self->{'current'} += scalar(@$list);
} # end insert


# Moves the current pointer, or return undef if the pointer can't be moved. 
# It always makes sure that the current pointer is at a legal msg.  So, if there are no
# more msgIDs that pass the Rules test, it'll skip all the way to the end and return undef.
# $direction is 1 to advance one and -1 to go back one.  $direction is 0 to validate the
# current position and advance if not OK.  next() and prev() are front-ends for _move_ptr
sub _move_ptr {
my($self,$direction) = @_;
  my($msg,$current,$checking);

  $current = $self->currentpos();
print STDERR "In _move_ptr direction $direction current $current\n" if ($DEBUG);
  if ($direction > 0) {   # Only allowed to move one position at a time
    $direction = 1;
  } elsif ($direction < 0) {
    $direction = -1;
  }

  if (!$direction) {
    $direction = 1;  # If 0, don't immediately advance, but set things up to advance if this one's not OK
    $checking = 1;
  } else {
    $current += $direction;  # first, move the pointer
  }

  # This counter is used to break out of the loop if the MsgsRules rejects
  # too many msgs in a row, rather than just eternally searching backwards
  # forever
  my $breakout_counter = 1000;
  NEXT_LOOP:
  while($current < $self->count() &&
        $current >= 0 &&
        $breakout_counter--) {  # If we're still within the list

    $msg = $self->{'list'}->[$current];

    # If this element is an implied range, expand it into two elements: the single msgID that's
    # actually next, and another implied range that dosen't contain this msgID
    if (ref($msg) eq "ARRAY") { 
      my($low,$high,@splicelist);
      
      ($low,$high) = @$msg;
print STDERR "Moving into range $low .. $high at current $current\n" if ($DEBUG);

      if ($low >= $high) {  # If it's not really a range
        $msg = $low;
      } elsif ($direction == -1) { # If going backward
        splice(@{$self->{'list'}}, $current, 1, [$low, $high-1], $high);
        $current++;  # Fixup for splicing in a new element
        $msg = $high;
      } else {   # If advancing forward or checking current position
        splice(@{$self->{'list'}}, $current, 1, $low, [$low+1, $high]);
        $msg = $low;
      }
    }
      
print STDERR sprintf("Stored msg is %s list has %d elements now current is $current\n", $msg, $self->count()) if ($DEBUG);

    if (ref($msg)) {  # If it now points to an already-loaded msg
      $self->{'current'} = $current;
      return $msg;  # Nothing else to do
    } else {
      $msg = $self->{'msgsinterface'}->Get($msg);  # Retrieve the Msg object for this msgID
      if (!defined($self->{'msgsrules'}) or $self->{'msgsrules'}->pass($msg)) {
print STDERR "Retrieved msg passed the Rules test current is $current\n" if ($DEBUG);
        $breakout_counter = 1000;   # reset the breakout counter
        $self->{'current'} = $current;
        $self->incorporate($msg);
        return $msg;
      } else {    # Didn't pass the Rules test, remove this msgID from the list
print STDERR "Didn't pass the Rules test, removing msgID from the list\n" if ($DEBUG);
        splice(@{$self->{'list'}}, $current, 1);
        # $self->_fixup_current_stack($current);
        $current += $direction if ($direction < 0);  # Fixup the current pointer if moving backward
        next NEXT_LOOP;    # retry the test with the next msgID
      }
    } # end else not already a Msg object

    $current += $direction;
  } # end while

  # If we're only checking the current pointer, and we got to the end without finding
  # a good msg, retry the loop going backward
  if ($checking && $direction == 1) {
print STDERR "Didn't check out working forward, trying backward\n" if ($DEBUG);
    $current = $#{$self->{'list'}};
    $direction = -1;
    goto NEXT_LOOP;
  }

  if ($breakout_counter < 1) {
    $self->no_matches(1);
  }
print STDERR "Can't change the pointer, returning undef\n" if ($DEBUG);
  return undef;  # We went through the whole list and didn't find a good msg
} # end _move_ptr

sub no_matches {
my($self,$val) = @_;
  if (defined $val) {
    $self->{'no_matches'} = $val;
  } else {
    $self->{'no_matches'};
  }
}

sub next {
  $_[0]->_move_ptr(1);
}

sub prev {
  $_[0]->_move_ptr(-1);
}
      

# Store the given Msg object at the current position.  This is a full method so that
# callers can create populated lists, like the search and mark functionality will need
sub incorporate {
my($self,$msg) = @_;

  $self->{'list'}->[$self->currentpos()] = $msg;
  $self->Debug(sprintf("Setting list position %d to %s",
                       $self->currentpos(),
                       $self->{'list'}->[$self->currentpos()]));
} # end incorporate


# Return a Msg object for the msgID at the current position.  _move_ptr always ensures that 
# the current pointer will be at a good Msg object
sub get {
my($self) = @_;
  $self->Debug(sprintf("getting msg at list position %d msg is %s",
                       $self->currentpos(),
                       $self->{'list'}->[$self->currentpos()]));
  $self->{'list'}->[$self->currentpos()];
  # $self->{'msgsinterface'}->Get($self->{'list'}->[$self->currentpos()]);
} # end get
    


# Get or set the current position in the list
sub currentpos {
my($self,$arg) = @_;
  $self->Debug("In currentpos arg is $arg");

  if (defined($arg)) {
    $self->Debug("Setting current position trying $arg");
    $self->{'current'} = $arg;
    $self->_move_ptr(0);
    $self->Debug(sprintf("Current position is now %d",
                         $self->{'current'}));
  }
  $self->{'current'};
} # end currentpos

# Get the msgID of the current item
sub currentid {
my($self) = @_;
  
  my $msg = $self->{'list'}->[$self->currentpos()];
  if (ref($msg)) {
    # $msg must be a Msg object
    $msg->id();
  } else {
    $msg;  # Must be a msgID instead
  }
} # currentid


# How many items are currently in the list
sub count {
my($self) = @_;
return scalar(@{$self->{'list'}});
  my $retval = 0;

  foreach ( @{$self->{'list'}} ) {
    if (ref($_) eq 'ARRAY') {
      $retval += $_->[1] - $_->[0] + 1;
    } else {
      $retval++;
    }
  }
  $retval;
} # end count

# Return the max msgid in the list
sub maxid {
my($self) = @_;
  my $last = $self->{'list'}->[$#{$self->{'list'}}];
  if (ref($last) eq 'ARRAY') {
    return $last->[1];
  } elsif (ref($last) && $last->can('id')) {
    return $last->id;
  } elsif (! ref($last)) {
    return $last;
  } else {
    die "Can't get last item from $last\n";
  }
}

sub minid {
my($self) = @_;
  my $first = $self->{'list'}->[0];
  if (ref($first) eq 'ARRAY') {
    return $first->[0];
  } elsif (ref($first) && $first->can('id')) {
    return $first->id;
  } elsif (! ref($first)) {
    return $first;
  } else {
    die "Can't get first item from $first\n";
  }
}



## The current-save stach shouldn't be used anymore
## Save the current position on the save stack
#sub pushcurrent {
#my($self) = @_;
#  push(@{$self->{'currentstack'}}, $self->currentpos());
#}
#
##sub new_pushcurrent {
##my($self) = @_;
##  push(@{$self->{'currentstack'}}, \{$self->{'list'}->[$self->currentpos()]});
##}
#
##sub new_popcurrent {
##my($self) = @_;
##  my($ref);
##
##  $ref = pop(@{$self->{'currentstack'}});
##  # Now search through the list to find where that reference points to
##  foreach (0 .. $#{$self->{'list'}}) {
##    if ($ref eq \{$self->{'list'}->[$_]}) {
##      return $self->currentpos($_);
##    }
##  }
##  return undef;
##}
#  
#
## Get the current position from the save stack
#sub popcurrent {
#my($self) = @_;
#  $self->currentpos(pop(@{$self->{'currentstack'}}));
#}
#
#
## If msgs are removed whose position is numerically lower than any of the
## positions in the save stack, then we have to decrement the saved positions.
## The price we pay for using a Perl list and not a linked list
#sub _fixup_current_stack {
#my($self,$position) = @_;
#  my(@list,$pos);
#
#  return unless ($self->{'currentstack'});
#  @list = @{$self->{'currentstack'}};
#  foreach $pos ( 0 ..  $#list) {
#    if ($self->{'currentstack'}->[$pos] < $position) {
#      $self->Debug(sprintf("Removed position $position is greater than at stack pos $_: %d",$self->{'currentstack'}->[$pos]));
#      $self->{'currentstack'}->[$pos]--;
#    }
#  }
#} # end _fixup

# Search for the given msgid and set the current pointer to its position
sub setcurrentid {
my($self,$msgid) = @_;
  my($msg,$trypos);

print STDERR "Looking to set current list position to msgid $msgid\n" if ($DEBUG);

  $trypos = 0;
  while ($trypos <= $#{$self->{'list'}}) {
print STDERR "Trying position $trypos\n" if ($DEBUG);
    $msg = $self->{'list'}->[$trypos];
    if (ref($msg) eq "ARRAY") {  # This is a range element
      my($low,$high,@splicelist);

      ($low,$high) = @$msg;
      if ($msgid >= $low and $msgid <= $high)  { # The one we're looking for is in this range
print STDERR "msgid falls into the range $low .. $high\n" if ($DEBUG);

        @splicelist = $self->_splicerange($msgid, $low,$high);
         
        splice(@{$self->{'list'}}, $trypos, 1, @splicelist);
        $trypos++ if ($msgid != $low);  # Fixup position if we inserted an item

        #$self->dump($trypos-2, $trypos+2);
        $self->currentpos($trypos);
        return $trypos;
      } # end if in this range

    } elsif (ref($msg) && $msg->id() == $msgid) {  # If it's a Msg object
print STDERR "matched Msg object's id\n" if ($DEBUG);
      $self->currentpos($trypos);
print STDERR "back from setting currentpos\n" if ($DEBUG);
      return $trypos;
    } elsif ($msg == $msgid) {  # If it's a plain msgid and it matches
print STDERR "matched msgid stored in that slot\n" if ($DEBUG);
      $self->currentpos($trypos);
      return $trypos;
    }
    $trypos++;
  } # end while

  return undef;  # no match found
} # end setcurrentid


# Used by setcurrentid and _move_ptr to chop up a range when you try to move inside it
# Returns the list that gets spliced into the current position
sub _splicerange {
my($self,$msgid,$low,$high) = @_;
  my(@retval);

  if ($msgid == $low) {
    $self->Debug("msgid $msgid matched the lower bound");
    @retval = ( $msgid, [$msgid+1, $high]);
  } elsif ($msgid == $high) {
    $self->Debug("msgid $msgid matched the upper bound");
    @retval = ( [$low, $msgid-1], $msgid);
  } else {
    $self->Debug("msgid $msgid is in the middle of the range $low .. $high");
    @retval = ([$low, $msgid-1], $msgid, [$msgid+1, $high]);
  }

  # Now, check the ranges at either end of @retval and make sure they're really ranges
  foreach ( 0, $#retval ) {
    if (ref($retval[$_])) {
      if ($retval[$_]->[0] >= $retval[$_]->[1]) {
        $self->Debug(sprintf("Lopsided range %d, %d, changing to single id %d",
                             $retval[$_]->[0], $retval[$_]->[1], $retval[$_]->[0]));
        $retval[$_] = $retval[$_]->[0];
      }
    }
  } # end foreach
  
  @retval;
} # end _splicerange


sub dump {
my($self,$low,$high) = @_;
  my $current = $self->{'current'};
  my $item = $self->{'list'}->[$current];

print STDERR "Dump of MsgList $self from $low to $high: current pos $current current item $item\n";
  
  if (!defined($low) or !defined($high)) {
    $low = 0;
    $high = $#{$self->{'list'}};
  }
 
  my $itemnum = $low-1;    
  while ($itemnum <= $high ) {
    $itemnum++;
    my $string = "Item at position $itemnum ";
    $item = $self->{'list'}->[$itemnum];
    next unless defined($item);

    if (ref($item) eq "ARRAY") {
      $string .= "range from " . $item->[0] . " to " . $item->[1];
    } elsif (ref($item)) {
      $string .= "Msg object id " . $item->id();
    } else {
      $string .= "raw msgid $item";
    }
print STDERR $string,"\n";
  } # end while

print STDERR "End of Dump\n";
} # end dump
   
1;
