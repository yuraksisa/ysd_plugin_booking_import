require 'ysd-plugins' unless defined?Plugins::Plugin

Plugins::SinatraAppPlugin.register :booking_import do

   name=        'booking_import'
   author=      'yurak sisa'
   description= 'Booking import'
   version=     '0.1'
   hooker       YsdPluginBookingImport::BookingImportExtension
   sinatra_extension Sinatra::YitoExtension::BookingImport
   sinatra_extension Sinatra::YitoExtension::BookingExport
  
end   