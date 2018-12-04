module Sinatra
  module YitoExtension
    module BookingImportHelper
    	def background_file_folder(name_suffix, final_folder)
          root_path = SystemConfiguration::Variable.get_value('data.folder_root','')
          do_apply_server_name_folder = SystemConfiguration::Variable.get_value('data.use_server_name_folder','false').to_bool
          folder = if do_apply_server_name_folder
		             File.join(root_path.empty? ? File.expand_path($0).gsub($0,'') : root_path, 
		                       'data', 
		          	           final_folder,
		          	           name_suffix)  
		           else
		             File.join(root_path.empty? ? File.expand_path($0).gsub($0,'') : root_path, 
		          	           'data', 
		          	           final_folder)  
		           end
		end           
	end
  end
end  		