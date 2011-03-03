#!/usr/bin/perl;
use lib '.';
use strict;
use warnings;
use fn;
use 5.010;

fn test2 ($f,$m;$lol) {
    $f->($m);
}

test2(fn ($msg) {
    say("recieved: ($msg)");
}, "ohai");

