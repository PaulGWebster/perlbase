#!/usr/bin/perl

use warnings;
use strict;

use v5.30;
use Env;

use IPC::Open3 qw( open3 );
use Symbol qw( gensym );
use IO::Select;
use Text::ParseWords qw( shellwords quotewords );

# Specify to term width for gen_seperator
my $term_width = 80;

# Command inclusion method
my $cmd_mode = 'ENV';
if (scalar(@ARGV) > 1) {
    $cmd_mode = 'ARGV';
    say STDERR gen_seperator(
        'Warning: Using ARGV for command inclusion, please use '
        .'ENV{ENTRYPOINT_CMD} instead'
    );
}
elsif (!$ENV{'ENTRYPOINT_CMD'} || $ENV{'ENTRYPOINT_CMD'} eq '') {
    $ENV{'ENTRYPOINT_CMD'} = q(/nocmd);
}

# Make both STDERR and STDOUT hot
select STDERR;
$| = 1;
select STDOUT;
$| = 1;

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

sub gen_seperator {
    my $command = shift;
    $command||='';

    if ($command =~ m/\n/m) {
        my @result;
        my @lines = split(/\n/,$cmd);
        foreach my $line (@lines) {
            chomp($line);
            push @result,gen_seperator($line);
        }
        return join("\n",@result);
    }

    my $brace = '|';
    my $bar = '-';
    my $adjusted_term_width = ($term_width-2);
    my $command_length = length($command)+2;
    if ($command_length > $adjusted_term_width) {
        $command = substr($command,0,$adjusted_term_width);
        $command_length = $adjusted_term_width;
    }
    if (($command_length % 2) != 0) {
        # We have an uneven number
        $command .= ' ';
        $command_length = length($command)+2;
    }
    my $command_diff = ($term_width - $command_length);
    if ($command_diff == 2) {
        return "$brace$command$brace";
    }
    if ($command eq '') {
        return "$bar"x($term_width-2);
    }
    else {
        my $side_length = ($command_diff/2) - 1;
        return "$bar"x$side_length.$brace.$command.$brace."$bar"x$side_length;
    }
}

say STDERR gen_seperator('Raw Passed Arguments');
if ($cmd_mode eq 'ARGV') {
    say STDERR gen_seperator(join(' ', @ARGV));
} else {
    say STDERR gen_seperator($ENV{'ENTRYPOINT_CMD'});
}

if ($ENV{'SSH_ENABLE'} && (lc($ENV{'SSH_ENABLE'}) eq 'true') || (lc($ENV{'SSH_ENABLE'}) eq 'yes')) {
    say STDERR gen_seperator('SSH Service enabled');
    my $start_ssh = `service ssh start`;
    chomp($start_ssh);
    say STDERR gen_seperator($start_ssh);
} else {
    say STDERR gen_seperator("SSH Service not enabled");
}

say STDERR gen_seperator(q(Beginning command execution));

# Use open3 to run the command as the specified user and capture stdout and stderr
my $out = gensym;
my $err = gensym;
# Starting open3 call
my $pid = open3(undef, $out, $err, $cmd);
if ($!) {
    gen_seperator("Error after open3: $!");
}
# Ending open3 call

# Create an IO::Select object and add the output handles
my $sel = IO::Select->new();
$sel->add($out, $err);

# While there's still output to read
while ($sel->count > 0) {
    # Check which handles have data to read
    for my $fh ($sel->can_read) {
        # Read a line from this handle
        my $line = <$fh>;
        if (defined $line) {
            # Print the line to the appropriate output
            if ($fh == $out) {
                print STDOUT "STDOUT: $line";
            } else {
                print STDERR "STDERR: $line";
            }
        } else {
            # If there's no more data to read on this handle, remove it from the select object
            $sel->remove($fh);
        }
    }
}

waitpid($pid, 0);
