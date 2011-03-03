#!/usr/bin/perl
package Sig;
use strict;
use warnings;
use Devel::Declare;
use Devel::Declare::Context::Simple;
use B::Hooks::EndOfScope;

sub import {
    my ($class) = @_;
    my $caller = caller;

    Devel::Declare->setup_for(
        $caller,
        {
            meth => {
                const => \&parser,
            },
        }
    );
    no strict 'refs';
    *{$caller.'::meth'} = sub (&) {};
}

sub make_proto_unwrap {
    my ($proto) = @_;
    my $inject = 'my ($self';
    if (defined $proto) {
        $inject .= ", $proto" if length($proto);
        $inject .= ') = @_; ';
    }
    else {
        $inject .= ') = shift; ';
    }
    return $inject;
}

sub parser {
    my $ctx = Devel::Declare::Context::Simple->new;
    $ctx->init(@_);

    $ctx->skip_declarator;
    my $name = $ctx->strip_name;
    my $proto = $ctx->strip_proto;

    my $inject = make_proto_unwrap($proto);
    if (defined $name) {
        $inject =  $ctx->scope_injector_call(';') . $inject;
    }
    $ctx->inject_if_block($inject);
    if (defined $name) {
        $name = join('::', $ctx->get_curstash_name(), $name)
            unless ($name =~ /::/);
        $ctx->shadow(sub (&) { no strict 'refs'; *{$name} = shift; });
    }
    else {
        $ctx->shadow(sub (&) { shift });
    }
}

1;
