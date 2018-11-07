require 'csv' unless defined?CSV

module Job
  class BookingExportCustomerJob
   
    def initialize(folder,
                   file_name, 
                   content_type,
    	           sales_channel_code=nil, 
    	           notify_by_email_on_finish=false, notification_email=nil)
      @folder = folder 
      @file_name = file_name
      @file_path = File.join(@folder, @file_name)
      @content_type = content_type
      @sales_channel_code = sales_channel_code
      @notification_email = notification_email
      @notify_by_email_on_finish = notify_by_email_on_finish
    end

    #
    # Process : Create the CSV from user export
    #
    def perform

      p "Exporting customers to #{@file_path}"
     
      FileUtils.mkdir_p(@folder)

      now = DateTime.now
      @customers = BookingDataSystem::Booking.customers(@sales_channel_code)
      @export_file = ExternalIntegration::BackgroundExportFile.create(name: "Exportación clientes",
      	                                         description: "Exportación clientes",
      	                                         notification_email: @notification_email,
      	                                         notify_by_email_on_finish: @notify_by_email_on_finish,
      	                                         created_at: now,
      	                                         valid_until: now + 1,
      	                                         file_name: @file_name,
      	                                         file_path: @file_path,
      	                                         url_path: "/admin/integration/export/#{@file_name}",
      	                                         content_type: @content_type,
      	                                         status: :pending)
  
      processed = 0

      begin
	      CSV.open(@file_path, "wb") do |csv|
	      	csv << ["name", "surname", "email", "phone"]
	      	@export_file.update(status: :in_progress)
	        @customers.each do |customer|
	        	csv << [customer.customer_name, customer.customer_surname, 
	        		    customer.customer_email, customer.customer_phone]
	        	processed += 1
	        	@export_file.update(number_of_records: processed)
	        end 	
	      end
	      @export_file.update(status: :done)
      rescue StandardError => msg
        @export_file.update(status: :error, error_message: msg)
      end	
      
    end

  end
end  	