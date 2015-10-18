#require 'rubygems'
require 'optparse'
require 'csv'
require 'Indirizzo'
#require 'logger'

# -- parse_church_data.rb <filename.csv>--
#
# Purpose:
#  Read in St. Paul family/elder/address data
#  provided by church secretary and generate
#  CSV ready to import into Google Maps for map creation
#
# Data is provided as 3 fundamental columns of data
#  step 1: - put everything into a single column
#  step 2: - transpose data to every 4th
#
#  Outputs CSV to display, capture to file if desired

def define_csv_format(options={})
  
  ###############################
  # QUALITIES OF INPUT CSV FILE
  
  # indicate which columns contain valid data
  # leftmost column is 0
  @data_columns = [0,4,8]
 
  # number of lines per group in input file
  @num_lines_per_linegroup = 5
  
  # indicate what values per row
  # should be 0 to @num_lines_per_linegroup-1
  @input_data_rows = {0 => :name,
                      1 => :elder,
                      2 => :address,
                      3 => :city_state_zip,       # occasionally this is more of the address
                      4 => :extra,                # occasionally this is the city/state/zip! 
  }
  
  # Output data fields
  # Used as data for Google Maps,
  # and used to access data itself via keys
  @output_fields = {:name => "Name",                             # key matches @input_data_rows
                    :elder => "Elder",                           # key matches @input_data_rows
                    :address => "Address",                       # key matches @input_data_rows
                    :city_state_zip => "City_State_Zip",         # key matches @input_data_rows
                    :city => "City",
                    :state => "State",
                    :zip => "Zip",
                    }
  
  # Hash here used to give warning if someone is assigned to wrong elder!
  # also should match data input -- eventually want this to come from external file?
  @elders = ["Daniel Hadad",
             "Mark De Young",
             "Ernie Johnson",
             "Joshua Konkle",
             "Charles Whitsel",
             "Ethan Cruz",
             "Ross Davis",
             "Don Hilsberg",
             "Paul Hunt",
             "Gary Jordan",
             "Tim Horn",
             "Kelly Holligan",
             "Steve Hutton",
             "John Ritchie",
             ]
  
  # extra list of names to help find elders themselves in the database (need to use hash above instead...)
  # or break down the name to remove spouse name
  @elders2 = ["Dan Hadad",
              ]
  
  # if needing to sub elder in the data
  # format:   old_elder => new_elder
  @elder_sub = {
                }
  
  ###############################
  
end

#
# Simple print of @final_data for debug
#
def print_data(options={})
  # print data by :
  #  :record (default), record, showing each field
  options={:by => :record,
          }.merge(options)
  
  case options[:by]
  when :record
    @final_data.each do |record|
      record.each do |field, value|
        if !field.nil? and !value.nil?
          puts "    #{field}: #{value}" if !field.nil?
        end
      end
      puts "****************************"
    end
  when :zip_code

    # gather all zip codes and count members in each
    all_zips = {}
    @final_data.each do |record|
      unless record[:zip].nil?
        if !all_zips.has_key?(record[:zip])
          # new zip code found
          all_zips[record[:zip]] = 1
        else
          # increment number for previous zip code
          all_zips[record[:zip]] = all_zips[record[:zip]] + 1
        end
      end
    end

    # output data
    puts CSV.generate_line(Array["Zipcode","Count"])
    all_zips.keys.sort.each do |zip|
      count = all_zips[zip]
     # puts " #{zip}  #{count}\n"
      puts CSV.generate_line(Array[zip,count])
    end
 
  else
    fail "ERROR in print_datoa"
  end
  
end

#
# prints final data in google map input format
# to console, grab to file if you like
#
# google.com/mymaps
#
def print_google_map_data(options={})
  options={ header: false,
          }.merge(options)
  
  puts CSV.generate_line(@output_fields.values) if options[:header]
  
  
  @final_data.each do |record|
    if @command_options[:elders_only]
      # remove spouse name if possible to make elder easier to find..
      name = record[:name].gsub(/& \w+ /, "")
      # check against 2 lists of elders in case names don't match
      if !@elders.include?(name) and !@elders2.include?(name)
        next
      end
    end
    if record[:name].nil?
      next
    end
    
    record_values=[]
    @output_fields.each_key do |field|
      record_values.push(record[field])
    end
    line = CSV.generate_line(record_values)
    
    # print line to output
    puts line
  end
end

#
# Read data from input CSV file
#
def read_data(options={})
  orig_data = CSV.read(@filename, :skip_blanks => true)
  num_lines = orig_data.length
  if num_lines % @num_lines_per_linegroup == 0
    num_line_groups = num_lines / @num_lines_per_linegroup
  else
    raise "ERROR: Invalid number of lines in file!"
  end
  
#  puts "Num Lines: #{num_lines}"
#  puts "************************\n"
  
  # array for final data
  @final_data = []
  
  # go through each line group
  num_line_groups.times do |i|
    
    # init a temp hash
    temp_hashes = []
    @data_columns.each do |col|
      temp_hashes[col] = {}
    end
    
    # grab data per linegroup
    @num_lines_per_linegroup.times do |j|
      line = orig_data[i*@num_lines_per_linegroup + j]
      field_name = @input_data_rows[j]
      # parse columns within a line
      @data_columns.each do |col|
        data = line[col]
        temp_hashes[col][field_name] = data
       # puts "  #{line[col]}" if !line[col].nil?
      end
    end
    
    # push grabbed data onto master hash array
    temp_hashes.each do |record|
      if !record.nil?
        @final_data << record
      end
    end
    
  end  # per line groups
  
end

#
# clean up data from any issues
#
def clean_data(options={})
  
  @final_data.each_index do |i|
    record = @final_data[i]
    if record[:name].nil?   # remove no-name records
      @final_data.delete_at(i)
      next
    end
    if record[:address].nil? # remove no-address records, can't display!
      @last_log << "WARNING: Address Missing for #{record[:name]}!\n"
      @final_data.delete_at(i)
      next
    end
    if record[:elder].nil?
      @last_log << "WARNING: Elder Missing for #{record[:name]}!\n"
    end
    if !record[:extra].nil? # if extra data, then assume it is city/state/zip,
                            # merge :address and existing :city_state_zip,
                            # put :extra data into :city_state_zip
      
      # fix data
      @final_data[i][:address] = "#{record[:address]}, #{record[:city_state_zip]}"
      @final_data[i][:city_state_zip] = "#{record[:extra]}"
      @final_data[i][:extra] = nil
      
    end
    if record[:address] =~ /Apt/ and record[:address] !=~ /,/
      # insert comma for Apt to make it easier on google
      @final_data[i][:address] = "#{record[:address].gsub(/ Apt/, ", Apt")}"
#      @last_log << "NOTE: Funny address found for #{record[:name]}!\n"
#      @last_log << "       Address: #{record[:address]}!\n"
    end
    if !@elders.include?(record[:elder])  # if No elder found, then report
      @last_log << "WARNING: No Elder found for #{record[:name]}!\n"
      if record[:address] !=~ /\w*\s\w*/ and record[:extra].nil?
        # if this is the case, very likely this is the address
        # shift data by 1 record
        @final_data[i][:city_state_zip] = record[:address]
        @final_data[i][:address] = record[:elder]
        @final_data[i][:elder] = "No Elder"
      end
    end
    
    # finally filter for problematic addresses that don't seem to picked up by Google Maps Geocoding properly!
    if record[:address] =~ /FM 2222/
      @final_data[i][:address] = "#{record[:address].gsub(/FM 2222/, "RM 2222")}"
    end
    if record[:address] =~ /Mo Pac/
      @final_data[i][:address] = "#{record[:address].gsub(/Mo Pac/, "MoPac")}"
    end
    
  end
end

#
# add new separate fields for city, state, zip
#
def add_city_st_zip(options={})
  options = {
            }.merge(options)
  
  @final_data.each_index do |i|
    record = @final_data[i]
    
    # Use Indirizzo to parse address for me
    unless record[:city_state_zip].nil?
      address = Indirizzo::Address.new(record[:city_state_zip])
      @final_data[i][:city] = address.city[0].capitalize # for some reason returns as array
      @final_data[i][:state] = address.state
      @final_data[i][:zip] = address.zip
    end
    
  end
  
  
end

#
# Replace elders if necessary in database
# then corrects elders list itself,  if desired
#
def sub_elders(options={})
  options = { update_elder_master: true,
            }.merge(options)

  @final_data.each_index do |i|
    record = @final_data[i]
    if @elder_sub.key?(record[:elder])  # found matching elder
      @final_data[i][:elder] = @elder_sub[record[:elder]]  # modify elder in final database
    end
  end
  
  # optionally update elder master list
  if options[:update_elder_master]
    @elder_sub.each do |old_elder, new_elder|
      @elders.delete(old_elder)
      @elders << new_elder
    end                
  end
              
end


#
# quick way to report any log data captured
# for debugging
#
def data_report(options={})
  puts "\n\n"
  puts "**********************************\n"
  puts "**********************************"
  puts @last_log
end


# main basically
begin
              
  # interpret command line options
  @command_options = {}
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: parse_church_data.rb database_filename.csv [options]"
    opts.separator ''
    
    opts.on('-h', '--help', 'Display help' ) { puts opts; exit }
    opts.on('-e', 'Output elders only' ) { |e| @command_options[:elders_only] = true }
    opts.on('-d', 'Debug data output') { |d| @command_options[:debug] = true}
    opts.on('-z', 'Output By Zip') { |d| @command_options[:zip] = true}
  end
  
  option_parser.parse!
  
  # ERROR CHECKING of arguments
  if ARGV.length != 1
#    raise "ERROR: Invalid number of arguments"
    puts option_parser
    exit
  end
  @filename = ARGV[0]
#  puts "Filename: #{@filename}"

  if File.extname(@filename) != ".csv"
    raise "ERROR: #{@filename} not a CSV file!"
  end

  # init vars
  @last_log = ""
  
  # define CSV format of input and output files
  define_csv_format
  
  # read data from file
  read_data
  
  # clean data from issues
  clean_data
  
  # substitute for any recent elder changes
  sub_elders
  # add fields for city/state/zip
  add_city_st_zip
  
  # print data to display
  if @command_options[:debug]
    print_data
    data_report # mainly for debugging
  elsif @command_options[:zip]
    print_data(:by => :zip_code)
  else # google map type output
    print_google_map_data( header: true )
  end
  
  
end
