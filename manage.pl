#!/usr/bin/perl

use warnings;
use strict;

#Comment out the print statement to turn off debug output
sub debug {
#print @_;
}

#Ask the user for input
sub askuser {
my ($menu_items, $quit, $max) = @_;

USERASK: {
		#Tell the user what to do
		print "Please choose an item from the list below:\n\n";
		print "$menu_items$quit\n";
	
		#Get the user's desired item
		my $item = <STDIN>;
		
		#Clean trailing newline (if present)
		chomp $item;
		
		#Check that $item is a number
		{
			#Disable warnings--cleaner output if it isn't a number
			no warnings;
			
			#Is it even a number?
			if ($item == 0) {
				#Check if the user is quitting
				if ($item eq 'q') {
					exit 1;
				}
				print "That's not a number!\n";
				redo USERASK;
			}
		}
		
		#Convert $item to an int
		$item = int $item;

		#It's a number. Is is a valid one?
		if ($item < 1 || $item > $max) {
			print "That's not on the list.\n";
			redo USERASK;
		}
		
		return $item;
	}
}

sub getprogram {
	#Break up arguments
	#$vm: VM name
	#@safeops: An array of strings, each the name of an acceptable operation for the VM's current state
	my ($vm, @safeops) = @_;
	
	my $program = "vboxmanage ";

	#List of available operations, with human-readable descriptions of each
	my %ops = (
		'pause' => 'Pause VM',
		'resume' => 'Resume execution of VM',
		'reset' => 'Hard reset VM',
		'poweroff' => 'Unplug the VM',
		'savestate' => 'Save the VM state and unload it',
		'gui' => 'Start VM with graphical console',
		'headless' => 'Start VM to run in background',
		'delete' => 'Delete saved state'
	);

	#List of program names for each op (all from vboxmanage)
	my %program = (
		'pause' => "controlvm '$vm' pause",
		'resume' => "controlvm '$vm' resume",
		'reset' => "controlvm '$vm' reset",
		'poweroff' => "controlvm '$vm' poweroff",
		'savestate' => "controlvm '$vm' savestate",
		'gui' => "startvm '$vm' --type gui",
		'headless' => "startvm '$vm' --type headless",
		'delete' => "discardstate '$vm'"
	);

	debug "@safeops\n";

	#Init variables
	my $count = 1;
	my $menu_items;

	#Add each op to the menu
	foreach my $i (@safeops) {
		$menu_items .= "$count $ops{$i}\n";
		$count ++;
	}
	#Ask user what to do, and store that opname from @safeops
	my $op = askuser $menu_items, "q Quit\n", $count;
	$op = $safeops[$op-1];
	
	debug "$op\n";
	
	#Return the name of the program to run:
	return ($op, $ops{$op}, $program . $program{$op});
}

sub getinfo {
	#Break up arguments
	#$v: VM name to get info for
	my ($v) = @_;
	
	#Get info listing
	my $info = `vboxmanage showvminfo '$v'`;
	
	#Tell the user if we got info
	if ($info) {
		print "Got info on $v\n";
	} else {
		exit 2;
	}
	
	#Extract specific facts from various places:
	
	#UUID
	my ($uuid) = $info =~ /^UUID:\s*(\S+)/m;

	#Run-state
	my ($state) = $info =~ /^State:\s*(.+)\s+\(/m;
	debug "'$state' of $v";

	#Return hash of facts
	return {'state' => $state, 'uuid' => $uuid};
}

#BEGIN PROGRAM
#=============

#Scope variables for whole program
my (%vms, @vms, $vm);

#Get list of VMs
{
	#Get information about the available VMs
	my $vms = `vboxmanage list vms`;

	#Split the command output into name-uuid pairs; eliminate lines w/o a pair
	my $regexp = '^"([^"]+)" \{([^}]+)\}$';
	%vms = $vms =~ /$regexp/mgo;

	@vms = keys %vms;
}

#Get data about VMs
{
	#Gather further info about each vm
	foreach my $v (@vms) {
		#Get info for each VM
		$vms{$v} = getinfo $v;
		
		debug "\n'$vms{$v}{'state'}'\n================\n\n";
	}
}

#Loop until quit
for (;;) {

	print "\n\n";

	#Ask the user which VM to work on
	{
		#Initialize variable for scope
		my $menu_items;
		my $count = 0;
	
		#Look at each vm
		foreach my $v (@vms) {
			my $marker;
			
			#Increment the number of this item
			$count++;
					
			#Choose proper marker
			if ($vms{$v}{'state'} eq 'running') {debug "$v running\n"; $marker = '>>';}
			elsif ($vms{$v}{'state'} eq 'paused') {debug "$v paused\n"; $marker = '||';}
			elsif ($vms{$v}{'state'} eq 'saved') {debug "$v saved\n"; $marker = '[]';}
			elsif ($vms{$v}{'state'} eq 'powered off') {debug "$v powered off\n"; $marker = '  ';}
		
			#Add line to menu
			$menu_items .= "$marker $count $v\n";

		}
		my $item = askuser $menu_items, "   q Quit\n", $count;
	
		#Check if the user canceled
		if ($item == $count) {
			exit 1;
		}
		
		#Store the name of the chosen VM
		$vm = $vms[$item-1];
		
		#Tell the user what we saw
		print "'$vm' chosen.\n";
	
	}

	#Offer the user the possible options, depending on VM state
	{
		#Scope variables to store operation name & program name
		my @opinfo;
	
		#Check if it's running...
		if ($vms{$vm}{'state'} eq 'running') {
			@opinfo = getprogram $vm, ('pause', 'reset', 'poweroff', 'savestate');
		}
	
		#Check if it's paused...
		elsif ($vms{$vm}{'state'} eq 'paused') {
			@opinfo = getprogram $vm, ('resume', 'poweroff', 'savestate');
		}
	
		#Check if it's saved...
		elsif ($vms{$vm}{'state'} eq 'saved') {
			@opinfo = getprogram $vm, ('headless', 'gui', 'delete');
		}
		
				#Check if it's off...
		elsif ($vms{$vm}{'state'} eq 'powered off') {
			@opinfo = getprogram $vm, ('headless', 'gui');
		}

		#Tell the user what we'll do
		print "Executing $opinfo[0]...\n";
		
		#Execute the chosen operation
		print `$opinfo[2]`;
	}
	
	#Get data about changed VM
	{
			#Load facts into hash
			$vms{$vm} = getinfo $vm;
			debug "\n'$vms{$vm}{'state'}'\n================\n\n";
	}


}
