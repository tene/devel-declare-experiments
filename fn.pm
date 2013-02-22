#!/usr/bin/perl
package fn;
use strict;
use warnings;
use Devel::Declare;
use Devel::Declare::Context::Simple;
use 5.010;

sub import {
    my ($class) = @_;
    my $caller = caller;

    Devel::Declare->setup_for(
        $caller,
        {
            fn => {
                const => \&parser,
                rv2cv => sub { use Data::Dumper; print STDERR '» ' . Dumper(\@_)},
                check => sub { use Data::Dumper; print STDERR '» ' . Dumper(\@_)},
            },
        }
    );
    no strict 'refs';
    *{$caller.'::fn'} = sub (&) {};
}

sub make_proto_unwrap {
    my ($proto) = @_;
    my ($req,$opt) = split(/\s*;\s*/, $proto, 2);
    my @it = split(/\s*,\s*/, $req);
    my $min = @it;
    my $max = @it;
    if ($opt) {
        my @opt = split(/\s*,\s*/, $opt);
        push @it, ';', @opt;
        $max += @opt;
    }
    my $p;
    my @args;
    for (@it) {
        when (';') {
            $p .= ';';
        }
        when (/^\$/) {
            $p .= '$';
            push @args, $_;
        }
        when (/^\@/) {
            $p .= '@';
            push @args, $_;
        }
        when (/^\%/) {
            $p .= '%';
            push @args, $_;
        }
        when (/^\&/) {
            $p .= '&';
            substr($_,0,1) = '$';
            push @args, $_;
        }
        default {
            die "invalid prototype arg: $_\n";
        }
    }
    my $inject = "die 'too few arguments passed' if \@_ < $min; die 'too many arguments passed' if \@_ > $max; ";
    $inject .= "my (" . join(',', @args) . ") = \@_; ";
    return $p, $inject;
}

sub parser {
    my $ctx = fn::Context->new;
    $ctx->init(@_);

    print STDERR '» ', $ctx->fmt_offset('|');
    $ctx->skip_word();
    print STDERR '» ', $ctx->fmt_offset('|');
    my $name = $ctx->strip_name;
    print STDERR '» ', $ctx->fmt_offset('|');
    my $proto = $ctx->strip_proto;
    print STDERR '» ', $ctx->fmt_offset('|');

    my ($p, $inject) = make_proto_unwrap($proto);

    $ctx->s(0, "(sub ($p)");
    print STDERR '» ', $ctx->fmt_offset('|');

    if (defined $name) {
        $inject = $ctx->scope_injector_call(');') . $inject;
        $inject = "BEGIN { sub $name ($p) { } }; ". $inject;
    }
    else {
        $inject = $ctx->scope_injector_call(')') . $inject;
    }
    $ctx->inject_if_block($inject);
    say STDERR '» ', $ctx->fmt_offset('|');
    if (defined $name) {
        $name = join('::', $ctx->get_curstash_name(), $name)
            unless ($name =~ /::/);
        $ctx->shadow(sub (&) { no strict 'refs'; no warnings 'redefine'; *{$name} = shift; });
    }
    else {
        $ctx->shadow(sub (&) { shift });
    }
}

{
    package fn::Context;
    use base 'Devel::Declare::Context::Simple';
    use B::Hooks::EndOfScope;

    sub inject_scope {
        my $class = shift;
        my $inject = shift;
        on_scope_end {
            my $linestr = Devel::Declare::get_linestr;
            return unless defined $linestr;
            my $offset  = Devel::Declare::get_linestr_offset;
            substr( $linestr, $offset, 0 ) = $inject;
            Devel::Declare::set_linestr($linestr);
        };
    }

    sub scan_word {
        my ($self, $handle_pkg) = @_;
        return Devel::Declare::toke_scan_word($self->offset, $handle_pkg);
    }

    sub s {
        my ($self, $len, $rep) = @_;
        my $line = $self->get_linestr;
        if (defined($rep)) {
            substr($line, $self->offset, $len) = $rep;
            $self->set_linestr($line);
            $self->inc_offset(length $rep);
        }
        else {
            return substr($line, $self->offset, $len);
        }
    }

    sub skip_word {
        my $self = shift;
        my $len = Devel::Declare::toke_scan_word($self->offset, 0);
        die "Couldn't find word" unless $len;
        $self->inc_offset($len);
    }

    sub fmt_offset {
        my ($self, $ind) = @_;
        my $line = $self->get_linestr;
        substr($line, $self->offset, 0) = $ind;
        return $line;
    }
}
1;
