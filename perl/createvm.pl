#!/usr/bin/perl
#
# Based on VMWare examples

use strict;
use warnings;
use POSIX qw(ceil floor);
use VMware::VIRuntime;
use VMware::VICommon;
use lib "/usr/lib/vmware-vcli/apps";
use JSON;
use IO::Socket::SSL;
use AppUtil::VMUtil;
use AppUtil::HostUtil;

# Ignore SSL warnings or invalid server warning
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

IO::Socket::SSL::set_ctx_defaults(
     SSL_verifycn_scheme => 'www',
     SSL_verify_mode => 0,
);

# Changeable options
my %opts = (
		action => {
                type => "=s",
                help => "What to do",
                required => 1,
        },
        resourcepool => {
                type => "=s",
                help => "ESXi Host in cluster to deploy VM to",
                required => 1,
                default => "esxi-host",
        },
        vmtemplate => {
                type => "=s",
                help => "Name of VM Template (source VM)",
                required => 1,
                default => "vmMachineTemplate",
        },
        vmname => {
                type => "=s",
                help => "Name to set for the new VM",
                required => 1,
        },
        datastore => {
                type => "=s",
                help => "Name of datastore in vCenter",
                required => 1,
        },
        folder => {
                type => "=s",
                help => "Folder where to deploy the new VM. If not defined, the value is the same folder as the template",
                required => 0,
				default => "SelfPortalVMs",
        },
		'datacenter' => {
      		type => "=s",
      		help => "The name of the virtual machine",
      		required => 0,
   		},
);
Opts::add_options(%opts);
Opts::parse();

sub deploy_template() {
        my ($vmtemplate, $datastore, $resourcepool, $folder, $vm_view, $vmname);

		$vmname = Opts::get_option('vmname');
        $datastore = Vim::find_entity_view( view_type => 'Datastore', filter => { 'name' => Opts::get_option('datastore') } );
		$resourcepool = Vim::find_entity_view( view_type => 'ResourcePool', filter => { 'name' => Opts::get_option('resourcepool') } );
        $vm_view = Vim::find_entity_view( view_type => 'VirtualMachine', filter => { 'config.uuid' => Opts::get_option('vmtemplate') } );

        my %relocate_params;
        my $datastore_info;
        %relocate_params = ( datastore => $datastore->summary->datastore, pool => $resourcepool->{mo_ref} );

        my $relocate_spec = get_relocate_spec(%relocate_params);

        my $clone_spec = VirtualMachineCloneSpec->new( powerOn => 1, template => 0, location => $relocate_spec);

        if (Opts::get_option('folder')) {
                  my $folder_name = Opts::get_option('folder');
                  $folder = Vim::find_entity_view( view_type => 'Folder', filter => { 'name' => $folder_name } );
        } else {
                  $folder = $vm_view->parent;
        }

		my $result = $vm_view->CloneVM_Task(  folder => $folder, name => $vmname, spec => $clone_spec );
        my $task=Vim::get_view(mo_ref=>$result)->info;
		print $result->value;

}

sub update_task()
{
    my $Mor = new ManagedObjectReference();
	$Mor->{type}="Task";
	$Mor->{value}=Opts::get_option('vmname');
	my $task;
	eval{
		$task=Vim::get_view(mo_ref=>$Mor)->info;
	};
	if ($@) { print 1; }
	elsif ($task->state->val eq 'success') {print Vim::get_view(mo_ref=>$task->result)->summary->config->uuid;}
	elsif ($task->state->val eq 'error') {print $task->error->localizedMessage;}
	else {print 0;}
}

sub get_relocate_spec() {
        my %args = @_;
        my $datastore = $args{datastore};
        my $resourcePool = $args{pool};
        my $relocate_spec = VirtualMachineRelocateSpec->new( datastore => $datastore, pool => $resourcePool );
        return $relocate_spec;
}

Util::connect();

if (Opts::get_option('action') eq 'createvm')
{ deploy_template(); }
elsif (Opts::get_option('action') eq 'updateinfo')
{ update_task(); }

Util::disconnect();