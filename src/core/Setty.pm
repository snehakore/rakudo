my role Setty does Associative {
    has %!elems; # key.WHICH => key

    method BUILD (:%!elems) {}
    method default(--> Bool) { False }
    method keys { %!elems.values }
    method values { True xx %!elems.elems }
    method elems(--> Int) { %!elems.elems }
    method exists ($k --> Bool) {  # is DEPRECATED doesn't work in settings
        once DEPRECATED("Method 'Setty.exists'","the :exists adverb");
        self.exists_key($k);
    }
    method exists_key($k --> Bool) {
        so nqp::existskey(%!elems, nqp::unbox_s($k.WHICH));
    }
    method Bool { %!elems.Bool }
    method Numeric { %!elems.Numeric }
    method Real { %!elems.Numeric.Real }

    method hash(--> Hash) {
        my %e;
        %e{$_} = True for %!elems.values;
        %e;
    }

    method new(*@args --> Setty) {
        my %e;
        %e{$_.WHICH} = $_ for @args;
        self.bless(:elems(%e));
    }
    method new-fp(*@pairs --> Setty) {
        my %e;
        for @pairs {
            when Pair {
                %e{.key.WHICH} //= $_.key if .value;
            }
            default {
                %e{.WHICH} //= $_;
            }
        }
        self.bless(:elems(%e));
    }

    method ACCEPTS($other) {
        self.defined
          ?? $other (<=) self && self (<=) $other
          !! $other.^does(self);
    }

    multi method Str(Setty:D $ : --> Str) { ~ %!elems.values }
    multi method gist(Setty:D $ : --> Str) {
        my $name := self.^name;
        ( $name eq 'Set' ?? 'set' !! "$name.new" )
        ~ '('
        ~ %!elems.values.map( {.gist} ).join(', ')
        ~ ')';
    }
    multi method perl(Setty:D $ : --> Str) {
        my $name := self.^name;
        ( $name eq 'Set' ?? 'set' !! "$name.new" )
        ~ '('
        ~ %!elems.values.map( {.perl} ).join(',')
        ~ ')';
    }

    method list() { %!elems.values }
    method pairs() { %!elems.values.map({ $_ => True }) } 
    method pick($count = 1) { %!elems.values.pick($count) }
    method roll($count = 1) { %!elems.values.roll($count) }

    # TODO: WHICH will require the capability for >1 pointer in ObjAt
}

proto sub infix:<(elem)>($, $ --> Bool) {*}
multi sub infix:<(elem)>($a, Any $b --> Bool) {
    $a (elem) $b.Set(:view);
}
multi sub infix:<(elem)>($a, Set $b --> Bool) {
    $b.exists_key($a);
}
# U+2208 ELEMENT OF
only sub infix:<<"\x2208">>($a, $b --> Bool) {
    $a (elem) $b;
}
# U+2209 NOT AN ELEMENT OF
only sub infix:<<"\x2209">>($a, $b --> Bool) {
    $a !(elem) $b;
}

proto sub infix:<(cont)>($, $ --> Bool) {*}
multi sub infix:<(cont)>(Any $a, $b --> Bool) {
    $a.Set(:view) (cont) $b;
}
multi sub infix:<(cont)>(Set $a, $b --> Bool) {
    $a.exists_key($b);
}
# U+220B CONTAINS AS MEMBER
only sub infix:<<"\x220B">>($a, $b --> Bool) {
    $a (cont) $b;
}
# U+220C DOES NOT CONTAIN AS MEMBER
only sub infix:<<"\x220C">>($a, $b --> Bool) {
    $a !(cont) $b;
}

only sub infix:<(|)>(**@p) {
    if @p.grep(Baggy) {
        my $keybag = KeyBag.new;
        for @p.map(*.Bag(:view)) -> $bag {
            $keybag{$_} max= $bag{$_} for $bag.keys;
        }
        $keybag.Bag(:view);
    }
    else {
        Set.new( @p.map(*.Set(:view).keys) );
    }
}
# U+222A UNION
only sub infix:<<"\x222A">>(|p) {
    infix:<(|)>(|p);
}

only sub infix:<(&)>(**@p) {
    return set() unless @p;

    if @p.grep(Baggy) {
        my $keybag = @p[0] ~~ KeyBag
          ?? KeyBag.new-fp(@p.shift.pairs)
          !! @p.shift.KeyBag;
        for @p.map(*.Bag(:view)) -> $bag {
            $bag{$_}
              ?? $keybag{$_} min= $bag{$_}
              !! $keybag.delete_key($_)
              for $keybag.keys;
        }
        $keybag.Bag(:view);
    }
    else {
        my $keyset = @p[0] ~~ KeySet
          ?? KeySet.new(@p.shift.keys)
          !! @p.shift.KeySet;
        for @p.map(*.Set(:view)) -> $set {
            $set{$_} || $keyset.delete_key($_) for $keyset.keys;
        }
        $keyset.Set(:view);
    }
}
# U+2229 INTERSECTION
only sub infix:<<"\x2229">>(|p) {
    infix:<(&)>(|p);
}

only sub infix:<(-)>(**@p) {
    return set() unless @p;

    if @p[0] ~~ Baggy {
        my $keybag = @p[0] ~~ KeyBag
          ?? KeyBag.new-fp(@p.shift.pairs)
          !! @p.shift.KeyBag;
        for @p.map(*.Bag(:view)) -> $bag {
            $bag{$_} < $keybag{$_}
              ?? $keybag{$_} -= $bag{$_}
              !! $keybag.delete_key($_)
              for $keybag.keys;
        }
        $keybag.Bag(:view);
    }
    else {
        my $keyset = @p[0] ~~ KeySet
          ?? KeySet.new(@p.shift.keys)
          !! @p.shift.KeySet;
        for @p.map(*.Set(:view)) -> $set {
            $set{$_} && $keyset.delete_key($_) for $keyset.keys;
        }
        $keyset.Set(:view);
    }
}
# U+2216 SET MINUS
only sub infix:<<"\x2216">>(|p) {
    infix:<(-)>(|p);
}

proto sub infix:<(^)>($, $ --> Setty) {*}
multi sub infix:<(^)>(Any $a, Any $b --> Setty) {
    $a.Set(:view) (^) $b.Set(:view);
}
multi sub infix:<(^)>(Set $a, Set $b --> Setty) {
    ($a (-) $b) (|) ($b (-) $a);
}
# U+2296 CIRCLED MINUS
only sub infix:<<"\x2296">>($a, $b --> Setty) {
    $a (^) $b;
}

# TODO: polymorphic eqv
# multi sub infix:<eqv>(Any $a, Any $b --> Bool) {
#     $a.Set(:view) eqv $b.Set(:view);
# }
# multi sub infix:<eqv>(Setty $a, Setty $b --> Bool) {
#     $a == $b and so $a.keys.all (elem) $b
# }

proto sub infix:<<(<=)>>($, $ --> Bool) {*}
multi sub infix:<<(<=)>>(Any $a, Any $b --> Bool) {
    $a.Set(:view) (<=) $b.Set(:view);
}
multi sub infix:<<(<=)>>(Setty $a, Setty $b --> Bool) {
    $a <= $b and so $a.keys.all (elem) $b
}
# U+2286 SUBSET OF OR EQUAL TO
only sub infix:<<"\x2286">>($a, $b --> Bool) {
    $a (<=) $b;
}
# U+2288 NEITHER A SUBSET OF NOR EQUAL TO
only sub infix:<<"\x2288">>($a, $b --> Bool) {
    $a !(<=) $b;
}

proto sub infix:<<(<)>>($, $ --> Bool) {*}
multi sub infix:<<(<)>>(Any $a, Any $b --> Bool) {
    $a.Set(:view) (<) $b.Set(:view);
}
multi sub infix:<<(<)>>(Setty $a, Setty $b --> Bool) {
    $a < $b and so $a.keys.all (elem) $b;
}
# U+2282 SUBSET OF
only sub infix:<<"\x2282">>($a, $b --> Bool) {
    $a (<) $b;
}
# U+2284 NOT A SUBSET OF
only sub infix:<<"\x2284">>($a, $b --> Bool) {
    $a !(<) $b;
}

proto sub infix:<<(>=)>>($, $ --> Bool) {*}
multi sub infix:<<(>=)>>(Any $a, Any $b --> Bool) {
    $a.Set(:view) (>=) $b.Set(:view);
}
multi sub infix:<<(>=)>>(Setty $a, Setty $b --> Bool) {
    $a >= $b and so $b.keys.all (elem) $a;
}
# U+2287 SUPERSET OF OR EQUAL TO
only sub infix:<<"\x2287">>($a, $b --> Bool) {
    $a (>=) $b;
}
# U+2289 NEITHER A SUPERSET OF NOR EQUAL TO
only sub infix:<<"\x2289">>($a, $b --> Bool) {
    $a !(>=) $b;
}

proto sub infix:<<(>)>>($, $ --> Bool) {*}
multi sub infix:<<(>)>>(Any $a, Any $b --> Bool) {
    $a.Set(:view) (>) $b.Set(:view);
}
multi sub infix:<<(>)>>(Setty $a, Setty $b --> Bool) {
    $a > $b and so $b.keys.all (elem) $a;
}
# U+2283 SUPERSET OF
only sub infix:<<"\x2283">>($a, $b --> Bool) {
    $a (>) $b;
}
# U+2285 NOT A SUPERSET OF
only sub infix:<<"\x2285">>($a, $b --> Bool) {
    $a !(>) $b;
}
