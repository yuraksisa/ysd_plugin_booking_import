require 'csv' unless defined?CSV

module Job
  class BookingImportReservationJob

    attr_reader :file
    attr_reader :file_name

    def initialize(file_name,
    	             notify_by_email_on_finish=false, notification_email=nil)
      @file_name = file_name
      @file = file
    end	

    #
    # Import CSV
    #
    def perform

      p "Importing reservations"
      now = DateTime.now
  	  @import_file = ExternalIntegration::BackgroundImportFile.create(name: "Importación reservas",
    	                                         description: "Importación reservas",
    	                                         notification_email: @notification_email,
    	                                         notify_by_email_on_finish: @notify_by_email_on_finish,
    	                                         created_at: now,
    	                                         file_path: file_name,
    	                                         status: :pending,
    	                                         number_of_records: 0,
    	                                         number_of_imported_records: 0,
    	                                         number_of_errors: 0)

      processed = 0
      imported_records = 0
      errors = 0
      @import_error = {}
      booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
      begin
          CSV.foreach(file_name, col_sep: ';', headers: true) do |row|
            processed += 1
  	        @import_file.update(number_of_records: processed)      	
              booking = if row['id'] and !row['id'].nil? and !row['id'].empty?
              	        BookingDataSystem::Booking.get(row['id'])
              	      else
              	        nil
              	      end      
            
            if booking.nil?
              booking = BookingDataSystem::Booking.new
              booking.id = row['id'] if row['id'] and !row['id'].nil? and !row['id'].empty? 
              # Pickup / return date
              booking.date_from = row['date_from']
              if booking_item_family.time_to_from
                if BookingDataSystem::Booking.valid_time?(row['time_from'])
                  booking.time_from = row['time_from']
                else
	              errors += 1
	              @import_file.update(number_of_errors: errors)                	
                  @import_error.store($., {data: row.inspect, error: ['Hora de inicio no es válida']})
                  next
                end
              else
                booking.time_from = booking_item_family.time_start
              end
              if booking_item_family.pickup_return_place
                booking.pickup_place = row['pickup_place']
              end
              booking.date_to = row['date_to']
              if booking_item_family.time_to_from
                if BookingDataSystem::Booking.valid_time?(row['time_to'])
                  booking.time_to = row['time_to']
                else
	              errors += 1
	              @import_file.update(number_of_errors: errors)                  	
                  @import_error.store($., {data: row.inspect, error: ['Hora de fin no es válida']})
                  next
                end
              else
                booking.time_to = booking_item_family.time_end
              end
              if booking_item_family.pickup_return_place
                booking.return_place = row['return_place'] 
              end
              booking.comments = row['comments']
              # Sales channel
              booking.sales_channel_code = row['sales_channel_code'] if row.has_key?('sales_channel_code') and !row['sales_channel_code'].nil? and !row['sales_channel_code'].empty?
              # Rental location
              booking.rental_location_code = row['rental_location_code'] if row.has_key?('rental_location_code') and !row['rental_location_code'].nil? and !row['rental_location_code'].empty?
              # Customer
              booking.customer_name = row['customer_name']
              booking.customer_surname = row['customer_surname']
              booking.customer_email = row['customer_email']
              booking.customer_phone = row['customer_phone']
              booking.customer_mobile_phone = row['customer_mobil_phone']
              booking.customer_language = row['customer_language']
              # Address (contact or driver)
              booking.driver_address = LocationDataSystem::Address.new
              booking.driver_address.street = row['street'] if row.has_key?('street')
              booking.driver_address.number = row['number'] if row.has_key?('number')
              booking.driver_address.complement = row['complement'] if row.has_key?('complement')
              booking.driver_address.city = row['city'] if row.has_key?('city')
              booking.driver_address.state = row['state'] if row.has_key?('state')
              booking.driver_address.country = row['country'] if row.has_key?('country')
              booking.driver_address.zip = row['zip'] if row.has_key?('zip')
              # Driver
              if booking_item_family.driver_date_of_birth
                booking.driver_name = row['driver_name']
                booking.driver_surname = row['driver_surname']
                booking.driver_document_id = row['driver_document_id']
                booking.driver_driving_license_number = row['driver_driving_license_number']
                booking.driver_date_of_birth = row['driver_date_of_birth']
                booking.driver_age = BookingDataSystem::Booking.completed_years(booking.date_from, booking.driver_date_of_birth) unless booking.date_from.nil? or booking.driver_date_of_birth.nil?
                booking.driver_driving_license_date = row['driver_driving_license_date']
                booking.driver_driving_license_years = BookingDataSystem::Booking.completed_years(booking.date_from, booking.driver_driving_license_date) unless booking.date_from.nil? or booking.driver_driving_license_date.nil?
                booking.driver_driving_license_country = row['driver_driving_license_country']
              end
              unless booking.valid?
	            errors += 1
	            @import_file.update(number_of_errors: errors)                	
                @import_error.store($., {data: booking, error: booking.errors.full_messages})
                next
              end

              booking.item_cost = 0
              booking.extras_cost = 0
              # Products
              if row.has_key?('item_id') and !row['item_id'].nil? and !row['item_id'].empty?
                if ::Yito::Model::Booking::BookingCategory.get(row['item_id'])
                  booking_line = BookingDataSystem::BookingLine.new
                  booking_line.item_id = row['item_id']
                  booking_line.item_description = row['item_description']
                  booking_line.item_unit_cost = row['item_unit_cost']
                  booking_line.item_unit_cost_base = booking_line.item_unit_cost
                  booking_line.quantity = row['quantity'] || 1
                  booking_line.item_cost = booking_line.item_unit_cost * booking_line.quantity
                  booking_line.booking = booking

                  (0..booking_line.quantity-1).each do |blr|
                    booking_line_resource = BookingDataSystem::BookingLineResource.new
                    booking_line.booking_line_resources << booking_line_resource
                  end  

                  unless booking_line.valid?
	                errors += 1
	                @import_file.update(number_of_errors: errors)                    	
                    @import_error.store($., {data: booking_line, error: booking_line.errors.full_messages})
                    next
                  end
                  booking.booking_lines << booking_line
                  booking.item_cost += booking_line.item_cost
                else
	              errors += 1
	              @import_file.update(number_of_errors: errors)                  	
                  @import_error.store($., {data: booking, error: ['El producto no existe']})
                  next
                end
              else
	            errors += 1
	            @import_file.update(number_of_errors: errors)                	
                @import_error.store($., {data: booking, error: ['No ha especificado el producto']})
                next
              end
              # Extras
              if row.has_key?('extra_1_id') and !row['extra_1_id'].nil? and !row['extra_1_id'].empty?
                booking_extra = BookingDataSystem::BookingExtra.new
                booking_extra.extra_id = row['extra_1_id']
                booking_extra.extra_description = row['extra_1_description']
                booking_extra.extra_unit_cost = row['extra_1_unit_cost']
                booking_extra.quantity = row['extra_1_quantity']
                booking_extra.extra_cost = booking_extra.extra_unit_cost * booking_extra.quantity
                booking_extra.booking = booking
                unless booking_extra.valid?
                  errors += 1
	              @import_file.update(number_of_errors: errors)  
                  @import_error.store($., {data: booking_extra, error: booking_extra.errors.full_messages})
                  next
                end
                booking.booking_extras << booking_extra
                booking.extras_cost += booking_extra.extra_cost
              end
              if row.has_key?('extra_2_id') and !row['extra_2_id'].nil? and !row['extra_2_id'].empty?
                booking_extra = BookingDataSystem::BookingExtra.new
                booking_extra.extra_id = row['extra_2_id']
                booking_extra.extra_description = row['extra_2_description']
                booking_extra.extra_unit_cost = row['extra_2_unit_cost']
                booking_extra.quantity = row['extra_2_quantity']
                booking_extra.extra_cost = booking_extra.extra_unit_cost * booking_extra.quantity
                booking_extra.booking = booking
                unless booking_extra.valid?
	              errors += 1
	              @import_file.update(number_of_errors: errors)                  	
                  @import_error.store($., {data: booking_extra, error: booking_extra.errors.full_messages})
                  next
                end                
                booking.booking_extras << booking_extra
                booking.extras_cost += booking_extra.extra_cost
              end
              if row.has_key?('extra_3_id') and !row['extra_3_id'].nil? and !row['extra_3_id'].empty?
                booking_extra = BookingDataSystem::BookingExtra.new
                booking_extra.extra_id = row['extra_3_id']
                booking_extra.extra_description = row['extra_3_description']
                booking_extra.extra_unit_cost = row['extra_3_unit_cost']
                booking_extra.quantity = row['extra_3_quantity']
                booking_extra.extra_cost = booking_extra.extra_unit_cost * booking_extra.quantity
                booking_extra.booking = booking
                unless booking_extra.valid?
	              errors += 1
	              @import_file.update(number_of_errors: errors)                  	
                  @import_error.store($., {data: booking_extra, error: booking_extra.errors.full_messages})
                  next
                end                
                booking.booking_extras << booking_extra
                booking.extras_cost += booking_extra.extra_cost
              end
              booking.calculate_cost(false, false)

              booking.transaction do
                begin
                  # Save the booking
                  booking.save
                  # Create the charge and updates the booking
                  if row.has_key?('amount') and !row['amount'].nil? and !row['amount'].empty?
                    charge = Payments::Charge.new
                    charge.date = row['data_of_payment']
                    charge.currency = 'EUR'
                    charge.status = :done
                    charge.amount = row['amount']
                    charge.payment_method_id = row['payment_method']
                    unless charge.valid?
	                  errors += 1
	                  @import_file.update(number_of_errors: errors)                      	
                      @import_error.store($., {data: charge, error: charge.errors.full_messages})
                      next
                    end
                    booking_charge = BookingDataSystem::BookingCharge.new
                    booking_charge.booking = booking
                    booking_charge.charge = charge
                    booking_charge.save
                    # Booking status
                    today = Date.today
                    if booking.date_from < today
                      if booking.date_to < today
                        booking.status = :done
                      else
                        booking.status = :in_progress
                      end
                    else
                      booking.status = :confirmed
                    end
                    # Booking payment and payment status
                    booking.total_paid = charge.amount
                    booking.total_pending = booking.total_cost - booking.total_paid
                    if booking.total_pending > 0
                      booking.payment_status = :deposit
                    else
                      booking.payment_status = :total
                    end
                    booking.save
                  end
	              imported_records += 1
	              @import_file.update(number_of_imported_records: imported_records)
                rescue DataMapper::SaveFailureError => error
                  p "Error saving booking: #{error.resource.errors.full_messages.inspect}"
	              errors += 1
	              @import_file.update(number_of_errors: errors)                    
                  @import_error.store($., {data: booking, error: error.resource.errors.full_messages})
                end
              end
            else
	          errors += 1
	          @import_file.update(number_of_errors: errors)              	
              @import_error.store($., {data: row.inspect, error: "Reservation #{row['id']} exists"}) 
            end
          end

          unless @import_error.empty?
            @import_file.update(error_message: @import_error.to_json)
          end

          @import_file.update(status: :done)	

      rescue StandardError => msg
        @import_file.update(status: :error, error_message: msg)
      end	

    end	
  end
end  	  	