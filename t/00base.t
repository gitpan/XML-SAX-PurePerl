use Test;
BEGIN { plan tests => 2 }
END { ok($loaded) }
use XML::SAX::PurePerl;
$loaded++;
ok(1);
