require 'csv' unless defined?CSV

module Job
  #
  # Booking export reservation job
  #
  class BookingExportReservationJob
   
    def initialize(folder,
                   file_name, 
                   content_type,
                   created_from,
                   created_to,
    	             sales_channel_code=nil, 
    	             notify_by_email_on_finish=false, notification_email=nil)
      @folder = folder 
      @file_name = file_name
      @file_path = File.join(@folder, @file_name)
      @created_from = created_from
      @created_to = created_to
      @content_type = content_type
      @sales_channel_code = sales_channel_code
      @notification_email = notification_email
      @notify_by_email_on_finish = notify_by_email_on_finish
    end

    #
    # Process : Create the CSV from user export
    #
    def perform

      p "Exporting reservations to #{@file_path}"
     
      FileUtils.mkdir_p(@folder)

      now = DateTime.now
      @export_file = ExternalIntegration::BackgroundExportFile.create(name: "Exportación reservas",
      	                                         description: "Exportación reservas",
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
          columns = ["received", "date_from", "time_from", "date_to", "time_to", "id", 
                     "customer", "phone", "email", "status", "products", "total"]
          columns << "sales_channel"
          csv << columns
          @reservations = reservations
          @export_file.update(status: :in_progress)
          @reservations.each do |reservation|
            products = reservation.booking_lines.inject([]) do |result, booking_line|
                         result << booking_line.item_id
                       end
            csv << [reservation.creation_date ? reservation.creation_date.strftime('%Y-%m-%d %H:%M:%S') : '', 
                    reservation.date_from ? reservation.date_from.strftime('%Y-%m-%d') : '',
                    reservation.time_from, 
                    reservation.date_to ? reservation.date_to.strftime('%Y-%m-%d') : '',
                    reservation.time_to,
                    reservation.id,
                    "#{reservation.customer_name} #{reservation.customer_surname}",
                    "#{reservation.customer_phone} #{reservation.customer_mobile_phone}",
                    reservation.customer_email,
                    BookingDataSystem.r18n.t.booking_status[reservation.status.to_s],
                    products.join(' '),
                    reservation.total_cost,
                    reservation.sales_channel_code
                  ]            
            processed += 1
            @export_file.update(number_of_records: processed)
          end   
        end
        @export_file.update(status: :done)
      rescue StandardError => msg
        @export_file.update(status: :error, error_message: msg)
      end 
      
    end

    private

    def reservations

          condition = Conditions::JoinComparison.new('$and',
                                                     [Conditions::Comparison.new(:status, '$ne', :cancelled),
                                                      #Conditions::JoinComparison.new('$or',
                                                      #   [Conditions::JoinComparison.new('$and',
                                                      #                                   [Conditions::Comparison.new(:date_from,'$lte', @date_from),
                                                      #                                    Conditions::Comparison.new(:date_to,'$gte', @date_from)
                                                      #                                   ]),
                                                      #    Conditions::JoinComparison.new('$and',
                                                      #                                   [Conditions::Comparison.new(:date_from,'$lte', @date_to),
                                                      #                                    Conditions::Comparison.new(:date_to,'$gte', @date_to)
                                                      #                                   ]),
                                                      #    Conditions::JoinComparison.new('$and',
                                                      #                                   [Conditions::Comparison.new(:date_from,'$lte', @date_from),
                                                      #                                    Conditions::Comparison.new(:date_to,'$gte', @date_to)
                                                      #                                   ]),
                                                      #    Conditions::JoinComparison.new('$and',
                                                      #                                   [Conditions::Comparison.new(:date_from, '$gte', @date_from),
                                                      #                                    Conditions::Comparison.new(:date_to, '$lte', @date_to)])
                                                      #   ]
                                                      #),
                                                      Conditions::JoinComparison.new('$and',
                                                                                         [Conditions::Comparison.new(:creation_date,'$gte', @created_from),
                                                                                          Conditions::Comparison.new(:creation_date,'$lte', @created_to)
                                                                                         ])
                                                     ]
          )

          @reservations = condition.build_datamapper(BookingDataSystem::Booking).all(:order => [:date_from, :time_from])


    end 

  end
end             