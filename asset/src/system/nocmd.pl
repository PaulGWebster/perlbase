#!/usr/bin/env perl

use warnings;
use strict;
use v5.30;

my $onetime = 1;

my $msg = q(environmental variable ENTRYPOINT_CMD missing, )
        . q(please set it in docker-compose.yml or use the )
        . q(-e flag with docker run);

while($onetime-- == 1 || sleep(10)) { 
    say STDERR "$msg";
    say STDOUT "$msg";
}