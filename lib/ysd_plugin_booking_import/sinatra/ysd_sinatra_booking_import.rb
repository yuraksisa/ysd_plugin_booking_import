require 'csv' unless defined?CSV

module Sinatra
  module YitoExtension
    module BookingImport

      def self.registered(app)

        app.settings.views = Array(app.settings.views).push(
            File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..',
                                       'views')))
        app.settings.translations = Array(app.settings.translations).push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'i18n')))

        #
        # Booking import
        #
        app.get '/admin/booking/import', :allowed_usergroups => ['booking_manager', 'staff'] do

          booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

          load_page(:booking_import)

        end

        #
        # Import reservations 
        #
        app.post '/admin/booking/import/reservations', :allowed_usergroups => ['booking_manager', 'staff'] do

          if params[:reservations_file][:tempfile].nil?
            halt 500, 'Fichero no válido'
          end

          folder = background_file_folder(RequestStore.store[:media_server_name_folder], 'import')
          file_name = "reservations-#{DateTime.now.strftime('%Y%m%d%H%M%S')}.csv"

          # Make folder
          FileUtils.mkdir_p(folder)
      
          # Copy file
          FileUtils.copy(params[:reservations_file][:tempfile], File.join(folder, file_name))

          ::Delayed::Job.enqueue Job::BookingImportReservationJob.new(File.join(folder, file_name))          

          flash[:notice] = 'El proceso de importación se realizará en segundo plano. Compruebe <a href="/admin/integration/background-import-files">aquí</a>'
          redirect '/admin/booking/import'

        end

      end
    end
  end
end