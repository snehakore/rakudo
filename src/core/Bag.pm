my class Bag does Baggy {
    has $!WHICH;

    submethod WHICH { $!WHICH }
    submethod BUILD (:%elems)  {
        my @keys := %elems.keys.sort;
        $!WHICH = self.^name
          ~ '|'
          ~ @keys.map( { $_ ~ '(' ~ %elems{$_}.value ~ ')' } );
        nqp::bindattr(self, Bag, '%!elems', %elems);
    }

    method at_key($k --> Int) {
        my $elems := nqp::getattr(self, Bag, '%!elems');
        my $key   := $k.WHICH;
        $elems.exists_key($key)
          ?? $elems{$key}.value
          !! 0;
    }

    method delete ($a --> Int) {  # is DEPRECATED doesn't work in settings
        once DEPRECATED("Method 'Bag.delete'","the :delete adverb");
        self.delete_key($a);
    }
    method delete_key($a --> Int) is hidden_from_backtrace {
        X::Immutable.new( method => 'delete', typename => self.^name ).throw;
    }

    method Bag { self }
    method KeyBag { KeyBag.new-fp(nqp::getattr(self, Bag, '%!elems').values) }
}
