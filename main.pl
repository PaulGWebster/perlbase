#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
my $server_endpoint = "https://api.binance.com/api/v3/ticker/bookTicker";

# set custom HTTP request header fields
my $req = HTTP::Request->new(GET => $server_endpoint);
$req->header('content-type' => 'application/json');

my $resp = $ua->request($req);
if ($resp->is_success) {
    my $message = $resp->decoded_content;
    print "Received reply: $message\n";
}
else {
    print "HTTP GET error code: ", $resp->code, "\n";
    print "HTTP GET error message: ", $resp->message, "\n";
}
