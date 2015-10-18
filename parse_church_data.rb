#require 'rubygems'
require 'optparse'
require 'csv'
#require 'logger'

# -- parse_church_data.rb <filename.csv>--
#
# Read in St. Paul family/elder/address data
# provided by church secretary and generate
# CSV ready to import into Google Maps for map creation
#
# Data is provided as 3 fundamental columns of data
# step 1: - put everything into a single column
# step 2: - transpose data to every 4th
#
# Outputs CSV to display

def define_csv_format(options={})
  
  ###############################
  # QUALITIES OF CSV FILE
  
  # indicate which columns contain valid data
  # leftmost column is 0
  @data_columns = [0,4,8]
 
  # number of lines per group
  @num_lines_per_linegroup = 5
  
  # indicate what values per row
  # should be 0 to @num_lines_per_linegroup-1
  @data_rows = {0 => :name,
                1 => :elder,
                2 => :address,
                3 => :city_state_zip,       # occasionally this is more of the address
                4 => :extra,                # occasionally this is the city/state/zip! 
  }
  
  # keys here must match the same order as values in @data_rows
  @output_header = {:name => "Name",
                    :elder => "Elder",
                    :address => "Address",
                    :city_state_zip => "City_State_Zip",
                    }
  
  # Used to give warning if someone is assigned to wrong elder!
  # also should match data input -- eventually want this to come from external file?
  @elders = ["Daniel Hadad",
             "Jerry Schmidt",
             "Harvey Brelin",
             "Mark De Young",
             "Ernie Johnson",
             "Joshua Konkle",
             "Charles Whitsel",
             "Ethan Cruz",
             "Ross Davis",
             "Don Hilsberg",
             "Paul Hunt",
             "Matthew Bohnsack",
             "Gary Jordan",
             "Tim Horn",
             ]
  
  # extra list of names to help find elders themselves in the database (need to use hash above instead...)
  # or break down the name to remove spouse name
  @elders2 = ["Dan Hadad",
              ]
  
  # if needing to sub elder in the data
  # format:   old_elder => new_elder
  @elder_sub = {"Jerry Schmidt" => "John Ritchie",
                "Harvey Brelin" => "Kelly Holligan"}
  
  #TBD sub out an elder for another??
  
  ###############################
  
end

# Simple print of @final_data for debug
def print_data(options={})
  options={ }.merge(options)
  
  @final_data.each do |record|
    record.each do |field, value|
      if !field.nil? and !value.nil?
        puts "    #{field}: #{value}" if !field.nil?
      end
    end
    puts "****************************"
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
  
  puts CSV.generate_line(@output_header.values) if options[:header]
  
  @final_data.each do |record|
    if @command_options[:elders_only]
      # remove spouse name if possible to make elder easier to find..
      name = record[:name].gsub(/& \w+ /, "")
      if !@elders.include?(name) and !@elders2.include?(name)
        next
      end
    end
    line = CSV.generate_line(record.values)
    puts line
  end
end

def read_data(options={})
  
  # slurp the CSV data!
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
      field_name = @data_rows[j]
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
    if !@elders.include?(record[:elder])  # if invalid elder found, then report
      @last_log << "WARNING: Invalid Elder found for #{record[:name]}!\n"
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
    
  end
end

# Replace elders if necessary in database
# then corrects elders list itself,  if desired
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


def data_report(options={})
  puts "\n\n"
  puts "**********************************\n"
  puts "**********************************"
  puts @last_log
end


begin
  @command_options = {}
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: parse_church_data.rb database_filename.csv [options]"
    opts.separator ''
    
    opts.on('-h', '--help', 'Display help' ) { puts opts; exit }
    
    opts.on('-e', 'Output elders only' ) { |e| @command_options[:elders_only] = true }
    
  end
  
  option_parser.parse!
  
  # ERROR CHECKING
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

  @last_log = ""
  
  define_csv_format
  
  read_data
  
  clean_data
  
  sub_elders
  
  print_google_map_data( header: true )
  
#  data_report # mainly for debugging
  
end
