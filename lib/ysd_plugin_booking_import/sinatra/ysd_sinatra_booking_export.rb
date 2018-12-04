require 'delayed_job' unless defined?Delayed::Job

module Sinatra
  module YitoExtension
    module BookingExport

      def self.registered(app)
      
        #
        # Export
        #
        app.get '/admin/booking/export', :allowed_usergroups => ['booking_manager', 'staff'] do

          booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
          
          # Get the sales channels
          addons = mybooking_addons
          @addon_sales_channels = (addons and addons.has_key?(:addon_sales_channels) and addons[:addon_sales_channels])
          if @addon_sales_channels
            @sales_channels = ::Yito::Model::SalesChannel::SalesChannel.all
          end

          load_page(:booking_export)

        end

        #
        # Export customers
        #
        app.post '/admin/booking/export/customers', :allowed_usergroups => ['booking_manager', 'staff'] do

          folder = background_file_folder(RequestStore.store[:media_server_name_folder], 'export')
          file_name = "customer-#{DateTime.now.strftime('%Y%m%d%H%M%S')}.csv"

          sales_channel = (params[:sales_channel] and !params[:sales_channel].empty?) ? params[:sales_channel] : nil
          ::Delayed::Job.enqueue Job::BookingExportCustomerJob.new(folder, file_name, 'text/csv',
                                                                   sales_channel)
          flash[:notice] = 'El proceso de exportación se realizará en segundo plano. Compruebe <a href="/admin/integration/background-export-files">aquí</a>' 
          redirect '/admin/booking/export'
 
        end 

      end

    end
  end
end       	