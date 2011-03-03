#!/usr/bin/perl;
use lib '.';
use strict;
use warnings;
use Sig;
use 5.010;
say "ohai";

meth foo ($lol) {
    say "$self -> $lol";
}

foo(1,2);
