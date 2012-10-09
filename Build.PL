use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
   module_name => 'Circle::FE::Term',
   dist_name   => 'circle-fe-term',
   requires => {
      'Convert::Color' => '0.06',
      'Convert::Color::XTerm' => 0,
      'IO::Async' => '0.14',
      'Net::Async::Tangence::Client' => '0.08',
      'String::Tagged' => 0,
      'Text::Balanced' => 0,
      'Tickit::Async' => 0,
      'Tickit::Widget::Entry' => 0,
      'Tickit::Widget::HBox' => 0,
      'Tickit::Widget::Scroller' => '0.04',
      'Tickit::Widget::Tabbed' => '0.005',
      'Tickit::Widget::VBox' => 0,
   },
   auto_configure_requires => 0, # Don't add M::B to configure_requires
   share_dir => {
      dist => "share",
   },
   license => 'gpl',
   create_makefile_pl => 'traditional',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
