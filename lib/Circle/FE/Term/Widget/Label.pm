#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2011-2013 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Widget::Label;

use strict;
use warnings;

use constant type => "Label";

use Tickit::Widget::Static;

sub build
{
   my $class = shift;
   my ( $obj, $tab ) = @_;

   my $widget = Tickit::Widget::Static->new(
      classes => $obj->prop( "classes" ),
      text => "",
   );

   $obj->watch_property(
      property => "text",
      on_set   => sub { $widget->set_text( $_[0] ) },
      want_initial => 1,
   );

   return $widget;
}

Tickit::Style->load_style( <<'EOF' );
Static.ident {
  bg: "blue";
}

EOF

0x55AA;
