my class KeyBag does Baggy {

    method at_key($k) {
        Proxy.new(
          FETCH => {
              my $key   := $k.WHICH;
              my $elems := nqp::getattr(self, KeyBag, '%!elems');
              $elems.exists_key($key) ?? $elems{$key}.value !! 0;
          },
          STORE => -> $, $value {
              if $value > 0 {
                  (nqp::getattr(self, KeyBag, '%!elems'){$k.WHICH}
                    //= ($k => 0)).value = $value;
              }
              elsif $value == 0 {
                  self.delete_key($k);
              }
              else {
                  fail "Cannot put negative value $value for $k in {self.^name}";
              }
              $value;
          }
        );
    }

    method delete($k) {  # is DEPRECATED doesn't work in settings
        once DEPRECATED("Method 'KeyBag.delete'","the :delete adverb");
        self.delete_key($k);
    }
    method delete_key($k) {
        my $key   := $k.WHICH;
        my $elems := nqp::getattr(self, KeyBag, '%!elems');
        if $elems.exists_key($key) {
            my $value = $elems{$key}.value;
            $elems.delete_key($key);
            $value;
        }
        else {
            0;
        }
    }

    method Bag (:$view) {
        if $view {
            my $bag := nqp::create(Bag);
            $bag.BUILD( :elems(nqp::getattr(self, KeyBag, '%!elems')) );
            $bag;
        }
        else {
            Bag.new-fp(nqp::getattr(self, KeyBag, '%!elems').values);
        }
    }           
    method KeyBag { self }
}
