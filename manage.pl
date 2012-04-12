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
		#Get info listing
		my $info = `vboxmanage showvminfo '$v'`;
		if ($info) {
		print "Got info on $v\n";
		}
	
		#Extract specific facts from various places:
	
		#UUID
		my $uuid = $vms{$v};
	
		#Run-state
		my ($state) = $info =~ /^State:\s*(.+)\s+\(/m;
		debug "'$state' of $v";
	
		#Load facts into hash
		$vms{$v} = {'state' => $state, 'uuid' => $uuid};
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
		my ($op, $program);
		$program = "vboxmanage ";
	
		#List of available operations, with human-readable descriptions of each
		my %ops = (
		'pause' => 'Pause VM',
		'resume' => 'Resume execution of VM',
		'reset' => 'Hard reset VM',
		'poweroff' => 'Unplug the VM',
		'savestate' => 'Save the VM state and unload it',
		'gui' => 'Start VM with graphical console',
		'headless' => 'Start VM to run in background'
		);

		#Check if it's running...
		if ($vms{$vm}{'state'} eq 'running') {
			#Store program name
			$program .= "controlvm '$vm' ";
			#Choose safe ops
			my @safeops = ('pause', 'reset', 'poweroff', 'savestate');
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
			$op = askuser $menu_items, "q Quit\n", $count;
			$op = $safeops[$op-1];
		}
	
		#Check if it's paused...
		elsif ($vms{$vm}{'state'} eq 'paused') {
			#Store program name
			$program .= "controlvm '$vm' ";
			#Choose safe ops
			my @safeops = ('resume', 'poweroff', 'savestate');
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
			$op = askuser $menu_items, "q Quit\n", $count;
			$op = $safeops[$op-1];
		}
	
		#Check if it's saved or off...
		elsif ($vms{$vm}{'state'} eq 'saved' || $vms{$vm}{'state'} eq 'powered off') {
			#Store program name
			$program .= "startvm '$vm' --type ";
			#Choose safe ops
			my @safeops = ('headless', 'gui');
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
			$op = askuser $menu_items, "q Quit\n", $count;
			$op = $safeops[$op-1];
			
			print "$op\n";
		}
		
		#Tell the user what we'll do
		print "Executing $ops{$op}...\n";
		
		#Execute the chosen operation
		print `$program $op`;
	}
	
	#Get data about changed VM
	{
			#Get info listing
			my $info = `vboxmanage showvminfo '$vm'`;
			if ($info) {
			print "Got info on $vm\n";
			}
	
			#Extract specific facts from various places:

			#Run-state
			my ($state) = $info =~ /^State:\s*(.+)\s+\(/m;
			debug "'$state' of $vm";
	
			#Load facts into hash
			$vms{$vm}{'state'} = $state;
			debug "\n'$vms{$vm}{'state'}'\n================\n\n";
	}


}
=pod
{
	#To run or not to run
	if (%vms{$vm}) {
		#Running; give options
		}
}

=pod

	runningvms=$(vboxmanage list runningvms | sed -r '/^["]/!d; s/"([^"]*)"/\1/')

	dialog --menu "Available VMs:" 0 0 0 $(vboxmanage list vms | sed -r '/^["]/!d; s/"([^"]*)"/\1/') 2> $temp

	if [ $? -eq 1 ]
	then
		exit
	fi

	vm=$(cat $temp)

	if vboxmanage list runningvms | grep -q "$vm"
	then
		dialog --menu "Operation:" 0 0 0 pause "Pause the VM" resume "Resume the VM" savestate "Save the VM and unload it" poweroff "Pull the plug on the VM" 2> $temp

		if [ $? -eq 1 ]
		then
			exit
		fi
	#	vboxmanage controlvm "$vm" "$(cat $temp)" | dialog --programbox 0 0
		#vboxmanage controlvm "$vm" "$(cat $temp)" > $temp &

		#dialog --tailbox $temp 20 60 
		#vboxmanage controlvm "$vm" "$(cat $temp)"
		vboxmanage controlvm "$vm" "$(cat $temp)" && sleep 1 && dialog --msgbox "Operation on $vm was successful!" 10 60
	#	read
	sleep 1
	else
		dialog --yesno "Start $vm?" 0 0
		if [ $? -eq 0 ]
		then
			if [ -n "$DISPLAY" ]
			then
				type=gui
			else
				type=headless
			fi
			#vboxmanage startvm "$vm" --type $type > $temp
			#dialog --tailbox $temp 20 60
			#vboxmanage startvm "$vm" --type $type
			vboxmanage startvm "$vm" --type $type && sleep 1 && dialog --msgbox "Operation on $vm was successful!" 10 60
	#		read

	sleep 1
		fi
	fi
=cut
