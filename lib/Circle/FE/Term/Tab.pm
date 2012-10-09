#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2012 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Tab;

use strict;
use warnings;

use base qw( Tickit::Widget::Tabbed::Tab );

use File::ShareDir qw( dist_file );

use Module::Pluggable search_path => "Circle::FE::Term::Widget",
                      sub_name => "widgets",
                      require => 1,
                      inner => 0;

use Tickit::Widget::Static;

sub new
{
   my $class = shift;
   my ( $tabbed, %args ) = @_;

   my $object = delete $args{object};
   my $self;

   if( $object->proxy_isa( "Circle::RootObj" ) ) {
      $args{label} = "Global";
   }
   else {
      $args{label} = $object->prop( "tag" );
      $object->watch_property(
         property => "tag",
         on_set => sub {
            my ( $newtag ) = @_;
            $self->set_label_text( $newtag );
         },
      );
   }

   $self = $class->SUPER::new( $tabbed, %args );
   $self->{object} = $object;

   $object->call_method(
      method => "get_widget",
      args => [],
      on_result => sub {
         $self->widget->add( $self->build_widget( $_[0] ), expand => 1 );
      }
   );

   $object->watch_property(
      property => "level",
      on_set => sub {
         my ( $level ) = @_;
         $self->set_level( $level );
      },
      want_initial => 1,
   );

   # TODO: weasel
   $self->set_on_activated( sub { $self->activated } );

   return $self;
}

sub build_widget
{
   my $self = shift;
   my ( $obj ) = @_;

   foreach my $type ( widgets ) {
      next unless $obj->proxy_isa( "Circle::Widget::" . $type->type );
      return $type->build( $obj, $self );
   }

   die "Cannot build widget for $obj as I don't recognise its type - " . join( ", ", $obj->proxy_isa ) . "\n";
}

sub level
{
   my $self = shift;
   return $self->{object}->prop( "level" );
}

sub set_level
{
   my $self = shift;
   my ( $level ) = @_;

   $self->pen->chattr( fg => $self->get_theme_colour( "level$level" ) );
}

sub set_label_text
{
   my $self = shift;
   my ( $text ) = @_;

   $self->{label} = $text;

   return unless my $tab = $self->{tab};
   $tab->set_label( $text );
}

sub label
{
   my $self = shift;
   return $self->{label};
}

sub label_short
{
   my $self = shift;
   my $label = $self->label;
   $label =~ s/([a-z0-9])([a-z0-9]+)/$1/gi;
   return $label;
}

sub activated
{
   my $self = shift;

   my $object = $self->{object};

   if( $object->prop("level") > 0 ) {
      $object->call_method(
         method => "reset_level",
         args   => [],
         on_result => sub {}, # ignore
      );
   }
}

# Now read the theme
my %theme_vars;

{
   my $theme_filename;

   foreach ( $ENV{CIRCLE_FE_TERM_THEME},
             "$ENV{HOME}/.circle-fe-term.theme",
             dist_file( "circle-fe-term", "circle-fe-term.theme" ) ) {
      defined $_ or next;
      -e $_ or next;

      $theme_filename = $_;
      last;
   }

   defined $theme_filename or die "Cannot find a circle-fe-term.theme";

   open( my $themefh, "<", $theme_filename ) or die "Cannot read $theme_filename - $!";

   while( <$themefh> ) {
      m/^\s*#/ and next; # skip comments
      m/^\s*$/ and next; # skip blanks

      m/^(\S*)=(.*)$/ and $theme_vars{$1} = $2, next;
      print STDERR "Unrecognised theme line: $_";
   }
}

sub get_theme_var
{
   my $class = shift;
   my ( $varname ) = @_;
   return $theme_vars{$varname} if exists $theme_vars{$varname};
   print STDERR "No such theme variable $varname\n";
   return undef;
}

sub translate_theme_colour
{
   my $class = shift;
   my ( $colourname ) = @_;

   return $colourname if $colourname =~ m/^#/; # Literal #rrggbb
   return $theme_vars{$colourname} if exists $theme_vars{$colourname}; # hope
   print STDERR "No such theme colour $colourname\n";
   return undef;
}

sub get_theme_colour
{
   my $class = shift;
   my ( $varname ) = @_;
   return $theme_vars{$varname} if exists $theme_vars{$varname};
   print STDERR "No such theme variable $varname for a colour\n";
   return undef;
}

0x55AA;
