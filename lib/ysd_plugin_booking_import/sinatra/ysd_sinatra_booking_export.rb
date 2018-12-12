require 'delayed_job' unless defined?Delayed::Job

module Sinatra
  module YitoExtension
    module BookingExport

      def self.registered(app)
      
        #
        # Export
        #
        app.get '/admin/booking/export/customers', :allowed_usergroups => ['booking_manager', 'staff'] do

          booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
          
          # Get the sales channels
          addons = mybooking_addons
          @addon_sales_channels = (addons and addons.has_key?(:addon_sales_channels) and addons[:addon_sales_channels])
          if @addon_sales_channels
            @sales_channels = ::Yito::Model::SalesChannel::SalesChannel.all
          end

          load_page(:booking_export_customers)

        end

        #
        # Export customers
        #
        app.post '/admin/booking/export/customers', :allowed_usergroups => ['booking_manager', 'staff'] do

          folder = background_file_folder(RequestStore.store[:media_server_name_folder], 'export')
          file_name = "customer-#{DateTime.now.strftime('%Y%m%d%H%M%S')}.csv"

          year = Date.today.year

          created_from = Date.civil(year, 1, 1)
          created_to = Date.civil(year, 12, 31)

          if params[:created_from]
            begin
              created_from = DateTime.strptime(params[:created_from], '%Y-%m-%d')
            rescue
              logger.error("reservation created from date not valid #{params[:created_from]}")
            end
          end

          if params[:created_to]
            begin
              created_to = DateTime.strptime(params[:created_to], '%Y-%m-%d')
            rescue
              logger.error("reservation created to date not valid #{params[:created_to]}")
            end
          end

          sales_channel = (params[:sales_channel] and !params[:sales_channel].empty?) ? params[:sales_channel] : nil
          ::Delayed::Job.enqueue Job::BookingExportCustomerJob.new(folder, file_name, 'text/csv',
                                                                   created_from, created_to, sales_channel)
          flash[:notice] = 'El proceso de exportación se realizará en segundo plano. Compruebe <a href="/admin/integration/background-export-files">aquí</a>' 
          redirect '/admin/booking/export/customers'
 
        end 

        #
        # Export
        #
        app.get '/admin/booking/export/reservations', :allowed_usergroups => ['booking_manager', 'staff'] do

          booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
          
          # Get the sales channels
          addons = mybooking_addons
          @addon_sales_channels = (addons and addons.has_key?(:addon_sales_channels) and addons[:addon_sales_channels])
          if @addon_sales_channels
            @sales_channels = ::Yito::Model::SalesChannel::SalesChannel.all
          end

          load_page(:booking_export_reservations)

        end

        #
        # Export reservations
        #
        app.post '/admin/booking/export/reservations', :allowed_usergroups => ['booking_manager', 'staff'] do

          folder = background_file_folder(RequestStore.store[:media_server_name_folder], 'export')
          file_name = "reservation-summary-#{DateTime.now.strftime('%Y%m%d%H%M%S')}.csv"

          year = Date.today.year

          created_from = Date.civil(year, 1, 1)
          created_to = Date.civil(year, 12, 31)

          if params[:created_from]
            begin
              created_from = DateTime.strptime(params[:created_from], '%Y-%m-%d')
            rescue
              logger.error("reservation created from date not valid #{params[:created_from]}")
            end
          end

          if params[:created_to]
            begin
              created_to = DateTime.strptime(params[:created_to], '%Y-%m-%d')
            rescue
              logger.error("reservation created to date not valid #{params[:created_to]}")
            end
          end

          sales_channel = (params[:sales_channel] and !params[:sales_channel].empty?) ? params[:sales_channel] : nil

          ::Delayed::Job.enqueue Job::BookingExportReservationJob.new(folder, file_name, 'text/csv',
                                                                      created_from, created_to, sales_channel)
          flash[:notice] = 'El proceso de exportación se realizará en segundo plano. Compruebe <a href="/admin/integration/background-export-files">aquí</a>' 
          redirect '/admin/booking/export/reservations'
 
        end 

      end

    end
  end
end       	