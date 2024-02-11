#!/usr/bin/perl

use warnings;
use strict;

use v5.30;
use Encode;
use POSIX qw(WNOHANG);

use Data::Dumper;

use IPC::Open3 qw( open3 );
use Symbol qw( gensym );
use IO::Select;
use Time::HiRes qw( sleep usleep );

# Make STDOUT hot
STDOUT->autoflush(1);

# TODO Specify to term width for gen_seperator 
# write a function to generate a max line length and if > term_width,
# then split the line into multiple lines
my $term_width = 120;

# A handler for multiple handles
my $select = IO::Select->new();

# Command inclusion method
my $cmd_mode = 'ENV';
if (scalar(@ARGV) > 1) {
    $cmd_mode = 'ARGV';
    say STDERR q(Warning: Using ARGV for command inclusion, please use
                ENV{ENTRYPOINT_CMD} instead);
}
elsif (!$ENV{'ENTRYPOINT_CMD'} || $ENV{'ENTRYPOINT_CMD'} eq '') {
    $ENV{'ENTRYPOINT_CMD'} = q(/nocmd);
}

# Command-line options
my $cmd = do {
    if ($cmd_mode eq 'ARGV') {
        join(' ', @ARGV);
    } 
    else {
        $ENV{'ENTRYPOINT_CMD'} =~ s/\s+/ /g;
        $ENV{'ENTRYPOINT_CMD'}
    }
};

say STDERR  'Raw Passed Arguments';
if ($cmd_mode eq 'ARGV') {
    say STDERR  join(' ', @ARGV);
} else {
    say STDERR  $ENV{'ENTRYPOINT_CMD'};
}

if (
    $ENV{'SSH_ENABLE'}
    && (
        lc($ENV{'SSH_ENABLE'}) eq 'true')
        || (lc($ENV{'SSH_ENABLE'}) eq 'yes')
) {
    say STDERR  'SSH Service enabled';
    my $start_ssh = qx(service ssh start);
    chomp($start_ssh);
    say STDERR  $start_ssh;
} else {
    say STDERR  "SSH Service not enabled";
}

if (
    defined $ENV{'POSTGRESQL_ENABLE'}
    && (
        lc($ENV{'POSTGRESQL_ENABLE'}) eq 'true')
        || (lc($ENV{'POSTGRESQL_ENABLE'}) eq 'yes')
) {
    say STDERR  'PostgreSQL Service enabled';
    my $start_postgresql = qx(bash /start-postgres);
    chomp($start_postgresql);
} else {
    say STDERR  "PostgreSQL Service not enabled";
}

say STDERR  q(Beginning command execution);

# A place to keep track of all our filehanles
my $buffer = {
    'stash'       => {
        # This is used to hint to the output routine
        # which handles should be investigated,
        # plus any other temporary tasks
    },
    'config'     =>  {
        'read_size' =>  1024,
        'cmd'       =>  $cmd,
    },
    'out'       =>  {
        'offset'    =>  0,
        'data'      =>  '',
        'type'      =>  'device',
        'handle'    =>  gensym
    },
    'err'       =>  {
        'offset'    =>  0,
        'data'      =>  '',
        'type'      =>  'device',
        'handle'    =>  gensym
    },
    'log'    =>  {
        'offset'    =>  0,
        'data'      =>  '',
        'type'      =>  'file',
        'path'      =>  '/var/log/postgresql-console.log',
    }
};

# Starting open3 call
$buffer->{'config'}->{'pid'} = open3(
    undef,
    $buffer->{'out'}->{'handle'},
    $buffer->{'err'}->{'handle'},
    $buffer->{'config'}->{'cmd'}
);
# Ending open3 call

# Make sure the log file is empty
open($buffer->{'log'}->{'handle'}, '>', $buffer->{'log'}->{'path'}) or 
    die "Could not open file '".$buffer->{'log'}->{'path'}."' $!";
close($buffer->{'log'}->{'handle'});

open($buffer->{'log'}->{'handle'}, '<', $buffer->{'log'}->{'path'}) or 
    die "Could not open file '".$buffer->{'log'}->{'path'}."' $!";

# Add our filehandles to the select handler
$select->add(
    $buffer->{'out'}->{'handle'},
    $buffer->{'err'}->{'handle'},
);

# Read our various data sources, sleep for at least 100ms
my $read_bytes = sub {
    my $fh = shift;
    my $data = '';
    my $bytes_read = 0;

    $bytes_read = sysread(
        $fh,
        $data,
        $buffer->{'config'}->{'read_size'}
    );

    if ($bytes_read == 0) {
        $data = '';
    }

    return ($data,$bytes_read);
};

my $fast_read = 0;
MAIN: while ($fast_read-- || usleep(100)) {

    # Identify the filehandle
    my $handle = 'unhandled';
    HANDLEREAD: for my $fh ($select->can_read(0.1)) {
        # Read the data from the filehandles
        my $data_read;
        my $byte_size;

        if ($fh == $buffer->{'out'}->{'handle'}) {
            $handle = 'out';
            ($data_read,$byte_size) = 
                $read_bytes->($buffer->{'out'}->{'handle'});

            if ($byte_size != 0) {
                $buffer->{'stash'}->{'out'} = 1;
            }
        }
        elsif ($fh == $buffer->{'err'}->{'handle'}) {
            $handle = 'err';
            ($data_read,$byte_size) = 
                $read_bytes->($buffer->{'err'}->{'handle'});

            if ($byte_size != 0) {
                $buffer->{'stash'}->{'err'} = 1;
            }
        }

        if ($handle eq 'unhandled' || $data_read eq '') {
            next HANDLEREAD;
        }

        # Update the buffer state
        $buffer->{$handle}->{'data'} .= $data_read;
        $buffer->{$handle}->{'offset'} += $byte_size;

    }
    
    # Read the log file
    my $log_read = do {
        my $bytes_read = 1;
        my $byte_count = 0;
        while ($bytes_read) {
            $bytes_read = sysread(
                $buffer->{'log'}->{'handle'},
                $buffer->{'log'}->{'data'},
                $buffer->{'config'}->{'read_size'},
                $buffer->{'log'}->{'offset'}
            );
            if ($bytes_read != 0) {
                $buffer->{'log'}->{'offset'} += $bytes_read;
                $buffer->{'stash'}->{'log'} = 1;
                $byte_count += $bytes_read;
            }
        }
        $byte_count
    };

    foreach my $target_handler (keys %{$buffer->{'stash'}}) {
        if (!$buffer->{'stash'}->{$target_handler}) {
            next;
        }
        while ($buffer->{$target_handler}->{'data'} =~ m/\n/m)
        {
            my ($line,$rest) = split(/\n/,$buffer->{$target_handler}->{'data'},2);
            say STDERR "[$target_handler] $line"; 
            $buffer->{$target_handler}->{'data'} = $rest;
        }
        delete $buffer->{'stash'}->{$target_handler};
    }
}

close($buffer->{'log'}->{'handle'});
waitpid($buffer->{'config'}->{'pid'}, 0);
