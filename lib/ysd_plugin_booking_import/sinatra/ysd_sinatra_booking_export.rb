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

          load_page(:booking_export)

        end

        #
        # Export customers
        #
        app.post '/admin/booking/export/customers', :allowed_usergroups => ['booking_manager', 'staff'] do

          root_path = SystemConfiguration::Variable.get_value('data.folder_root','')

          do_apply_server_name_folder = SystemConfiguration::Variable.get_value('data.use_server_name_folder','false').to_bool
          file_name = "customers-#{DateTime.now.strftime('%Y%m%d%H%M%S')}.csv"
          p "path: #{root_path} #{File.expand_path($0)} -- #{File.expand_path($0).gsub($0,'')} -- #{$0}"
          folder = if do_apply_server_name_folder
		             File.join(root_path.empty? ? File.expand_path($0).gsub($0,'') : root_path, 
		                       'data', 
		          	           'export',
		          	           RequestStore.store[:media_server_name_folder])  
		           else
		             File.join(root_path.empty? ? File.expand_path($0).gsub($0,'') : root_path, 
		          	           'data', 
		          	           'export')  
		           end

          ::Delayed::Job.enqueue Job::BookingExportCustomerJob.new(folder, file_name, 'text/csv')

          flash[:notice] = 'El proceso de exportación se realizará en segundo plano. Compruebe <a href="/admin/integration/background-export-files">aquí</a>' 
          redirect '/admin/booking/export'
 
        end 

      end

    end
  end
end       	