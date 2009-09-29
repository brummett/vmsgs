package Vmsgs::Cache;

# An object for caching things

$VERSION = "1.0";
$DEBUG = 0;

# Create a new cache.  $size is the number of items to store in the cache
# $read_fcn and $write_fcn are names of methods in object $obj that can
# read and write items from the backing store.  If $writeback is true, the
# cache will operate in write-back mode; otherwise, it's write-through
# If $read_fcn and/or $write_fcn aren't specified, then it'll use the method names
# 'read' and 'write'
sub new {
my($class,$obj,$size,$read_fcn,$write_fcn,$writeback) = @_;
  my($self);

  print "Creating new cache\n" if ($DEBUG);

  $self->{'obj'} = $obj;
  $self->{'maxsize'} = $size;
  $self->{'size'} = 0;
  $self->{'read'} = $read_fcn || "read";
  $self->{'write'} = $write_fcn || "write";
  $self->{'items'} = undef;  # The actual cache.
  $self->{'ages'} = undef;  # Ref to an array.  As items are added to the cache, the id's
                            # get pushed onto the end; older items are at the head
  $self->{'writeback'} = $writeback;
  $self->{'changed'} = undef;  # ref to a hash; keys are item id's, value set to true if the
                               # item has changed since read and should be saved before delete in
                               # write-back mode

  bless $self,$class;
}


# Get an item out of the cache.  If the requested ID isn't there, fetch it from the source
# using the read_fcn
sub get {
my($self,$id) = @_;
  my($item);

  print "In Cache::get id is $id\n" if ($DEBUG);

  # Is the requested item in the cache?
  if ($self->{'items'}->{$id}) {
    print "Item $id in cache\n" if ($DEBUG);
    $self->{'items'}->{$id};
  } else {
    print "Item $id not in cache... fetching " if ($DEBUG);
    # We have to fetch it
    my($obj,$fcn) = ($self->{'obj'}, $self->{'read'});

    print "obj $obj method $fcn " if ($DEBUG);
    $item = $obj->$fcn($id);
    print "item >>$item<<\n" if ($DEBUG);
    $self->put($id,$item);

    $item;
  }
} # end get




# Put an item into the cache.  Can be called internally or externally
sub put {
my($self,$id,$value) = @_;
  my($pos,$item);

  print "In Cache::put\n" if ($DEBUG);

  if ($self->{'items'}->{$id}) {  # Item is already in the cache
    print "Item $id already in cache\n" if ($DEBUG);

    $pos = $self->_ages_list_pos($id);
    if (defined($pos)) {  # move the item to the end of the ages list
      push(@{$self->{'ages'}},
           splice(@{$self->{'ages'}}, $pos, 1));
    } else {
      warn "Item $id cache $cache: item in items hash but not in ages list\n";
    }
  } else {  # Item $id isn't currently in the cache
    print "Item $id not in cache\n" if ($DEBUG);

    # Clear out enough room for the new item
    while($self->{'size'} >= $self->{'maxsize'}) {
      $item = shift(@{$self->{'ages'}});  # Get the oldest item
      print "Removing item $item to make space\n" if ($DEBUG);
      $self->remove($item,1);
    }

    push(@{$self->{'ages'}}, $id);
    print "pushed id $id onto the ages list.  list now is ",join(",", @{$self->{'ages'}}),"\n" if ($DEBUG);
  }

  $self->{'items'}->{$id} = $value;
  $self->{'size'}++;

  if (! $self->{'writeback'}) {  # !$writeback means write-through
    print "writing item $id to backing store as write-through " if ($DEBUG);
    my($obj,$fcn) = ($self->{'obj'}, $self->{'write'});
    print "object ",ref($obj)," method $fcn\n" if ($DEBUG);
    $obj->$fcn($id,$value);
  } else {
    print "making item $id as changed for write-through\n" if ($DEBUG);
    $self->{'changed'}->{$id} = 1;
  }
} # end put


# Remove an item from the cache.  Can be called internally or externally.  If $internal
# is true, then assumme we're called internally and don't search the ages list first
# retval is undef if $id isn't in the cache, or the number of items left in the cache
# after the delete
sub remove {
my($self,$id,$internal) = @_;
  my($item,$pos);

  print "In Cache::remove\n" if ($DEBUG);

  # Is that item even in the cache?
  return undef unless (defined($self->{'items'}->{$id}));

  print "Item $id is in the cache\n" if ($DEBUG);

  # Not internal; search for the item in the ages list
  if (!$internal) {
    $pos = $self->_ages_list_pos($id);
    print "item is position $pos in the ages list\n" if ($DEBUG);
    if (defined($pos)) {
      splice(@{$self->{'ages'}}, $pos, 1);  # Remove the item from the list
    } else {
      warn "Removing item $id from cache $self: item not in ages list\n" unless ($flag);
    }
  }

  # Should we write-back?
  if (defined($self->{'writeback'} && $self->{'changed'}->{$id})) {
    print "Writing item $id back to the backing store " if ($DEBUG);
    my($obj,$fcn) = ($self->{'obj'}, $self->{'write'});
    print "object ",ref($obj)," method $fcn\n" if ($DEBUG);
    $obj->$fcn($id,$self->{'items'}->{$id});  # Call the write method
  }

  delete($self->{'items'}->{$id});
  delete($self->{'changed'}->{$id});
  $self->{'size'}--;
} # end remove


# Remove everything from the cache
sub flush {
my($self) = @_;
  my($id);
  
  print "In Cache::flush\n" if ($DEBUG);

  while(scalar(@{$self->{'ages'}})) {
    $id = shift(@{$self->{'ages'}});
    print "removing id $id\n" if ($DEBUG);
    $self->remove($id,1);
  }
  print "Done flushing\n" if ($DEBUG);
} # end flush


# Returns the index into the ages list where this id lives; undef if it isn't there
sub _ages_list_pos {
my($self,$id) = @_;
  
  print "In _ages_list_pos\n" if ($DEBUG);

  foreach ( 0 .. scalar(@{$self->{'ages'}}) ) {
    print "checking id $id against list position $_: ",$self->{'ages'}->[$_],"\n" if ($DEBUG);
    if ($id eq $self->{'ages'}->[$_]) {
      print "Found it!\n" if ($DEBUG);
      return $_;
    }
  }

  print "Nothing matched\n" if ($DEBUG);
  return undef;
} # end _ages_list_pos


sub dump {
my($self) = @_;
  my($id);

  print "\nDump of ",ref($self)," $self\n";
  printf("backing store object is %s %s read method %s write nethod %s\n",
         ref($self->{'obj'}),$obj,$self->{'read'},$self->{'write'});
  printf("max size %d current size %d\n", $self->{'maxsize'}, $self->{'size'});
  print "writeback flag is $writeback\n";
  print "ages list is ",join(" ",@{$self->{'ages'}}),"\n";
  print "Items dump:\n";
  foreach $id (keys(%{$self->{'items'}})) {
    printf("Item %s  changed %d value %s\n",
           $self->{'items'}->{$id}, $self->{'changed'}->{$id});
    eval '$item->dump();';
  }
}  # end dump


1;
